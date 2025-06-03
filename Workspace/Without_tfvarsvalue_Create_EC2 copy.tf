provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the instance"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to create"
  type        = map(string)
  default     = {
    dev = "t2.micro"
    stage = "t3.micro"
    prod = "m5.large"
  }
}

module "ec2_instance" {
  source        = "./modules/ec2_instance"
  ami_id        = var.ami_id
  aws_region    = var.aws_region
  instance_type = lookup(var.instance_type, terraform.workspace, "t2.micro")
}