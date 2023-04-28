locals {

  instance_profile_role_name   = lower(join("-", [var.resource_prefix, var.env, "sql", "ec2", "iam"]))
  instance_profile_policy_name = lower(join("-", [var.resource_prefix, var.env, "sql", "ec2", "iam", "policy"]))
  instance_profile_name        = lower(join("-", [var.resource_prefix, var.env, "sql", "ec2", "iam"]))

}

resource "aws_iam_role" "sql-instanceprofile-role" {

  name                  = local.instance_profile_role_name
  assume_role_policy    = jsonencode(
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": ["ec2.amazonaws.com"]
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
  )
  force_detach_policies = true
  # lifecycle {
  #   ignore_changes = all
  # }
  tags = merge(var.tags, tomap({ "Name" = local.instance_profile_role_name }))
}


resource "aws_iam_role_policy" "sql-instanceprofile_policy" {
  name   = local.instance_profile_policy_name
  role   = aws_iam_role.sql-instanceprofile-role.id
  policy = jsonencode(
    {
        "Version": "2012-10-17",
        "Statement": [
            # {
            #     "Effect": "Allow",
            #     "Action": [
            #         "logs:CreateLogGroup",
            #         "logs:CreateLogStream",
            #         "logs:PutLogEvents",
            #         "logs:DescribeLogStreams"
            #     ],
            #     "Resource": [
            #         "arn:aws:logs:*:*:*"
            #   ]
            # },
            # {
            #     "Effect": "Allow",
            #     "Action": [
            #       "CloudWatch:PutMetricData",
            #       "ec2:DescribeInstances", 
            #       "ec2:DescribeImages",
            #       "EC2:DescribeTags"
            #     ],
            #     "Resource": "*"
            # },
            {
                "Sid":  "S3Buckets",
                "Effect": "Allow",
                "Action": [
                  "s3:GetObject",
                  "s3:ListBucket"
                ],
                "Resource": var.s3bucket_resources
            },
            {
                "Sid":  "IAMListAccAlias",
                "Effect": "Allow",
                "Action": "iam:ListAccountAliases",
                "Resource": "*"
            },
            # {
            #   "Effect": "Allow",
            #     "Action": [
            #       "ssm:*"
            #     ],
            #     "Resource": "*"
            # },
            # {
            #   "Effect": "Allow",
            #   "Action": [
            #       "ssm:GetParameters"
            #   ],
            #   "Resource": [
            #       "arn:aws:ssm:*:*:parameter/*"
            #   ]
            # }
            {
                "Sid": "EC2DescribeAll",
                "Effect": "Allow",
                "Action": [
                    "ec2:Describe*"
                ],
                "Resource": "*"
            },
            {
                "Sid": "SSMCustom",
                "Effect": "Allow",
                "Action": [
                    "ssm:ListCommandInvocations"
                ],
                "Resource": "*"
            },
            {
                "Sid": "SSMParametersByPath",
                "Effect": "Allow",
                "Action": "ssm:GetParametersByPath",
                "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
            }
        ]
    }
  )
  # lifecycle {
  #   ignore_changes = all
  # }
}

resource "aws_iam_instance_profile" "sql-instanceprofile" {
  name = local.instance_profile_name
  role = aws_iam_role.sql-instanceprofile-role.name
}

resource "aws_iam_role_policy_attachment" "sql-ssm-core" {
  role       = aws_iam_role.sql-instanceprofile-role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# resource "aws_iam_role_policy_attachment" "sql-secretsmanager" {
#   role       = aws_iam_role.sql-instanceprofile-role.id
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
# }

resource "aws_iam_role_policy_attachment" "sql-cloudwatch" {
  role       = aws_iam_role.sql-instanceprofile-role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "sql-ssm-maint" {
  role       = aws_iam_role.sql-instanceprofile-role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}