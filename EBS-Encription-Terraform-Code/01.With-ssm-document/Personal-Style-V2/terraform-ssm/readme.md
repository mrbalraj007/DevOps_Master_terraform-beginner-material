# EBS Encryption Automation

This Terraform configuration creates an AWS Systems Manager (SSM) Automation role, its IAM policy, and an Automation document for encrypting unencrypted EBS volumes attached to an EC2 instance. The document operates on EC2 block-device mappings and is not limited to a particular operating system.

## Resources created

- IAM role `SSM-EBS-Encryption-AutomationRole`, trusted by `ssm.amazonaws.com`.
- IAM policy `SSM-EBS-Encryption-Policy`, attached to the role. KMS permissions are scoped to the key ARN supplied through `kms_key_arn`.
- SSM Automation document `JQ-EBS-Encription`, loaded from `ssm/ebs-encryption.yaml`.

Terraform 1.15.0 or later and AWS provider 5.0 or later are required.

## What the automation does

The SSM document:

1. Inspects the target instance and its attached EBS volumes.
2. Reports encryption status, or exits without changes if all volumes are encrypted.
3. Creates a safety snapshot, copies it with encryption, and creates a replacement volume for each unencrypted volume.
4. Preserves volume tags and attachment settings, including `DeleteOnTermination`, then validates the replacement.
5. Attempts to roll back a failed volume swap. Original volumes and safety snapshots are retained for recovery.
6. Restarts an instance after successful processing if it was running beforehand. An instance that was already stopped remains stopped.

Only instances in the `running` or `stopped` state are supported. A real run can stop an instance and replace its EBS volumes. Test with `DryRun: true` first, use a maintenance window, and ensure you have a recovery plan.

## Prerequisites

1. Install Terraform 1.15.0 or later and the AWS CLI.
2. Configure a separate AWS CLI profile or other AWS credentials for each account. Do not store access keys in Terraform files.
3. Have a customer-managed KMS key available in each account and Region where it is needed. The key policy must allow the Terraform-created role to use the key.
4. Ensure the target EC2 instance is managed by Systems Manager and can be stopped and started as needed.

## Multi-account layout

Use one Terraform working directory and keep each account's variable file and local backend configuration paired by the same account alias:

```text
terraform-ssm/
├── backend.tf
├── provider.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── ssm/
│   └── ebs-encryption.yaml
├── environments/
│   ├── personal.tfvars
│   ├── dev.tfvars
│   ├── test.tfvars
│   ├── prod.tfvars
│   └── account05.tfvars ... account12.tfvars
├── backends/
│   ├── personal.hcl
│   ├── dev.hcl
│   ├── test.hcl
│   ├── prod.hcl
│   └── account05.hcl ... account12.hcl
└── states/
```

The names above are examples; use aliases that identify your own accounts. Create exactly 12 matching `.tfvars` and `.hcl` files. For example, `environments/personal.tfvars` should be paired with `backends/personal.hcl`, and `environments/prod.tfvars` with `backends/prod.hcl`.

### Configure the local backend

Add `backend.tf` in the Terraform root directory:

```hcl
terraform {
  backend "local" {}
}
```

Keep the state path out of `backend.tf`; select it at initialization time using an account-specific backend configuration file. For example, `backends/personal.hcl` contains:

```hcl
path = "states/personal.tfstate"
```

Each other backend file contains the corresponding unique path, for example:

```hcl
path = "states/prod.tfstate"
```

Create one variable file per account using the format in `environments/personal.tfvars`:

```hcl
account_name = "Example account"
account_id   = "123456789012"
aws_region   = "us-east-1"
kms_key_arn  = "arn:aws:kms:us-east-1:123456789012:key/your-key-id"

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}
```

Use the actual 12-digit account ID and a KMS key ARN valid for that account and Region. Do not copy an account's KMS ARN into another account's variable file.

### Keep state out of source control

Terraform state can contain sensitive infrastructure data. Keep the `states/` directory private, back it up securely, and never commit state files to source control. Local state does not provide shared access or remote locking; for team workflows, use a secured remote backend with locking instead.

## Initialize and use an account

Run commands from the directory containing `main.tf`. The examples below use PowerShell and AWS CLI named profiles. Replace `personal` with the matching profile and alias for the account you intend to use.

First authenticate and verify the AWS identity:

```powershell
aws sso login --profile personal
$env:AWS_PROFILE = "personal"
aws sts get-caller-identity
```

Confirm the returned `Account` is exactly the same as `account_id` in `environments/personal.tfvars`. Do not continue if they do not match.

Create the state directory if needed, then configure this working directory to use that account's state:

```powershell
New-Item -ItemType Directory -Force states
terraform init -reconfigure -backend-config="backends/personal.hcl"
```

Format, validate, and review the proposed changes:

```powershell
terraform fmt -check
terraform validate
terraform plan -var-file="environments/personal.tfvars"
```

Apply only after reviewing the plan:

```powershell
terraform apply -var-file="environments/personal.tfvars"
```

Terraform's `check "correct_aws_account"` assertion compares the caller account with `account_id`, but a failed `check` is reported as a warning and does not block Terraform operations. Always verify the AWS identity with `aws sts get-caller-identity` before planning or applying; do not rely on the assertion as a substitute for checking credentials.

### Switch to another account

Before every account switch, set and verify the new AWS profile, then initialize the matching backend and use the matching variable file. For example:

```powershell
aws sso login --profile prod
$env:AWS_PROFILE = "prod"
aws sts get-caller-identity

terraform init -reconfigure -backend-config="backends/prod.hcl"
terraform plan -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

Use the exact same alias for the AWS profile, backend file, and variable file. Re-run `terraform init -reconfigure` whenever switching accounts. A Terraform working directory uses one selected backend configuration at a time; the backend path and variable file must always refer to the same account.

### Existing default local state

If this directory already has a `terraform.tfstate` containing resources that must remain managed, do not use `-reconfigure` to select its first account-specific state. Instead, authenticate to the account that owns those resources, verify its account ID, and migrate the state once:

```powershell
terraform init -migrate-state -backend-config="backends/personal.hcl"
```

Review Terraform's migration prompt carefully. Do not migrate a state file into an account-specific path unless it belongs to that account. For a new account with no existing state, use `-reconfigure` as shown above.

## Run the SSM automation

1. In the AWS console, select the Region configured in the active account's `.tfvars` file.
2. Open **Systems Manager > Automation** and choose **Execute automation**.
3. Select the `JQ-EBS-Encription` document.
4. Set the parameters:
   - `AutomationAssumeRole`: the ARN from `terraform output ssm_automation_role_arn`.
   - `InstanceId`: the EC2 instance ID to process.
   - `KmsKeyId`: optional KMS key ID, ARN, or alias for encrypted snapshot copies. Leave it empty to use the account/Region default EBS key. If specifying a key, ensure the role and key policy authorize its use.
   - `DryRun`: defaults to `true`, which reports volume status without making changes. Set to `false` to perform the migration.
5. Review the selected instance and parameters before starting the execution.
6. Monitor the Automation execution and validate the resulting instance and volumes before removing any retained original volumes or snapshots.

The document also declares `SnapshotTimeoutSeconds` and `VolumeTimeoutSeconds` parameters with 7200-second defaults, but the current step timeout values are set directly in the YAML and are not controlled by these parameters.

## Outputs

After applying, retrieve the role and document details:

```powershell
terraform output ssm_automation_role_name
terraform output ssm_automation_role_arn
terraform output ssm_ebs_encryption_policy_arn
terraform output ssm_ebs_encryption_document_name
terraform output ssm_ebs_encryption_document_arn
```

## Update or remove resources

After changing Terraform configuration or the SSM document, select and verify the intended AWS profile, initialize the matching backend, and review the account-specific plan before applying:

```powershell
terraform init -reconfigure -backend-config="backends/personal.hcl"
terraform plan -var-file="environments/personal.tfvars"
terraform apply -var-file="environments/personal.tfvars"
```

To remove the Terraform-managed role, policy, and SSM document from an account, first verify the AWS identity and initialize that account's backend, then review the destroy plan:

```powershell
terraform init -reconfigure -backend-config="backends/personal.hcl"
terraform plan -destroy -var-file="environments/personal.tfvars"
terraform destroy -var-file="environments/personal.tfvars"
```

Destroying these Terraform resources does not remove EBS volumes or snapshots created during an Automation execution.
