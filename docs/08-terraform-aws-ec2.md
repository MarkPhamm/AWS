# 08 - Terraform EC2 Syntax Breakdown

This is a line-by-line breakdown of `terraform/aws_ec2.tf`.

## What this file creates

Four things:

1. **Security Group** - firewall rules for the EC2 instance (SSH + HTTP in, all out)
2. **Key Pair** - uploads your SSH public key to AWS so you can log in
3. **Data Source** - looks up the latest Amazon Linux 2023 AMI
4. **EC2 Instance** - a t3.micro virtual server in a public subnet

## Resource 1: Security Group

```hcl
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instance - allows SSH and HTTP"
  vpc_id      = aws_vpc.mwaa.id

  tags = {
    Name        = "${var.project_name}-ec2-sg"
    Environment = var.environment
  }
}
```

### Breaking down the security group

**Line: `resource "aws_security_group" "ec2"`**

- `"aws_security_group"` = resource type for a security group (firewall)
- `"ec2"` = our label. Referenced as `aws_security_group.ec2`

**Line: `vpc_id = aws_vpc.mwaa.id`**

- Every security group belongs to a VPC
- This references the VPC we created in `aws_vpc.tf`
- Creates a dependency - Terraform creates the VPC first

## Security Group Rules

```hcl
resource "aws_security_group_rule" "ec2_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "ec2_inbound_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
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
```

### Breaking down the rules

**Why separate resources for rules?**

You could define rules inline inside `aws_security_group`, but Terraform recommends
using separate `aws_security_group_rule` resources. This avoids conflicts when
multiple files or modules add rules to the same security group.

**Line: `type = "ingress"` vs `type = "egress"`**

- `"ingress"` = inbound traffic (coming INTO the instance)
- `"egress"` = outbound traffic (going OUT from the instance)

**Lines: `from_port` and `to_port`**

- These define a port range. For a single port, both are the same number.
- SSH uses port `22`, HTTP uses port `80`
- For the egress rule, `0` to `0` with protocol `"-1"` means "all ports, all protocols"

**Line: `protocol = "tcp"` vs `protocol = "-1"`**

- `"tcp"` = TCP protocol (used by SSH, HTTP, HTTPS, most web traffic)
- `"-1"` = all protocols (TCP, UDP, ICMP, etc.)

**Line: `cidr_blocks = ["0.0.0.0/0"]`**

- `0.0.0.0/0` = "any IP address on the internet"
- In production, you'd restrict SSH to your own IP (e.g., `["203.0.113.50/32"]`)
- `/32` means a single IP, `/0` means all IPs

**Line: `security_group_id = aws_security_group.ec2.id`**

- Which security group this rule belongs to
- References the security group we created above

### Summary of the 3 rules

| Rule | Direction | Port | Protocol | Source/Dest | Purpose |
| ---- | --------- | ---- | -------- | ----------- | ------- |
| `ec2_inbound_ssh` | Ingress | 22 | TCP | `0.0.0.0/0` | Allow SSH from anywhere |
| `ec2_inbound_http` | Ingress | 80 | TCP | `0.0.0.0/0` | Allow HTTP from anywhere |
| `ec2_outbound_all` | Egress | All | All | `0.0.0.0/0` | Allow all outbound traffic |

## Resource 2: Key Pair

```hcl
resource "aws_key_pair" "ec2" {
  key_name   = "${var.project_name}-ec2-key"
  public_key = var.ec2_public_key

  tags = {
    Name        = "${var.project_name}-ec2-key"
    Environment = var.environment
  }
}
```

### Breaking down the key pair

**Line: `resource "aws_key_pair" "ec2"`**

- `"aws_key_pair"` = resource type for an SSH key pair
- AWS stores the public key. You keep the private key on your machine.

**Line: `public_key = var.ec2_public_key`**

- The public key content (e.g., `ssh-ed25519 AAAA... your@email`)
- Stored in `terraform.tfvars` (which is NOT committed to git - it contains secrets)
- You generate the key pair locally first:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/aws-ec2-key
```

This creates two files:

- `~/.ssh/aws-ec2-key` → private key (stays on your machine, never shared)
- `~/.ssh/aws-ec2-key.pub` → public key (uploaded to AWS via Terraform)

### How SSH key authentication works

```text
Your machine                          EC2 instance
┌──────────────┐                    ┌──────────────┐
│ Private key  │──── SSH handshake ─│ Public key   │
│ (~/.ssh/     │    (proves you     │ (uploaded by │
│  aws-ec2-key)│     own the key)   │  Terraform)  │
└──────────────┘                    └──────────────┘
```

The private key proves your identity. Anyone with the public key can verify you, but
they can't impersonate you without the private key. This is why you never share the
private key.

## Data Source: AMI Lookup

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### Breaking down the AMI lookup

**Keyword: `data` instead of `resource`**

- `resource` = "create something in AWS"
- `data` = "look something up in AWS" (read-only, doesn't create anything)
- Data sources let you query AWS for existing information

**Line: `data "aws_ami" "amazon_linux"`**

- `"aws_ami"` = the data source type (look up an AMI)
- `"amazon_linux"` = our label. Referenced as `data.aws_ami.amazon_linux`
- Note the `data.` prefix - that's how you distinguish data sources from resources

**Line: `most_recent = true`**

- AMIs are updated regularly (security patches, new versions)
- `most_recent = true` = "give me the newest one that matches my filters"
- Without this, you'd get an error if multiple AMIs match

**Line: `owners = ["amazon"]`**

- Only look at AMIs published by Amazon (not community or marketplace AMIs)
- This is a safety measure - you don't want a random person's AMI

**Block: `filter { ... }`**

Filters narrow down which AMI to return. We use two:

1. **Name filter**: `al2023-ami-*-x86_64`
   - `al2023` = Amazon Linux 2023
   - `*` = wildcard (matches any version number)
   - `x86_64` = 64-bit Intel/AMD architecture
2. **Virtualization filter**: `hvm`
   - HVM = Hardware Virtual Machine (modern, fast)
   - The alternative is `paravirtual` (older, slower) - you'll never use it

**Why not hardcode the AMI ID?**

AMI IDs are different in every region AND change when Amazon releases updates:

```text
us-east-1: ami-0abcdef1234567890   ← valid today, outdated next month
us-west-2: ami-0987654321fedcba0   ← different ID for the same OS
```

The `data` source always finds the current one automatically.

## Resource 3: The EC2 Instance

```hcl
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
```

### Breaking down the instance

**Line: `resource "aws_instance" "learning"`**

- `"aws_instance"` = resource type for an EC2 instance
- `"learning"` = our label. Referenced as `aws_instance.learning`

**Line: `ami = data.aws_ami.amazon_linux.id`**

- Which operating system to use
- References the data source above (note the `data.` prefix)
- `.id` returns the AMI ID (e.g., `ami-0abcdef1234567890`)

**Line: `instance_type = "t3.micro"`**

- The size of the virtual machine
- `t3` = burstable family (good for variable workloads)
- `micro` = 2 vCPU, 1 GB RAM
- Free tier eligible (750 hours/month for 12 months)

```text
Instance type naming:  t3.micro
                       │  │
                       │  └── Size (nano < micro < small < medium < large)
                       └── Family + generation (t = burstable, 3 = 3rd gen)
```

**Line: `subnet_id = aws_subnet.public_a.id`**

- Which subnet to launch the instance in
- `public_a` = a public subnet in us-east-1a (defined in `aws_vpc.tf`)
- Public subnet means the instance gets a public IP and is reachable from the internet

**Line: `vpc_security_group_ids = [aws_security_group.ec2.id]`**

- Which firewall rules apply to this instance
- It's a list `[ ]` because an instance can have multiple security groups
- We use just one: the EC2 security group we created above

**Line: `key_name = aws_key_pair.ec2.key_name`**

- Which SSH key pair to install on the instance
- References the key pair resource above
- `.key_name` returns the name (not the ID) because that's what `aws_instance` expects

## Outputs

```hcl
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance — use this to SSH in"
  value       = aws_instance.learning.public_ip
}

output "ec2_ssh_command" {
  description = "Copy-paste this to SSH into your instance"
  value       = "ssh -i ~/.ssh/aws-ec2-key ec2-user@${aws_instance.learning.public_ip}"
}
```

### Breaking down the outputs

**Keyword: `output`**

- Outputs are values printed after `terraform apply`
- Useful for information you need after creation (IPs, URLs, ARNs)
- You can also retrieve them later with `terraform output`

**Line: `value = aws_instance.learning.public_ip`**

- `.public_ip` = an attribute that AWS returns after creating the instance
- You can't know the IP beforehand - AWS assigns it at launch time
- Outputs are the way to get these "computed" values out of Terraform

**The SSH command output:**

```text
ssh -i ~/.ssh/aws-ec2-key ec2-user@34.201.xx.xx
│    │                     │         │
│    │                     │         └── public IP (from output)
│    │                     └── default user for Amazon Linux
│    └── path to your private key
└── SSH command
```

## New syntax in this file

### Data sources

```hcl
# Resource (creates something):
resource "aws_instance" "learning" { ... }

# Data source (looks something up):
data "aws_ami" "amazon_linux" { ... }
```

- Reference a resource: `aws_instance.learning.id`
- Reference a data source: `data.aws_ami.amazon_linux.id` (note the `data.` prefix)

### Output blocks

```hcl
output "name" {
  description = "What this value is"
  value       = some_resource.label.attribute
}
```

- Printed after `terraform apply`
- Retrievable with `terraform output name`
- Can be used by other Terraform configurations (modules)

### Filter blocks

```hcl
filter {
  name   = "name"
  values = ["pattern-*"]
}
```

- Used in data sources to narrow down results
- `name` = which attribute to filter on
- `values` = list of acceptable values (supports wildcards)
- Multiple filter blocks = AND logic (all must match)

## How the resources connect

```text
aws_vpc.tf                     variables.tf
    │                               │
    │ .id (VPC, subnet)            │ ec2_public_key
    ▼                               ▼
aws_ec2.tf
    │
    ├── aws_security_group.ec2          (vpc_id = aws_vpc.mwaa.id)
    │       │
    │       ├── aws_security_group_rule.ec2_inbound_ssh
    │       ├── aws_security_group_rule.ec2_inbound_http
    │       └── aws_security_group_rule.ec2_outbound_all
    │
    ├── aws_key_pair.ec2                (public_key = var.ec2_public_key)
    │
    ├── data.aws_ami.amazon_linux       (looks up latest AMI)
    │
    └── aws_instance.learning           (references all of the above)
            │
            └── outputs: ec2_public_ip, ec2_ssh_command
```

Terraform figures out the order automatically:

1. Look up the AMI (data source, no dependencies)
2. Create the security group (depends on VPC)
3. Create the security group rules (depend on security group)
4. Create the key pair (no dependencies beyond the variable)
5. Create the EC2 instance (depends on AMI, subnet, security group, key pair)
6. Output the public IP (depends on instance)
