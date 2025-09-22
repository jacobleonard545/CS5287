# Sharing CA1 Terraform Code Across AWS Accounts

This guide explains how to share your CA1 Terraform infrastructure code so others can deploy it in their own AWS accounts.

## 🎯 Goal
Enable anyone to deploy the complete CA1 IoT pipeline in their own AWS account with minimal setup.

## 📋 Prerequisites for Recipients

### AWS Account Setup
- AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform installed (v1.0+)
- Bash shell (Git Bash on Windows)

### Required AWS Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "vpc:*",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
}
```

## 📦 Sharing Methods

### Method 1: GitHub Repository (Recommended)

#### For You (Repository Owner):
```bash
# 1. Initialize git repository
cd CA1
git init

# 2. Add all files except sensitive data
git add .
git commit -m "Initial CA1 infrastructure code"

# 3. Create GitHub repository and push
git remote add origin https://github.com/yourusername/ca1-infrastructure.git
git branch -M main
git push -u origin main
```

#### For Recipients:
```bash
# 1. Clone the repository
git clone https://github.com/yourusername/ca1-infrastructure.git
cd ca1-infrastructure

# 2. Follow setup instructions below
```

### Method 2: ZIP File Distribution
```bash
# Create distribution package
cd CA1
zip -r ca1-infrastructure.zip . -x "*.tfstate*" "*.log" ".terraform/*" "terraform.tfvars"

# Share the ZIP file
# Recipients extract and follow setup instructions
```

## 🚀 Setup Instructions for Recipients

### Step 1: Configure AWS
```bash
# Configure AWS CLI with their credentials
aws configure
# AWS Access Key ID: [Their Key]
# AWS Secret Access Key: [Their Secret]
# Default region: us-east-2 (or their preferred region)
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Step 2: Customize Configuration
```bash
# Copy the example configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Get their public IP for SSH access
MY_IP=$(curl -s ifconfig.me)
echo "Your public IP: $MY_IP"

# Edit the configuration file
vim terraform/terraform.tfvars
```

**Required changes in `terraform.tfvars`:**
```hcl
# REQUIRED: Replace with their actual IP
my_ip = "203.0.113.42/32"  # Their actual public IP

# RECOMMENDED: Unique project name to avoid conflicts
project_name = "CA1-johndoe"  # Their name/identifier

# REQUIRED: Change default passwords for security
influxdb_password = "TheirSecurePassword123!"
grafana_admin_password = "TheirSecureGrafanaPass456!"

# OPTIONAL: Different region if preferred
aws_region = "us-west-2"  # Their preferred region
```

### Step 3: Deploy
```bash
# Make scripts executable
chmod +x *.sh

# Deploy the infrastructure
./deploy.sh

# This will:
# - Check prerequisites
# - Generate SSH keys if needed
# - Deploy all infrastructure
# - Show access URLs and IPs
```

### Step 4: Validate
```bash
# Verify everything is working
./validate.sh

# Access the dashboard
# Grafana URL will be shown in deploy.sh output
```

### Step 5: Cleanup When Done
```bash
# Clean up all resources to avoid charges
./destroy.sh
```

## 🔧 Advanced Configuration Options

### Custom Instance Types
```hcl
# For accounts with higher limits
instance_type = "t3.small"
kafka_memory_limit = 512
kafka_heap_opts = "-Xmx256m -Xms128m"
```

### Different Regions
```hcl
# Some regions may be cheaper or closer
aws_region = "us-west-1"
# Note: May need to verify Ubuntu AMI availability
```

### Production Settings
```hcl
# For production deployments
environment = "production"
enable_backups = true
enable_monitoring = true
```

## 🛡️ Security Considerations

### What's Safe to Share
✅ **Terraform configuration files** (`.tf` files)
✅ **Setup scripts** (`deploy.sh`, `validate.sh`, etc.)
✅ **Documentation** (`README.md`, guides)
✅ **Example configurations** (`terraform.tfvars.example`)

### What to NEVER Share
❌ **Terraform state files** (`*.tfstate`)
❌ **Your actual tfvars** (`terraform.tfvars`)
❌ **SSH private keys** (`*.pem`, `*-key`)
❌ **AWS credentials** (`.aws/` directory)
❌ **Log files** containing sensitive data

### Automatic Exclusions
The `.gitignore` file automatically excludes sensitive files:
```
*.tfstate*
*.tfvars
*.pem
.terraform/
*.log
```

## 🤝 Collaboration Workflow

### For Teams/Organizations
```bash
# 1. Set up shared Terraform backend
# Edit terraform/backend.tf and uncomment S3 backend
terraform {
  backend "s3" {
    bucket = "your-team-terraform-state"
    key    = "ca1/terraform.tfstate"
    region = "us-east-2"
  }
}

# 2. Team members use shared state
terraform init  # Connects to shared backend
```

### For Individual Use
```bash
# Each person maintains their own state
# No backend configuration needed
# Each deployment is independent
```

## 📞 Support for Recipients

### Common Issues & Solutions

#### AWS CLI Not Configured
```bash
aws configure
# Follow prompts to enter credentials
```

#### Terraform Not Found
```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

#### IP Address Issues
```bash
# Get correct public IP
curl ifconfig.me
# Update terraform.tfvars with this IP
```

#### Resource Limits
```bash
# Check AWS service limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A
# May need to request limit increases
```

#### Permission Errors
```bash
# Verify AWS permissions
aws iam get-user
aws sts get-caller-identity
# May need broader EC2/VPC permissions
```

### Getting Help
1. **Check logs**: All scripts show detailed error messages
2. **Validate setup**: Run `./validate.sh` to check system status
3. **Review documentation**: `README.md` has troubleshooting section
4. **AWS Console**: Verify resources in AWS web console

## 💰 Cost Information for Recipients

### Expected Costs
- **5 x t2.micro instances**: ~$0.50/hour total
- **EBS storage**: ~$0.10/day
- **Data transfer**: Minimal for testing
- **Total daily cost**: ~$12-15/day

### Cost Optimization
```bash
# Use smaller instances
echo 'instance_type = "t2.nano"' >> terraform/terraform.tfvars

# Deploy in cheapest region
echo 'aws_region = "us-east-1"' >> terraform/terraform.tfvars

# Remember to destroy when done
./destroy.sh
```

## 📈 Next Steps for Recipients

After successful deployment:
1. **Explore Grafana dashboards** - Real-time conveyor monitoring
2. **Examine the code** - Learn IoT pipeline architecture
3. **Customize components** - Modify producer scripts, add sensors
4. **Scale the system** - Try larger instances, multiple producers
5. **Clean up resources** - Always run `./destroy.sh` when done

This infrastructure serves as a complete IoT data pipeline template that can be adapted for real-world use cases!