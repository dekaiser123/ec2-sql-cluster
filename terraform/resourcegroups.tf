resource "aws_resourcegroups_group" "rg" {
  name = lower(join("-", [var.resource_prefix, var.env, "sql", "rg"]))

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "Prefix",
      "Values": ["${lower(var.resource_prefix)}"]
    },
    {
      "Key": "Environment",
      "Values": ["${lower(var.env)}"]
    },
    {
      "Key": "Component",
      "Values": ["sql"]
    }
  ]
}
JSON
  }
}
