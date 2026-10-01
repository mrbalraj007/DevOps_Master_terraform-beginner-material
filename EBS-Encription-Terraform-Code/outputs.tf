output "ssm_automation_role_name" {
  description = "Name of the SSM Automation IAM role"
  value       = aws_iam_role.ssm_ebs_encryption_automation_role.name
}

output "ssm_automation_role_arn" {
  description = "ARN of the SSM Automation IAM role"
  value       = aws_iam_role.ssm_ebs_encryption_automation_role.arn
}

output "ssm_ebs_encryption_policy_arn" {
  description = "ARN of the EBS encryption IAM policy"
  value       = aws_iam_policy.ssm_ebs_encryption_policy.arn
}