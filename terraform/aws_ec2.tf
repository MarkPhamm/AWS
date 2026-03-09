# aws_ec2.tf - A free-tier EC2 instance for learning
#
# This file creates:
#   - A security group for the EC2 instance (allow SSH + HTTP)
#   - A key pair for SSH access
#   - A t2.micro instance (free tier eligible) in a public subnet


# ─── 1. Security Group for EC2 ──────────────────────────────────────
#
# Separate from the MWAA security group. This one allows:
#   - SSH (port 22) from anywhere — so you can connect to it
#   - HTTP (port 80) from anywhere — in case you run a web server
#   - All outbound traffic — so the instance can reach the internet

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance - allows SSH and HTTP"
  vpc_id      = aws_vpc.mwaa.id

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "ec2_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # ↑ Allows SSH from anywhere. In production, you'd restrict this
  #   to your own IP (e.g., "203.0.113.50/32"). Fine for learning.
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "ec2_inbound_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # ↑ Allows HTTP from anywhere — useful if you run a web server on port 80
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "ec2_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}


# ─── 2. Key Pair ────────────────────────────────────────────────────
#
# A key pair lets you SSH into the instance.
#
# How to use:
#   1. Generate a key pair locally:  ssh-keygen -t ed25519 -f ~/.ssh/aws-ec2-key
#   2. Copy the public key content into terraform.tfvars:
#        ec2_public_key = "ssh-ed25519 AAAA... your@email"
#   3. Terraform uploads the public key to AWS
#   4. You SSH with the private key:  ssh -i ~/.ssh/aws-ec2-key ec2-user@<public-ip>

resource "aws_key_pair" "ec2" {
  key_name   = "${var.project_name}-ec2-key"
  public_key = var.ec2_public_key

  tags = {
    Name        = "${var.project_name}-ec2-key"
    Environment = var.environment
  }
}


# ─── 3. EC2 Instance ────────────────────────────────────────────────
#
# t2.micro = 1 vCPU, 1 GB RAM — free tier eligible (750 hrs/month for 12 months)
#
# We place it in public_a so it gets a public IP and is directly reachable via SSH.
# The AMI is Amazon Linux 2023 — AWS's own lightweight Linux distro.
#
# data "aws_ami" looks up the latest Amazon Linux 2023 AMI automatically,
# so you don't need to hardcode an AMI ID (they differ by region and change over time).

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
    # ↑ Amazon Linux 2023, 64-bit x86
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
    # ↑ HVM = Hardware Virtual Machine (the modern/fast virtualization type)
  }
}

resource "aws_instance" "learning" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.ec2.key_name

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }
}


# ─── 4. Outputs ─────────────────────────────────────────────────────
#
# After `terraform apply`, these values are printed so you know how to connect.

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance — use this to SSH in"
  value       = aws_instance.learning.public_ip
}

output "ec2_ssh_command" {
  description = "Copy-paste this to SSH into your instance"
  value       = "ssh -i ~/.ssh/aws-ec2-key ec2-user@${aws_instance.learning.public_ip}"
}
