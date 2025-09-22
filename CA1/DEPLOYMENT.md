# CA1 Multi-Machine/Multi-Account Deployment Guide

This guide covers deploying CA1 on different machines or AWS accounts.

## Potential Issues & Solutions

### 1. 🏗️ **Terraform State Management**

**Problem**: Local state files aren't portable between machines

**Solution Options:**

#### Option A: S3 Backend (Recommended for Teams)
```bash
# 1. Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket-name

# 2. Create DynamoDB table for locking
aws dynamodb create-table \
    --table-name terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# 3. Update backend.tf with your bucket name
# 4. Initialize with backend
terraform init -migrate-state
```

#### Option B: Terraform Cloud (Recommended for Individuals)
```bash
# 1. Create account at app.terraform.io
# 2. Update backend.tf with your organization
# 3. Initialize
terraform login
terraform init
```

### 2. 🔐 **AWS Account Dependencies**

**Issues:**
- Different AWS account IDs
- Region-specific AMI IDs
- VPC/subnet conflicts
- Security group naming conflicts

**Solutions:**

#### Environment Isolation
```bash
# Copy template for new environment
cp terraform.tfvars.example terraform.tfvars

# Customize for your account
vim terraform.tfvars
```

Update `terraform.tfvars`:
```hcl
# Use different project name per account/environment
project_name = "CA1-prod"      # Instead of "CA1"
environment  = "production"    # Instead of "dev"

# Your IP for SSH access
my_ip = "203.0.113.42/32"     # Your actual public IP

# Different AWS region if needed
aws_region = "us-west-2"      # Instead of us-east-2

# Strong passwords for production
influxdb_password = "SuperSecurePassword123!"
grafana_admin_password = "AnotherSecurePassword456!"
```

### 3. 🔑 **SSH Key Management**

**Problem**: SSH keys need to exist on each machine

**Solutions:**

#### Option A: Generate Keys Per Machine
```bash
# Let deploy.sh generate keys automatically
./deploy.sh  # Will create ~/.ssh/ca1-demo-key if not exists
```

#### Option B: Share Existing Keys
```bash
# Copy keys to new machine
scp ~/.ssh/ca1-demo-key* user@new-machine:~/.ssh/
chmod 400 ~/.ssh/ca1-demo-key
```

#### Option C: Use Different Key Names
```bash
# Update terraform.tfvars
public_key_path = "~/.ssh/my-custom-key.pub"
```

### 4. 🌐 **Network IP Restrictions**

**Problem**: `my_ip` variable needs to be updated for each user

**Solution**: Dynamic IP detection
```bash
# Get your current public IP
curl ifconfig.me

# Update terraform.tfvars
my_ip = "$(curl -s ifconfig.me)/32"
```

### 5. 💰 **AWS Service Limits & Costs**

**Issues:**
- Free tier limits (750 hours/month per instance type)
- Regional service availability
- Concurrent instance limits

**Solutions:**

#### Check Limits Before Deployment
```bash
# Check current EC2 usage
aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name==`running`].[InstanceType,LaunchTime]' --output table

# Check available regions
aws ec2 describe-regions --output table
```

#### Cost Optimization
```bash
# Use smaller instances in resource-constrained accounts
echo 'instance_type = "t2.nano"' >> terraform.tfvars

# Deploy in cheapest regions
echo 'aws_region = "us-east-1"' >> terraform.tfvars
```

## Step-by-Step Deployment on New Machine/Account

### Step 1: Prerequisites
```bash
# Install required tools
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# Configure AWS
aws configure
```

### Step 2: Clone and Configure
```bash
# Clone project
git clone <repository-url>
cd CA1

# Create configuration from template
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Get your public IP
MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"

# Update configuration
sed -i "s/YOUR_PUBLIC_IP/$MY_IP/g" terraform/terraform.tfvars
```

### Step 3: Configure Backend (Optional but Recommended)
```bash
# For S3 backend
vim terraform/backend.tf  # Uncomment and configure S3 backend

# For Terraform Cloud
terraform login
vim terraform/backend.tf  # Uncomment and configure cloud backend
```

### Step 4: Deploy
```bash
# Deploy infrastructure
./deploy.sh

# Validate deployment
./validate.sh
```

### Step 5: Cleanup When Done
```bash
./destroy.sh
```

## Troubleshooting Cross-Account Issues

### AMI Not Found Error
```bash
# Error: AMI not available in region
# Solution: Use different region or update AMI filters
aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu*amd64*" \
    --query 'Images[*].[ImageId,Name,CreationDate]' \
    --output table
```

### Resource Naming Conflicts
```bash
# Error: Resource already exists
# Solution: Use unique project names
echo 'project_name = "CA1-$(whoami)-$(date +%Y%m%d)"' >> terraform/terraform.tfvars
```

### Permission Denied Errors
```bash
# Check AWS permissions
aws sts get-caller-identity
aws iam get-user

# Required permissions:
# - EC2 full access
# - VPC full access
# - IAM limited access (for key pairs)
```

### State File Conflicts
```bash
# Error: State file locked
# Solution: Force unlock (use carefully)
terraform force-unlock <lock-id>

# Or reset state (destroys infrastructure)
rm terraform.tfstate*
terraform init
```

## Production Considerations

### Security Hardening
```hcl
# In terraform.tfvars
my_ip = "YOUR_OFFICE_IP/32"  # Restrict SSH access
influxdb_password = "$(openssl rand -base64 32)"  # Strong passwords
grafana_admin_password = "$(openssl rand -base64 32)"
```

### High Availability
```hcl
# Multi-AZ deployment
enable_multi_az = true
availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

# Larger instances
instance_type = "t3.small"
kafka_instance_type = "t3.medium"
influxdb_instance_type = "t3.large"
```

### Monitoring & Backup
```hcl
# Enable CloudWatch
enable_cloudwatch = true
log_retention_days = 30

# Enable backups
enable_backups = true
backup_retention_days = 7
```

## Team Collaboration Workflow

### Initial Setup (Team Lead)
```bash
# 1. Set up shared S3 backend
aws s3 mb s3://team-terraform-state
aws dynamodb create-table --table-name team-terraform-locks ...

# 2. Configure backend.tf
# 3. Initial deployment
terraform init
./deploy.sh
```

### Team Member Setup
```bash
# 1. Clone repository
git clone <repo>

# 2. Configure AWS credentials
aws configure

# 3. Initialize with shared backend
terraform init

# 4. Check current state
terraform plan
./validate.sh
```

This guide ensures smooth deployment across different environments while avoiding common pitfalls!