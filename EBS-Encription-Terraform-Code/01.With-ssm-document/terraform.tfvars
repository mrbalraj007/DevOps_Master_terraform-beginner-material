aws_region = "ap-southeast-2" # us-east-1


# Update your KMS key
# "arn:aws:kms:us-east-1:xxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxxx-xxxxxxxx"
kms_key_arn = "arn:aws:kms:us-east-1:xxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxxx-xxxxxxxx"

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}