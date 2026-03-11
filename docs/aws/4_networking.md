# VPC and Networking

## What is a VPC?

A VPC (Virtual Private Cloud) is your own isolated network inside AWS. All your resources (EC2, MWAA, databases) live inside a VPC.

### Key Concepts

| Concept | What it is | Analogy |
| ------- | ---------- | ------- |
| **VPC** | Your private network | Your own floor in a building |
| **Subnet** | A subdivision of the VPC | Rooms on that floor |
| **CIDR block** | IP address range | `10.0.0.0/16` = 65,536 IPs |
| **Internet Gateway** | VPC's door to the internet | Front door |
| **NAT Gateway** | One-way outbound internet for private subnets | P.O. Box |
| **Route Table** | Traffic rules (where to send packets) | Road signs |
| **Elastic IP** | A static public IP address | A fixed phone number |
| **Availability Zone** | A separate data center in a region | Different buildings |

### Public vs Private Subnets

| | Public Subnet | Private Subnet |
| --- | --- | --- |
| Internet access | Direct (via Internet Gateway) | Outbound only (via NAT Gateway) |
| Reachable from internet? | Yes (if security group allows) | No |
| Gets public IP? | Yes (`map_public_ip_on_launch`) | No |
| Use for | EC2 (SSH access), NAT Gateway, load balancers | MWAA, databases, internal services |

### CIDR Notation

```text
10.0.0.0/16  → 65,536 IPs  (10.0.0.0 - 10.0.255.255)
10.0.1.0/24  → 256 IPs     (10.0.1.0 - 10.0.1.255)
10.0.0.0/28  → 16 IPs      (10.0.0.0 - 10.0.0.15)
```

The number after `/` = how many bits are fixed. Smaller number = more IPs.

### Traffic Flow

**EC2 in public subnet (direct internet):**

```text
EC2 ↔ Route Table (0.0.0.0/0 → IGW) ↔ Internet Gateway ↔ Internet
```

**MWAA in private subnet (outbound only):**

```text
MWAA → Route Table (0.0.0.0/0 → NAT) → NAT Gateway → IGW → Internet
Internet → NAT Gateway → ✗ blocked (NAT is one-way outbound)
```

### Route Tables

Every subnet is associated with a route table. Two rules matter:

| Destination | Target | Meaning |
| --- | --- | --- |
| `10.0.0.0/16` | `local` | Traffic within the VPC stays in the VPC |
| `0.0.0.0/0` | `igw-xxx` or `nat-xxx` | Everything else goes to IGW (public) or NAT (private) |

## Our Network Layout

```text
VPC: 10.0.0.0/16
  │
  ├── Public Subnet A:  10.0.1.0/24  (us-east-1a)  ← NAT GW, EC2
  ├── Public Subnet B:  10.0.2.0/24  (us-east-1b)
  ├── Private Subnet A: 10.0.10.0/24 (us-east-1a)  ← MWAA
  └── Private Subnet B: 10.0.20.0/24 (us-east-1b)  ← MWAA
```

## Terraform Resources

| Resource | Purpose |
| --- | --- |
| `aws_vpc` | The VPC itself |
| `aws_subnet` (x4) | 2 public + 2 private subnets |
| `aws_internet_gateway` | VPC's connection to the internet |
| `aws_eip` | Static IP for the NAT gateway |
| `aws_nat_gateway` | Outbound internet for private subnets |
| `aws_route_table` (x2) | Public routes (→ IGW) and private routes (→ NAT) |
| `aws_route_table_association` (x4) | Link each subnet to its route table |

All defined in `aws_vpc.tf`.

## Cost

| Resource | Cost |
| ---------- | ------ |
| VPC, subnets, IGW, route tables | Free |
| NAT Gateway | ~$0.045/hr (~$32/month) |
| Elastic IP (while attached to NAT) | Free |
| Elastic IP (unattached) | ~$0.005/hr |
