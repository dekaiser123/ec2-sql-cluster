locals {
  bucket_name = lower(join("-", [var.resource_prefix, var.env, "sql", "backup", data.aws_caller_identity.current.account_id]))
  #log_bucket  = data.aws_s3_bucket.infra.id
  policy_name = lower(join("-", [var.resource_prefix, var.env, "sql", "backup", "policy"]))
  #cidr_block = [ for s in data.aws_subnet.subnets : s.cidr_block ]
}

resource "aws_s3_bucket" "sql-backup" {
  bucket        = local.bucket_name
  # acl           = "private"
  force_destroy = true

  tags = merge(var.tags, tomap({ "Name" = local.bucket_name }))

  # logging {
  #   target_bucket = local.log_bucket
  #   target_prefix = join("/", [join("-", [var.resource_prefix, var.env, "access", "log"]), join("-", [var.resource_prefix, var.env, "sql", ""])])
  # }

  # versioning {
  #   enabled = false
  # }

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       sse_algorithm = "AES256"
  #     }
  #   }
  # }

  # lifecycle_rule {
  #   id      = "sqlbackup"
  #   enabled = true

  #   prefix = "sqlbackup/"

  #   transition {
  #     days          = 30
  #     storage_class = "ONEZONE_IA"
  #   }

  #   transition {
  #     days          = 60
  #     storage_class = "GLACIER"
  #   }

  #   expiration {
  #     days = 90
  #   }
  # }
}

resource "aws_s3_bucket_ownership_controls" "sql-backup" {
  bucket = aws_s3_bucket.sql-backup.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "sql-backup" {
  bucket        = aws_s3_bucket.sql-backup.id
  acl           = "private"
  depends_on = [aws_s3_bucket_ownership_controls.sql-backup]
}

resource "aws_s3_bucket_versioning" "sql-backup" {
  bucket = aws_s3_bucket.sql-backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "sql-backup" {
  bucket        = aws_s3_bucket.sql-backup.id
  target_bucket = var.s3_access_logging_bucket #local.log_bucket
  target_prefix = lower(join("-", [local.bucket_name, "accesslogs/"])) #join("/", [local.bucket_name, join("", [local.bucket_name, "-"])])
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sql-backup" {
  bucket = aws_s3_bucket.sql-backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "sql-backup" {
  bucket = aws_s3_bucket.sql-backup.id

  rule {
    id      = "Move non-current versions older than 30 days"
    filter {
      object_size_greater_than = 40960
    }

    noncurrent_version_transition {
      noncurrent_days          = 1
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    status = "Enabled"
  }

  rule {
    id      = "sqlbackup"
    filter {
      and {
        prefix = "sqlbackup/"
        object_size_greater_than = 40960
      }
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    status = "Enabled"
  }

  rule {
    id      = "LHD_backups"
    filter {
      prefix = "sqlbackup/LHD_backups/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    expiration {
      expired_object_delete_marker = true
    }

    status = "Enabled"
  }

  rule {
    id      = "LHD_Archive"
    filter {
      and {
        prefix = "LHD_Archive/"
        object_size_greater_than = 40960
      }
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # expiration {
    #   days = 90
    # }
    status = "Enabled"
  }
  
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.sql-backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  depends_on              = [aws_s3_bucket.sql-backup]
}


resource "aws_s3_bucket_policy" "backup" {
  bucket = aws_s3_bucket.sql-backup.id

  policy = jsonencode(
    {
      "Version": "2012-10-17",
      "Id": "SQL_Backup",
      "Statement": [
        # {
        #   "Sid": "IPAllow",
        #   "Effect": "Deny",
        #   "Principal": "*",
        #   "Action": "s3:*",
        #   "Resource": [
        #   "${aws_s3_bucket.sql-backup.arn}",
        #   "${aws_s3_bucket.sql-backup.arn}/*"
        #   ]
        #   #Below is only for public IPs
        #   "Condition": {
        #     "IpAddress": {"aws:SourceIp": ["${element(local.cidr_block, 0)}","${element(local.cidr_block, 1)}","${element(local.cidr_block, 2)}"]}
        #   }
        # },
        {
          "Sid": "S3ForceSSL",
          "Effect": "Deny",
          "Principal": "*",
          "Action": "s3:*",
          "Resource": [
          "${aws_s3_bucket.sql-backup.arn}",
          "${aws_s3_bucket.sql-backup.arn}/*"
          ],
          "Condition": {
            "Bool": {"aws:SecureTransport": "false" }
          }
        }
      ]
    }
  )
  depends_on = [aws_s3_bucket_public_access_block.backup]
}


resource "aws_iam_role_policy" "backup_s3_policy" {
  name   = local.policy_name
  role   = aws_iam_role.sql-instanceprofile-role.id
  policy =  jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "S3SQLBackup",
                "Effect": "Allow",
                "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:ListBucket"
                  #"s3:DeleteObject",
                ],
                "Resource": [
                    "${aws_s3_bucket.sql-backup.arn}",
                    "${aws_s3_bucket.sql-backup.arn}/*"
                ]
            }
        ]
    }
  )
}
