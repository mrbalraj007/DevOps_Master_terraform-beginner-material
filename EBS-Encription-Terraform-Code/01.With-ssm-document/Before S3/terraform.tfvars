aws_region = "ap-southeast-2" # us-east-1


# Update your KMS key
# "arn:aws:kms:us-east-1:xxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxxx-xxxxxxxx"
kms_key_arn = "arn:aws:kms:ap-southeast-2:110187533252:key/94ddd0d1-0bcc-41bb-b9bc-5d19122076bf"

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}