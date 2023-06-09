# Cloudformation

These cloudformation templates is used to create the bootstrap components to enable the infrastructure build of the MS SQL Servers

## Parameter Inputs

| Parameter Input |         Description    | CFN Template |
|-----------------|------------------------|--------------|
| `EnvType` | Environment that these resources are being created for | 00_sql-infra-common.yaml <br /> 01_GitHub-webhook.yaml <br /> 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| `Project` | Project Application Name for which resources are created | 00_sql-infra-common.yaml <br /> 01_GitHub-webhook.yaml <br /> 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| `NotificationEmailAddress` | Email address that will receive notificaions for pipeline approval | 00_sql-infra-common.yaml |
| `SNSKeyID` | AWS SNS KMS keyID | 00_sql-infra-common.yaml |
| `AccessLogBucket` | Seperate S3 bucket to dump s3 access logs | 00_sql-infra-common.yaml |
| `GitTokenSecret` | PAT stored in AWS SSM | 01_GitHub-webhook.yaml |
| `GitRepository` | Git repo and branch details | 01_GitHub-webhook.yaml |
| `CodebuildFor` | Resource that will be created by the Codebuild | 01_GitHub-webhook.yaml |
| `ArtifactBucket` | Aritfact bucket name for webhook/codebuild | 01_GitHub-webhook.yaml <br /> 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| `CodeBuildGitCredentialARN` | Existing Codebuild Git Source Credential ARN | 01_GitHub-webhook.yaml |
| `PipelineFor` | Resource that will be created by the Pipeline | 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| `GitRepo` | The repo name without the env prefix | 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| `ApprovalNotificationTopicARN` | SNS topic ARN for pipeline manual approval | 02_sql-terraform-pipeline.yaml |
| `DestroyTF` | Description: 1 = true, 0 = false | 02_sql-terraform-pipeline.yaml |
| `AppBucket` | App bucket where runtime is stored | 03_sql-ansible-pipeline.yaml |
| `VPC` | The vpc to launch the service | 03_sql-ansible-pipeline.yaml |
| `Subnets` | Select primary and secondary subnets | 03_sql-ansible-pipeline.yaml |
| `SecurityGroups` | Select Stackset and ansible SGs | 03_sql-ansible-pipeline.yaml |
| `S3AppBucketSync` | 1 = true, 0 = false | 03_sql-ansible-pipeline.yaml |
| `AnsiblePlaybook` | Select Ansible Playbook | 03_sql-ansible-pipeline.yaml |

Some of the above are provisioned from other terraform/cfn bootstraps

## Resources
The list of resources these templates creates are:

| Resource Name | Type | CFN Template |
| ------------- | ---- | ------------ |
| ArtifactBucket | AWS::S3::Bucket | 00_sql-infra-common.yaml |
| ArtifactBucketpolicy | AWS::S3::BucketPolicy | 00_sql-infra-common.yaml |
| ApprovalNotificationTopic | AWS::SNS::Topic | 00_sql-infra-common.yaml |
| CodeBuildGitCredential | AWS::CodeBuild::SourceCredential | 01_GitHub-webhook.yaml |
| CodeBuildServiceRole | AWS::IAM::Role | 01_GitHub-webhook.yaml <br /> 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| CodeBuildPolicy | AWS::IAM::Policy | 01_GitHub-webhook.yaml <br /> 02_sql-terraform-pipeline.yaml <br /> 03_sql-ansible-pipeline.yaml |
| CodeBuildProject | AWS::CodeBuild::Project | 01_GitHub-webhook.yaml |
| CloudWatchLogGroup | AWS::Logs::LogGroup | 01_GitHub-webhook.yaml |
| CodeBuildTerraformPlan | AWS::CodeBuild::Project | 02_sql-terraform-pipeline.yaml |
| CodeBuildTerraformApply | AWS::CodeBuild::Project | 02_sql-terraform-pipeline.yaml |
| TerraformPipeline | AWS::CodePipeline::Pipeline | 02_sql-terraform-pipeline.yaml |
| CloudWatchLogGroupPlan | AWS::Logs::LogGroup | 02_sql-terraform-pipeline.yaml |
| CloudWatchLogGroupApply | AWS::Logs::LogGroup | 02_sql-terraform-pipeline.yaml |
| CodeBuildTerraformOutput | AWS::CodeBuild::Project | 03_sql-ansible-pipeline.yaml |
| CodeBuildAnsibleInventory | AWS::CodeBuild::Project | 03_sql-ansible-pipeline.yaml |
| AnsiblePipeline | AWS::CodePipeline::Pipeline | 03_sql-ansible-pipeline.yaml |
| CloudWatchLogGroupOutput | AWS::Logs::LogGroup | 03_sql-ansible-pipeline.yaml |
| CloudWatchLogGroupConfig | AWS::Logs::LogGroup | 03_sql-ansible-pipeline.yaml |

## Outputs
The list of outputs this template exposes:

| Output Name | Description | CFN Template |
| ----------- | ----------- | ------------ |
| ArtifactBucketARN | The Source Code Artifact bucket ARN | 00_sql-infra-common.yaml |
| ArtifactBucketName | The Source Code Artifact bucket name | 00_sql-infra-common.yaml |
| ApprovalNotificationTopicName | Approval notification topic name | 00_sql-infra-common.yaml |
| ApprovalNotificationTopicARN | Approval notification topic ARN | 00_sql-infra-common.yaml |
| TerraformStateDynamoDBTableARN | The terraform state DynamoDB ARN | 00_sql-infra-common.yaml |
| TerraformStateDynamoDBTable | The terraform state DynamoDB table | 00_sql-infra-common.yaml |
| CodeBuildGitCredentialARN | Codebuild Git Source Credential ARN | 01_GitHub-webhook.yaml |
| TerraformPipelineVersion | Terraform Apply CodePipeline Version | 02_sql-terraform-pipeline.yaml |
| AnsiblePipelineVersion | Ansible Configure CodePipeline Version | 03_sql-ansible-pipeline.yaml |

## Steps

1. Run `00_sql-infra-common.yaml` with the correct parameter inputs.
2. Run `01_GitHub-webhook.yaml` with the correct parameter inputs.
3. Go to the codebuild of the SQL webhook (Developer Tools > CodeBuild > Build projects > `{env}`-`{repo}` > Edit Source) and set up the trigger event manually
    ![GithHealth webhook codebuild config](../images/GitHub-webhook-codebuild.png)
4. Add the webhook url and token access to the repo in GitHub (admin access to repo is required).
5. Run `02_sql-terraform-pipeline.yaml` with the correct parameter inputs.
6. Wait until AWS resources are provisioned from the terraform codepipeline and SQL servers are joined to domain and service accounts configured. Confirm in Cloudwatch Logs (CloudWatch > Log groups > EC2 > SQL_`{instance_id}`) message `SQLAdmins Added and SrvAcc SetBatchLogonRight` exists for each sql server node.
7. Run `03_sql-ansible-pipeline.yaml` with the correct parameter inputs.
8. Review ansible codepipline run.
9. Remediate any errors.
10. Retry ansible codepipeline (release changes or retry) and repeat steps 7 - 9 if required.

## 🛈 Notes

- Ubuntu 20.04 is used for the ansible codebuilds.
- For an empty App Bucket, set S3AppBucketSync = 1 to auto-download the required packages to run ansible as first run, then set back to 0 via stack update. (Alternatively create a docker image)