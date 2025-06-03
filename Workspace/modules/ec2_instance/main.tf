provider "aws" {
  region = var.aws_region
  
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

