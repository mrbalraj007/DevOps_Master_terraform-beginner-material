# EBS Encryption Automation

This Terraform configuration creates an AWS Systems Manager (SSM) Automation role, its IAM policy, and an Automation document for encrypting unencrypted EBS volumes attached to one EC2 instance. The document workflow operates on EC2 block-device mappings and is not limited to a particular operating system.

## Resources created

- IAM role `SSM-EBS-Encryption-AutomationRole`, trusted by `ssm.amazonaws.com`.
- IAM policy `SSM-EBS-Encryption-Policy`, attached to the role. It grants the EC2 and KMS permissions used by the automation. The KMS permissions are scoped to the key ARN set in `kms_key_arn`.
- SSM Automation document `JQ-EBS-Encription`, whose content is loaded from `for-windows-ssm-document.yaml`.

Terraform requires version 1.15.0 or later and the AWS provider version 5.0 or later.

## What the automation does

The SSM document:

1. Inspects the target instance and its attached EBS volumes.
2. Reports the volume encryption status, or exits without changes if all volumes are encrypted.
3. Creates a safety snapshot, copies it with encryption, and creates a replacement volume for each unencrypted volume.
4. Preserves volume tags and the original device attachment settings, including `DeleteOnTermination`, then validates the replacement.
5. Attempts to roll back a failed volume swap. It retains original volumes and safety snapshots for recovery.
6. Restarts the instance after successful processing if it was running beforehand; an instance that was already stopped remains stopped.

Only instances in the `running` or `stopped` state are supported. This automation can stop an instance and replace its EBS volumes, so run it during a maintenance window and ensure you have a recovery plan.

## Prerequisites

1. Install Terraform 1.15.0 or later.
2. Configure AWS credentials and select an AWS Region for Terraform.
3. Have a KMS key available in the same Region as the EBS volumes. The `kms_key_arn` input must be a customer-managed KMS key ARN.
4. Ensure the target instance is managed by Systems Manager and can be stopped and started as needed.
5. Ensure the KMS key policy permits the Terraform-created role to use the key.

## Configure Terraform

From this directory, edit `terraform.tfvars` with your Region, KMS key ARN, and tags:

```hcl
aws_region  = "us-east-1"
kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/your-key-id"

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}
```

Do not put AWS access keys or other credentials in `terraform.tfvars`.

The S3 backend configuration in `backend.tf` is commented out, so Terraform uses local state by default. If you enable the S3 backend, configure the bucket, key, and Region for your environment before running `terraform init`.

## Create the IAM resources and SSM document

Run these commands from the directory containing `main.tf`:

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Review the plan before approving `terraform apply`. After applying, retrieve the role and document details:

```powershell
terraform output ssm_automation_role_name
terraform output ssm_automation_role_arn
terraform output ssm_ebs_encryption_policy_arn
terraform output ssm_ebs_encryption_document_name
terraform output ssm_ebs_encryption_document_arn
```

## Run the automation

1. In the AWS console, select the Region configured in `terraform.tfvars`.
2. Open **Systems Manager > Automation** and choose **Execute automation**.
3. Select the `JQ-EBS-Encription` document.
4. Set the parameters:
   - `AutomationAssumeRole`: the role ARN from `terraform output ssm_automation_role_arn`.
   - `InstanceId`: the EC2 instance ID to process.
   - `KmsKeyId`: optional KMS key ID, ARN, or alias for encrypted snapshot copies. Leave it empty to use the account/Region default EBS key. If specifying a key, ensure it is compatible with the KMS permissions and key policy configured for the automation role.
   - `DryRun`: defaults to `true`, which only reports volume status and makes no changes. Set it to `false` to perform the migration.
5. Review the selected instance and parameters before starting the execution. For a real migration, confirm `DryRun` is `false`.
6. Monitor the Automation execution and validate the resulting instance and volumes before deciding whether to remove any retained original volumes or snapshots.

## Important operational notes

- Test with `DryRun: true` first and review its report.
- The document also declares `SnapshotTimeoutSeconds` and `VolumeTimeoutSeconds` parameters with 7200-second defaults, but the current step timeout values are set directly in the YAML and are not controlled by these parameters.
- A real run can stop the instance and replace its unencrypted EBS volumes. Plan for downtime and verify that the instance can be safely stopped and started.
- Original volumes and safety snapshots are intentionally retained for rollback and recovery; review and clean them up manually only after confirming the migration.
- The IAM policy grants KMS actions on the `kms_key_arn` value in `terraform.tfvars`. If you pass a different `KmsKeyId` to the Automation document, make sure the role and key policy authorize its use.
- After changing Terraform or the YAML document, run `terraform plan` and review the proposed changes before applying.

## Update or remove resources

To update the managed resources after changing the Terraform configuration or document YAML:

```powershell
terraform plan
terraform apply
```

To remove the Terraform-managed role, policy, and SSM document:

```powershell
terraform destroy
```

Destroying these Terraform resources does not remove EBS volumes or snapshots created during an Automation execution.
