# 11 - Security Groups

## What is a Security Group?

A security group is a **virtual firewall** that controls traffic to and from your AWS resources.

Think of it like a bouncer at a club:

- The bouncer has a list of **who's allowed in** (inbound rules)
- And a list of **who's allowed out** (outbound rules)
- Anyone not on the list gets blocked

Every AWS resource that runs inside a VPC (MWAA, EC2 instances, databases, etc.) must be assigned at least one security group.

## Inbound vs Outbound Rules

**Inbound rules** = traffic coming IN to your resource

- "Allow HTTPS traffic from the internet" (port 443)
- "Allow database connections from my app servers" (port 5432)

**Outbound rules** = traffic going OUT from your resource

- "Allow all outbound traffic" (most common -- let your resource talk to anything)
- "Only allow traffic to my database" (more restrictive)

By default:

- All **inbound** traffic is **DENIED** (nothing can reach your resource)
- All **outbound** traffic is **ALLOWED** (your resource can reach anything)

## How Rules Work

Each rule has these parts:

| Field | What it means | Example |
|-------|---------------|---------|
| **Type** | Protocol | TCP, UDP, All traffic |
| **Port range** | Which ports to allow | 443 (HTTPS), 5432 (PostgreSQL), 0-65535 (all) |
| **Source/Destination** | Who is allowed | An IP range, another security group, or `0.0.0.0/0` (anywhere) |

## Security Groups are Stateful

This is important: security groups are **stateful**. This means:

If you allow an **inbound** request, the **response** is automatically allowed out -- even if there's no outbound rule for it.

Example: If MWAA receives a request on port 443 (allowed by inbound rule), the response goes back automatically. You don't need a separate outbound rule for the response.

This is different from **Network ACLs** (NACLs), which are stateless and require explicit rules for both directions. We won't use NACLs in this project.

## Self-referencing Security Groups

A security group can reference **itself** as a source. This is a common pattern:

```
Inbound rule:
  Source: sg-abc123 (this same security group)
  Port: All

  Meaning: "Allow traffic from any resource that has THIS security group attached"
```

This is exactly what MWAA needs. The MWAA scheduler, workers, and web server all have the same security group. The self-referencing rule lets them talk to each other freely.

## What MWAA needs

For MWAA, we create one security group with:

**Inbound:**

- Allow all traffic from itself (self-referencing) -- so MWAA components can communicate

**Outbound:**

- Allow all traffic to anywhere -- so MWAA can download packages, reach AWS APIs, etc.

```
Security Group: mwaa-sg
  Inbound:  All traffic from mwaa-sg (self)
  Outbound: All traffic to 0.0.0.0/0 (anywhere)
```

This is the simplest secure setup. MWAA components can talk to each other, MWAA can reach the internet, but nothing from outside can reach MWAA directly (unless you add more inbound rules later).

## Security Groups vs Network ACLs

You might see "Network ACL" (NACL) mentioned in AWS docs. Quick comparison:

| Feature | Security Group | Network ACL |
|---------|---------------|-------------|
| Level | Resource (instance) | Subnet |
| Stateful? | Yes | No |
| Rules | Allow only | Allow and Deny |
| Default | Deny all inbound | Allow all |
| Evaluation | All rules evaluated together | Rules evaluated in order |

For this project, security groups are all we need. NACLs are an extra layer you'd add in production but are not required for MWAA.
