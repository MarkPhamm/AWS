# aws_security_group.tf - Firewall rules for MWAA
#
# A security group controls what traffic can reach MWAA
# and what traffic MWAA can send out.


# ─── 1. Security Group ────────────────────────────────────────────────
#
# This security group will be attached to the MWAA environment.
# MWAA's scheduler, workers, and web server all share this group.

resource "aws_security_group" "mwaa" {
  name        = "${var.mwaa_project_name}-mwaa-sg"
  description = "Security group for MWAA environment"
  vpc_id      = aws_vpc.mwaa.id

  tags = {
    Name        = "${var.mwaa_project_name}-mwaa-sg"
    Environment = var.environment
  }
}


# ─── 2. Inbound Rule (self-referencing) ───────────────────────────────
#
# "Allow all traffic FROM resources that have this same security group"
#
# Why: MWAA's scheduler, workers, and web server need to talk to each other.
# Since they all have this security group, the self-reference lets them communicate.
#
# protocol = "-1" means "all protocols" (TCP, UDP, ICMP, everything)
# self = true means "the source is this same security group"

resource "aws_security_group_rule" "mwaa_inbound_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.mwaa.id
}


# ─── 3. Outbound Rule (all traffic) ──────────────────────────────────
#
# "Allow all outbound traffic to anywhere"
#
# Why: MWAA needs to reach the internet to:
#   - Download Python packages (pip install from PyPI)
#   - Talk to AWS APIs (S3, CloudWatch, SQS, etc.)
#   - Communicate with the NAT gateway
#
# cidr_blocks = ["0.0.0.0/0"] means "any destination"

resource "aws_security_group_rule" "mwaa_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mwaa.id
}
