resource "aws_key_pair" "terraform-demo" {
  key_name   = "MYLABKEY1"
  public_key = file("id_rsa.pub")
}

resource "aws_instance" "my-instance" {
  count         = var.instance_count
  ami           = lookup(var.ami, var.aws_region)
  instance_type = var.instance_type
  key_name      = aws_key_pair.terraform-demo.key_name
  user_data     = file("install_httpd.sh")

  tags = {
    Name  = element(var.instance_tags, count.index)
    Batch = "5AM"
  }
}