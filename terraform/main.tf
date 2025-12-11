##################################################################################
# LEARNING NOTES & REQUIREMENTS ORDER
#
# 1. Base EC2 Instance:
#    We started by defining the `aws_instance` resource and the `data` source for
#    the Ubuntu AMI. This created the virtual machine itself.
#
# 2. Region Configuration (Provider):
#    (Located in provider.tf) We switched the region to `eu-north-1` to match
#    your CLI configuration.
#
# 3. Access & Networking:
#    We discovered we couldn't connect to the instance. To fix this, we added:
#    - `aws_key_pair`: To upload your local SSH public key.
#    - `aws_security_group`: To explicitly allow SSH traffic (Port 22).
#    - We then linked these to the `aws_instance` resource.
##################################################################################

##################################################################################
# 🏗️ INFRASTRUCTURE DEFINITION
#
# This file defines the "Hardware" layer of our Pi-hole deployment:
# 1. EC2 Instance (The Virtual Machine)
# 2. Security Group (The Firewall)
# 3. SSH Key (The Key to the Door)
##################################################################################

# --- Data Source: Ubuntu AMI ---
# Fetches the latest Ubuntu 22.04 AMI (Amazon Machine Image) ID dynamically.
# This ensures we always use the latest patched version when creating the instance.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (The publisher of Ubuntu)
}

# --- Requirement 3: SSH Key Pair ---
# Uploads the public key we generated locally (pihole_key.pub) to AWS.
# This allows AWS to inject the key into the server so we can SSH in.
resource "aws_key_pair" "deployer" {
  key_name   = "pihole-key"
  public_key = file("${path.module}/pihole_key.pub")
}

# --- Requirement 3: Security Group ---
# Acts as a virtual firewall for the instance.
# By default, AWS blocks all inbound traffic. We must explicitly allow it.
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"

  # Inbound Rule: Allow SSH (Port 22)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["81.196.215.162/32"]
  }

  # Inbound Rule: Allow HTTP (Port 80) for Pi-hole Web Interface
  ingress {
    description = "HTTP Web Interface"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["81.196.215.162/32"]
  }

  # Inbound Rule: Allow DNS (Port 53 TCP)
  ingress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["81.196.215.162/32"]
  }

  # Inbound Rule: Allow DNS (Port 53 UDP)
  ingress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["81.196.215.162/32"]
  }

  # Inbound Rule: Allow Flask Webhook (Port 5005)
  ingress {
    description = "Flask Webhook"
    from_port   = 5005
    to_port     = 5005
    protocol    = "tcp"
    cidr_blocks = ["81.196.215.162/32"]
  }

  # Outbound Rule: Allow everything
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http_dns"
  }
}

# --- Requirement 1: EC2 Instance ---
# The actual Virtual Machine resource.
resource "aws_instance" "pihole" {
  ami = data.aws_ami.ubuntu.id
  # We switched from t2.micro (not free tier in this region?) to t3.micro
  instance_type = "t3.micro"

  # References the key pair created above
  key_name = aws_key_pair.deployer.key_name

  # References the security group created above
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "PiHole - AWS - Testing"
  }
}
