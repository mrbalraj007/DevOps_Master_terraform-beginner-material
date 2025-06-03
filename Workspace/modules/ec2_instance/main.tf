provider "aws" {
  region = var.aws_region
  
}
variable "aws_region" { 
  description = "The aws region to be used for the aws account"
  type = string
}

variable "ami_id" {
  description = "The AMI ID to use for the instance"
  type        = string
  
}

variable "instance_type" {
    description = "The type of instance to create"
    type        = string
    default     = "t2.micro"
  }

resource "aws_instance" "example" { 
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = "ExampleInstance"
  }
  
}

