# Security Groups

## What is a Security Group?

A security group is a virtual firewall that controls inbound and outbound traffic for AWS resources. Every resource in a VPC must have at least one.

### Key Concepts

| Concept | What it is | Example |
| ------- | ---------- | ------- |
| **Inbound rule** | Traffic allowed IN | Allow SSH (port 22) from anywhere |
| **Outbound rule** | Traffic allowed OUT | Allow all traffic to anywhere |
| **Protocol** | TCP, UDP, ICMP, or all | `tcp`, `udp`, `-1` (all) |
| **Port range** | Which ports to allow | `22`, `80`, `443`, `0-65535` |
| **Source/Destination** | Who is allowed | CIDR (`0.0.0.0/0`), another security group |

### Defaults

- All **inbound** traffic: **DENIED** (nothing can reach your resource)
- All **outbound** traffic: **ALLOWED** (your resource can reach anything)

You only need to add rules for what you want to allow in.

### Stateful

Security groups are **stateful**: if you allow a request in, the response is automatically allowed out. You don't need matching outbound rules for inbound traffic.

```text
Inbound rule: Allow TCP 443 from 0.0.0.0/0
→ Request comes in on port 443: ✅ allowed
→ Response goes back out: ✅ automatically allowed (stateful)
```

This is different from Network ACLs, which are stateless (need rules for both directions).

### Self-referencing

A security group can reference itself as a source. This means "allow traffic from any resource with this same security group."

```text
Security Group: mwaa-sg
  Inbound: All traffic from mwaa-sg (self)

MWAA Scheduler (has mwaa-sg) ↔ MWAA Worker (has mwaa-sg) ← allowed
Random EC2 (different SG) → MWAA Worker ← blocked
```

### Common Port Numbers

| Port | Service | When you'd use it |
|------|---------|-------------------|
| 22 | SSH | Remote terminal access |
| 80 | HTTP | Web server (unencrypted) |
| 443 | HTTPS | Web server (encrypted) |
| 5432 | PostgreSQL | Database |
| 3306 | MySQL | Database |
| 6379 | Redis | Cache |

## Our Security Groups

| Security Group | Inbound | Outbound | Used by |
|---------------|---------|----------|---------|
| `ec2-sg` | SSH (22), HTTP (80) from anywhere | All traffic | EC2 instance |
| `mwaa-sg` | All traffic from self | All traffic | MWAA environment |

## Terraform Resources

| Resource | Purpose |
|----------|---------|
| `aws_security_group` | Create the security group (name, VPC, description) |
| `aws_security_group_rule` | Add individual inbound/outbound rules |

Defined in `aws_ec2.tf` (EC2 rules) and `aws_security_group.tf` (MWAA rules).

## Cost

Security groups are completely free. No limits on the number of groups or rules.
