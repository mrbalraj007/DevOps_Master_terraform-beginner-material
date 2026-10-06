# Fetch the latest Ubuntu 26.04 LTS AMI
locals {
  ebs_volume_tags = {
    createdby   = "BSINGH"
    TechOwner   = "Singh Balraj"
    Infra       = "IT"
    Environment = "Non-Prod"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server*"] # For Ubuntu Instance.
    #values = ["amzn2-ami-hvm-*-x86_64*"] # For Amazon Instance.
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical owner ID for Ubuntu AMIs
  # owners = ["137112412989"] # Amazon owner ID for Amazon Linux AMIs
}

data "aws_ami" "windows_2025" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}


resource "aws_instance" "ubuntu-svr" {
  count                  = 1 # Create one instance
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "MYLABKEY" #change key name as per your setup
  vpc_security_group_ids = [aws_security_group.ubuntu-VM-SG.id]
  user_data              = templatefile("./jenkins_install.sh", {})

  #  instance_market_options {
  #    market_type = "spot"
  #    spot_options {
  #      max_price = "0.0051" # Set your maximum price for the spot instance
  #    }
  #  }

  tags = {
    Name = "ubuntu-${count.index + 1}" # This will create ubuntu-Trivy-1 and ubuntu-Trivy-2
  }

  root_block_device {
    volume_size = 8
  }

  dynamic "ebs_block_device" {
    for_each = toset(["f", "g", "h", "i", "j"])
    content {
      device_name           = "/dev/sd${ebs_block_device.value}"
      volume_size           = 1
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}

resource "aws_instance" "windows_2025" {
  ami                    = data.aws_ami.windows_2025.id
  instance_type          = "t3.small"
  key_name               = "MYLABKEY"
  vpc_security_group_ids = [aws_security_group.ubuntu-VM-SG.id]

  tags = {
    Name = "Windows-2025"
  }

  root_block_device {
    volume_size = 30
  }

  dynamic "ebs_block_device" {
    for_each = toset(["f", "g", "h", "i", "j"])
    content {
      device_name           = "/dev/sd${ebs_block_device.value}"
      volume_size           = 1
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}

locals {
  ubuntu_volume_ids = merge(
    {
      root = aws_instance.ubuntu-svr[0].root_block_device[0].volume_id
    },
    {
      for device in aws_instance.ubuntu-svr[0].ebs_block_device :
      device.device_name => device.volume_id
    }
  )
  windows_volume_ids = merge(
    {
      root = aws_instance.windows_2025.root_block_device[0].volume_id
    },
    {
      for device in aws_instance.windows_2025.ebs_block_device :
      device.device_name => device.volume_id
    }
  )
}

resource "aws_ec2_tag" "ubuntu_ebs_volume" {
  for_each = {
    for pair in setproduct(
      keys(local.ubuntu_volume_ids),
      keys(merge(local.ebs_volume_tags, { Name = "ubuntu-1" }))
      ) : "${pair[0]}:${pair[1]}" => {
      resource_id = local.ubuntu_volume_ids[pair[0]]
      key         = pair[1]
      value       = lookup(merge(local.ebs_volume_tags, { Name = "ubuntu-1" }), pair[1])
    }
  }

  resource_id = each.value.resource_id
  key         = each.value.key
  value       = each.value.value
}

resource "aws_ec2_tag" "windows_ebs_volume" {
  for_each = {
    for pair in setproduct(
      keys(local.windows_volume_ids),
      keys(merge(local.ebs_volume_tags, { Name = "Windows-2025" }))
      ) : "${pair[0]}:${pair[1]}" => {
      resource_id = local.windows_volume_ids[pair[0]]
      key         = pair[1]
      value       = lookup(merge(local.ebs_volume_tags, { Name = "Windows-2025" }), pair[1])
    }
  }

  resource_id = each.value.resource_id
  key         = each.value.key
  value       = each.value.value
}

resource "aws_security_group" "ubuntu-VM-SG" {
  name        = "ubuntu-SG"
  description = "Allow inbound traffic"

  dynamic "ingress" {
    for_each = toset([22, 3389]) #25, 22, 80, 443, 3389, 6443, 465, 8080, 9000, 3000
    content {
      description = "inbound rule for port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  #  ingress {
  #    description = "Custom TCP Port Range"
  #    from_port   = 2000
  #    to_port     = 11000
  #    protocol    = "tcp"
  #    cidr_blocks = ["0.0.0.0/0"]
  #  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubuntu-VM-SG"
  }
}

output "instance_ips" {
  value       = aws_instance.ubuntu-svr[*].public_ip
  description = "The public IPs of the ubuntu instances"
}

# You can also get individual IPs if needed
output "ubuntu_instance_ip" {
  value       = aws_instance.ubuntu-svr[0].public_ip
  description = "Public IP of the first ubuntu instance"
}

output "windows_2025_instance_ip" {
  value       = aws_instance.windows_2025.public_ip
  description = "Public IP of the Windows Server 2025 instance"
}