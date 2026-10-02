aws_region = "us-east-1"

# Update your KMS key

kms_key_arn = "arn:aws:kms:us-east-1:xxxxxxx:key/xxxxxxx-xxxx-xxxx-xxxxx-xxxxxxxx"   

tags = {
  Environment = "Production"
  Application = "EBS-Encryption"
  Owner       = "Infrastructure"
}