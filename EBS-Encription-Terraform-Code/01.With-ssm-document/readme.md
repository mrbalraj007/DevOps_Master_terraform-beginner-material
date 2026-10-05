# EBS Encryption Automation

This Terraform project creates the AWS identity and Systems Manager Automation resources needed to encrypt existing unencrypted Amazon EBS volumes attached to an EC2 instance.

## Resources created

The configuration provisions:

- An IAM role for SSM Automation to assume via the `ssm.amazonaws.com` trust policy.
- An IAM policy with the EC2, EBS, and KMS permissions required to:
  - describe instances, volumes, snapshots, and tags
  - create safety snapshots and encrypted copies
  - create replacement volumes and attach or detach them
  - stop and start the target instance when required
  - use the configured customer-managed KMS key
- An SSM Automation document for Windows:
  - `BS-WIN-EBS-Encription-Windows`
  - source: `for-windows-ssm-document.yaml`
- An SSM Automation document for Linux:
  - `BS-LIN-EBS-Encription-Linux`
  - source: `for-linux-ssm-document.yaml`

Do not create these documents manually in the AWS console. Terraform manages the document content and lifecycle.

## What the automation does

The SSM documents are designed to:

- discover attached EBS volumes and identify those that are not encrypted
- skip already-encrypted volumes
- create a safety snapshot before replacing a volume
- create an encrypted snapshot copy and use it to build an encrypted replacement volume
- preserve tags and the original attachment layout as closely as possible
- replace each unencrypted volume one at a time
- restore the original instance power state after processing
- support `DryRun: true` to report the planned work without changing anything

> This project does not create or modify EC2 instances outside the automation workflows it defines. The SSM document itself performs the EBS migration sequence.

## Prerequisites

1. Install Terraform 1.5.0 or later.
2. Configure AWS credentials for Terraform using your preferred AWS CLI profile, environment variables, or another supported authentication method.
3. Have an enabled customer-managed KMS key in the same AWS Region as the EBS volumes.
4. Ensure the target EC2 instance can be stopped and restarted, and have a recovery plan in place before running the migration.
5. Make sure the IAM role created by Terraform is allowed to use the key policy for the selected KMS key.

## Configure Terraform

1. Open PowerShell in the directory that contains `main.tf`.
2. Edit `terraform.tfvars` and set the AWS region, KMS key ARN, and tags for your environment.
3. Do not store AWS access keys or other secrets in `terraform.tfvars`.

Example:

```hcl
aws_region  = "us-east-1"
kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/your-key-id"

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}
```

## Create the IAM role and SSM documents

Run the following commands from the project directory:

```powershell
terraform init
terraform validate
terraform plan
terraform apply
```

Review the plan before approving `terraform apply`.

After the apply completes, retrieve the values needed for the automation run:

```powershell
terraform output ssm_automation_role_arn
terraform output ssm_ebs_encryption_document_name
terraform output ssm_ebs_encryption_document_arn
terraform output ssm_linux_ebs_encryption_document_name
terraform output ssm_linux_ebs_encryption_document_arn
```

The documents appear under AWS Systems Manager > Documents in the configured AWS Region.

## Run the Automation

1. In the AWS console, select the same Region configured in `terraform.tfvars`.
2. Open Systems Manager > Automation and choose Execute automation.
3. Select either the Windows or Linux SSM document for the target instance.
4. Enter the required parameters:
   - `InstanceId`: EC2 instance ID to process, for example `i-0123456789abcdef0`
   - `KmsKeyId`: KMS key ID, ARN, or alias used for encrypted snapshots and replacement volumes. For Linux, this defaults to `alias/aws/ebs` unless you override it.
   - `AutomationAssumeRole`: the role ARN returned by `terraform output ssm_automation_role_arn`
   - `DryRun`: set to `true` to report only, or `false` to perform the migration
5. Review the instance and key selection, then start the execution.
6. Monitor the run in Systems Manager Automation. Confirm the output for each migrated volume, snapshot, and replacement volume before deciding whether to keep or discard the original volumes.

## Important notes

**SSM Document workflow for Windows.**
```
EC2 Instance
    |
    v
Discover attached EBS volumes
    |
    v
Any unencrypted volumes?
    |
    +---- NO ----> EXIT
    |
   YES
    |
    v
Stop EC2
    |
    v
For each unencrypted EBS volume:
    |
    +--> Capture original configuration
    |
    +--> Create safety snapshot
    |
    +--> Wait for snapshot completion
    |
    +--> Copy snapshot with encryption
    |
    +--> Wait for encrypted snapshot
    |
    +--> Create encrypted EBS volume
    |
    +--> Wait for volume available
    |
    +--> Copy tags
    |
    +--> Detach original unencrypted volume
    |
    +--> Attach new encrypted volume
    |        to same device
    |
    +--> Restore DeleteOnTermination
    |
    +--> Validate encryption + attachment
    |
    v
All volumes complete
    |
    v
Was EC2 originally running?
    |
    +---- YES ----> Start EC2
    |
    +---- NO -----> Leave EC2 stopped
    |
    v
COMPLETE

Original volumes  ---> RETAINED FOR ROLLBACK
Safety snapshots  ---> RETAINED FOR RECOVERY
```



- The automation is designed for controlled maintenance windows and should be used only when the instance can be restored safely.
- Retained original volumes and safety snapshots are kept intentionally for rollback and review.
- If a document is updated or the Terraform code changes, run `terraform plan` and `terraform apply` again to make the AWS-managed document match the configuration in this repo.

## Update or remove resources

To update the Terraform-managed IAM resources and SSM documents after editing the YAML files or the Terraform code, run:

```powershell
terraform plan
terraform apply
```

To remove the Terraform-managed resources:

```powershell
terraform destroy
```

This removes the IAM role, attached policy, and the SSM documents created by this configuration. It does not delete the EBS volumes or snapshots that were created by the automation during a migration run.