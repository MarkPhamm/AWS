# 10 - VPC and Networking

## What is a VPC?

VPC stands for **Virtual Private Cloud**. It's your own private network inside AWS.

Think of it like this: AWS is a massive building with thousands of tenants. A VPC is your own private floor in that building -- other tenants can't see or access your floor unless you explicitly let them in.

Without a VPC, your resources (like MWAA, databases, etc.) would be sitting on the open internet. A VPC lets you control:

- **Who** can reach your resources
- **How** traffic flows in and out
- **Which** resources can talk to each other

Every AWS account comes with a "default VPC" in each region, but for production workloads (and for learning), you create your own.

## Key networking concepts

### CIDR Block (IP address range)

When you create a VPC, you give it a range of IP addresses. This is written in **CIDR notation**:

```
10.0.0.0/16
```

Breaking this down:

- `10.0.0.0` = the starting IP address
- `/16` = how many IPs are in this range

The `/16` means "the first 16 bits are fixed, the rest can vary." In practice:

- `/16` = 65,536 IP addresses (10.0.0.0 to 10.0.255.255)
- `/24` = 256 IP addresses (e.g., 10.0.1.0 to 10.0.1.255)
- `/28` = 16 IP addresses

For our learning project, `10.0.0.0/16` gives us plenty of room.

### Subnets

A subnet is a **smaller slice** of your VPC's IP range. Think of the VPC as the whole floor, and subnets as individual rooms on that floor.

Why split into subnets?

1. **Separation**: Put public-facing things in one subnet, private things in another
2. **Availability**: Put subnets in different data centers (availability zones) so if one goes down, the other still works
3. **Security**: Apply different rules to different subnets

There are two types:

**Public subnet** - Has a route to the internet gateway. Resources here CAN be reached from the internet (if their security group allows it).

**Private subnet** - NO direct route to the internet. Resources here are hidden from the outside world. They can still reach the internet outbound through a NAT gateway.

Example layout:

```
VPC: 10.0.0.0/16
  |
  +-- Public Subnet A:  10.0.1.0/24  (us-east-1a)   256 IPs
  +-- Public Subnet B:  10.0.2.0/24  (us-east-1b)   256 IPs
  +-- Private Subnet A: 10.0.10.0/24 (us-east-1a)   256 IPs
  +-- Private Subnet B: 10.0.20.0/24 (us-east-1b)   256 IPs
```

### Availability Zones (AZs)

AWS regions (like `us-east-1`) have multiple **availability zones** -- separate physical data centers. Examples: `us-east-1a`, `us-east-1b`, `us-east-1c`.

MWAA requires subnets in **at least 2 different AZs**. This is for high availability -- if one data center has a power outage, your Airflow keeps running in the other.

### Internet Gateway (IGW)

An internet gateway is the **front door** of your VPC. It connects your VPC to the public internet.

Without an IGW, nothing in your VPC can reach the internet, and nothing from the internet can reach your VPC.

You attach one IGW to one VPC. It's that simple.

```
Internet <---> Internet Gateway <---> VPC
```

### NAT Gateway

NAT stands for **Network Address Translation**.

Problem: Resources in private subnets can't reach the internet (that's the point of being private). But MWAA needs to download Python packages, talk to AWS services, etc.

Solution: A NAT gateway sits in a **public** subnet and acts as a middleman:

```
Private Subnet --> NAT Gateway (in public subnet) --> Internet Gateway --> Internet
```

The key difference from the IGW:

- **IGW**: Two-way door. Internet can reach in, resources can reach out.
- **NAT**: One-way door. Resources can reach OUT to the internet, but the internet CANNOT reach IN.

It's like a P.O. Box -- you can send mail out, and receive replies, but nobody knows your home address.

NAT gateways cost ~$0.045/hour (~$32/month). This is one of the main costs besides MWAA itself.

### Route Tables

A route table is a set of rules that tells traffic **where to go**. Every subnet is associated with a route table.

**Public subnet route table:**

```
Destination        Target
10.0.0.0/16        local          (traffic within the VPC stays in the VPC)
0.0.0.0/0          igw-xxxxx      (everything else goes to the internet gateway)
```

**Private subnet route table:**

```
Destination        Target
10.0.0.0/16        local          (traffic within the VPC stays in the VPC)
0.0.0.0/0          nat-xxxxx      (everything else goes through the NAT gateway)
```

`0.0.0.0/0` means "all destinations" -- it's the default route, the catch-all.

### Elastic IP (EIP)

A NAT gateway needs a **fixed public IP address**. An Elastic IP is a static IP that AWS reserves for you. It doesn't change even if you stop/start resources.

We allocate one EIP and assign it to the NAT gateway.

## How it all fits together

Here's the full picture for our MWAA setup:

```
                        Internet
                           |
                    Internet Gateway
                           |
                    +--------------+
                    |     VPC      |
                    |  10.0.0.0/16 |
                    |              |
    +---------------+--------------+---------------+
    |                                              |
    |  us-east-1a                  us-east-1b      |
    |                                              |
    |  +-------------+          +-------------+    |
    |  | Public      |          | Public      |    |
    |  | Subnet A    |          | Subnet B    |    |
    |  | 10.0.1.0/24 |          | 10.0.2.0/24 |    |
    |  |             |          |             |    |
    |  | [NAT GW]    |          |             |    |
    |  +------+------+          +-------------+    |
    |         |                                    |
    |  +------+------+          +-------------+    |
    |  | Private     |          | Private     |    |
    |  | Subnet A    |          | Subnet B    |    |
    |  | 10.0.10.0/24|          | 10.0.20.0/24|    |
    |  |             |          |             |    |
    |  |   [MWAA]    |          |   [MWAA]    |    |
    |  +-------------+          +-------------+    |
    |                                              |
    +----------------------------------------------+
```

Traffic flow when MWAA downloads a Python package:

1. MWAA (private subnet) sends request
2. Route table says "go to NAT gateway"
3. NAT gateway (public subnet) forwards to internet gateway
4. Internet gateway sends to the internet
5. Response comes back the same path in reverse

## Why MWAA needs all this

MWAA runs Apache Airflow containers inside your private subnets. It needs:

- **Private subnets** (2 minimum): Where the Airflow scheduler, workers, and web server run. Private because you don't want random internet traffic hitting your Airflow.
- **Internet access** (via NAT): To download Python packages from PyPI, pull Docker images, talk to AWS APIs.
- **Multiple AZs**: AWS requires this for MWAA -- if one AZ goes down, Airflow keeps running.

This is a common AWS pattern -- not just for MWAA. Databases (RDS), ECS containers, Lambda in VPC, and many other services use the same "private subnet + NAT gateway" setup.
