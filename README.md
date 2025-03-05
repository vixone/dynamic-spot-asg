# ECS Auto Scaling with Spot & On-Demand Instances

## Overview
This Terraform template sets up an **ECS cluster** with an **Auto Scaling Group (ASG)** that dynamically provisions both **Spot and On-Demand instances** using **attribute-based instance type selection**.

## Features
- **Auto Scaling Group (ASG)** with Spot & On-Demand instances
- **Attribute-based instance selection** for flexibility & cost optimization
- **Managed scaling** to auto-adjust ASG size based on ECS task demand
- **Capacity-Optimized Spot allocation** for best availability
- **IAM roles & instance profiles** for ECS integration

## Configuration
### **Auto Scaling Policy**
- **30% On-Demand, 70% Spot**
- Target **80% utilization** before scaling up
- Supports instances with **32-64 vCPUs & 32-128 GB RAM** (AMD/Intel only)

### **Instance Type Filtering**
✅ Includes: Compute-optimized & general-purpose instances  
❌ Excludes: ARM-based, storage-optimized, GPU, & specialized instances

## Deployment
1. **Update variables** (e.g., AMI, subnets, SSH key)
2. **Initialize Terraform**:
   ```sh
   terraform init
   ```
3. **Apply the configuration**:
   ```sh
   terraform apply -auto-approve
   ```

## TODO 
- Add **CloudWatch alarms** for Spot interruptions
- Creat a custom **AWS lambda** to drain spot instances marked for interruption

