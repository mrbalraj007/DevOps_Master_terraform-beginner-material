variable "aws_region" {
  description = "AWS region where Terraform resources will be managed"
  type        = string
}

variable "account_name" {
  description = "AWS Account Name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "kms_key_arn" {
  description = "Customer managed KMS key ARN used for EBS encryption"
  type        = string

  validation {
    condition = can(
      regex(
        "^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/",
        var.kms_key_arn
      )
    )

    error_message = "kms_key_arn must be a valid KMS key ARN."
  }
}

variable "tags" {
  description = "Tags applied to IAM resources"
  type        = map(string)

  default = {}
}


