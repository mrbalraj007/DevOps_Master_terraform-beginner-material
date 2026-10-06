terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# IAM Trust Policy
# Allows AWS Systems Manager Automation to assume this role
# ============================================================

data "aws_iam_policy_document" "ssm_automation_assume_role" {
  statement {
    sid    = "AllowSSMAutomationToAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# ============================================================
# IAM Role
# ============================================================

resource "aws_iam_role" "ssm_ebs_encryption_automation_role" {
  name        = "SSM-EBS-Encryption-AutomationRole"
  description = "IAM role used by SSM Automation to encrypt existing EBS volumes"

  assume_role_policy = data.aws_iam_policy_document.ssm_automation_assume_role.json

  tags = merge(var.tags, {
    Name      = "SSM-EBS-Encryption-AutomationRole"
    ManagedBy = "Terraform"
    Purpose   = "SSM-EBS-Encryption-Automation"
  })
}

# ============================================================
# IAM Policy for EC2 / EBS / KMS
# ============================================================

data "aws_iam_policy_document" "ssm_ebs_encryption_policy" {

  statement {
    sid    = "EC2DescribePermissions"
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EBSEncryptionMigrationPermissions"
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:CopySnapshot",
      "ec2:CreateVolume",
      "ec2:CreateTags",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyInstanceAttribute",
      "ec2:StopInstances",
      "ec2:StartInstances"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "KMSEBSEncryptionPermissions"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo"
    ]

    resources = [var.kms_key_arn]
  }

  statement {
    sid    = "KMSCreateGrantForAWSResource"
    effect = "Allow"

    actions = [
      "kms:CreateGrant"
    ]

    resources = [var.kms_key_arn]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"

      values = ["true"]
    }
  }
}

# ============================================================
# Create IAM Policy
# ============================================================

resource "aws_iam_policy" "ssm_ebs_encryption_policy" {
  name        = "SSM-EBS-Encryption-Policy"
  description = "Permissions required by SSM Automation to encrypt existing EBS volumes"
  policy      = data.aws_iam_policy_document.ssm_ebs_encryption_policy.json

  tags = merge(var.tags, {
    Name      = "SSM-EBS-Encryption-Policy"
    ManagedBy = "Terraform"
    Purpose   = "SSM-EBS-Encryption-Automation"
  })
}

# ============================================================
# Attach Policy to Automation Role
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm_ebs_encryption_policy_attachment" {
  role       = aws_iam_role.ssm_ebs_encryption_automation_role.name
  policy_arn = aws_iam_policy.ssm_ebs_encryption_policy.arn
}

# ============================================================
# SSM Automation Document
# ============================================================

resource "aws_ssm_document" "ebs_encryption" {
  name            = "JQ-EBS-Encription"
  document_type   = "Automation"
  document_format = "YAML"
  content         = file("${path.module}/for-windows-ssm-document.yaml")

  tags = merge(var.tags, {
    Name      = "JQ-EBS-Encription"
    ManagedBy = "Terraform"
    Purpose   = "EBS-Encryption-Automation"
  })
}
