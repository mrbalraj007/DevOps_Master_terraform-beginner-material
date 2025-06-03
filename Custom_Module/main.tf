provider "aws" {
  region = "us-east-1"
}

# calling the module
module "ec2_instance" {
  source              = "./modules/EC2_instance"
  ami_value           = "ami-066784287e358dad1"
  instance_type_value = "t2.micro"
  subnet_id_value     = "subnet-227ede46"
  key_name_value      = "MYLABKEY"
}