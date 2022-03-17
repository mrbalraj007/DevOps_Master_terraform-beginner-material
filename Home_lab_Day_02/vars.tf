variable "ami" {
  type = map(any)

  default = {
    "us-east-1" = "ami-033b95fb8079dc481" # Amazon Linux 2 AMI (HVM) - Kernel 5.10,
    "us-west-1" = "ami-04169656fea786776" #  ubuntu
  }
}

variable "instance_count" {
  default = "2"
}

variable "instance_tags" {
  type    = list(any)
  default = ["Terraform-1", "Terraform-2"]
}

variable "instance_type" {
  default = "t2.micro"
}

variable "aws_region" {
  default = "us-east-1"
}