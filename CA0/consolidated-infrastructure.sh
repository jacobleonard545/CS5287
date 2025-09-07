#!/bin/bash

# AWS Infrastructure Provisioning Script - T2.Micro Optimized
# Consolidated deployment for cost optimization

set -e

# Configuration
REGION="us-east-2"
KEY_NAME="kafka-pipeline-key"
SUBNET_ID=""  # Will be populated after VPC creation
SECURITY_GROUP_ID=""  # Will be populated after SG creation
AMI_ID="ami-0c02fb55956c7d316"  # Ubuntu 22.04 LTS (use latest for your region)

echo "🚀 Starting AWS Infrastructure Provisioning (t2.micro optimized)..."

# Create VPC
echo "📡 Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region $REGION \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=kafka-pipeline-vpc}]' \
  --query 'Vpc.VpcId' --output text)

echo "✅ VPC Created: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $REGION

# Create Internet Gateway
echo "🌐 Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=kafka-pipeline-igw}]' \
  --query 'InternetGateway.InternetGatewayId' --output text)

# Attach Internet Gateway
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
echo "✅ Internet Gateway Created and Attached: $IGW_ID"

# Create Subnet
echo "🏗️ Creating Subnet..."
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --region $REGION \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=kafka-pipeline-subnet}]' \
  --query 'Subnet.SubnetId' --output text)

echo "✅ Subnet Created: $SUBNET_ID"

# Create Route Table
echo "🗺️ Creating Route Table..."
RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=kafka-pipeline-rt}]' \
  --query 'RouteTable.RouteTableId' --output text)

# Add route to Internet Gateway
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION

# Associate Route Table with Subnet
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RT_ID --region $REGION
echo "✅ Route Table Created and Associated: $RT_ID"

# Create Security Group
echo "🔐 Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name kafka-pipeline-sg \
  --description "Security group for Kafka pipeline project" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=kafka-pipeline-sg}]' \
  --query 'GroupId' --output text)

# Add security group rules
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 9092 --source-group $SECURITY_GROUP_ID --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 27017 --source-group $SECURITY_GROUP_ID --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8081 --cidr 0.0.0.0/0 --region $REGION

echo "✅ Security Group Created: $SECURITY_GROUP_ID"

# Create Key Pair (if not exists)
echo "🔑 Creating Key Pair..."
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION >/dev/null 2>&1; then
    aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
    chmod 400 ${KEY_NAME}.pem
    echo "✅ Key Pair Created: $KEY_NAME"
else
    echo "⚠️ Key Pair already exists: $KEY_NAME"
fi

# Launch EC2 Instances - CONSOLIDATED DEPLOYMENT
echo "🖥️ Launching EC2 Instances (2 VMs for cost optimization)..."

# Function to launch instance
launch_instance() {
    local name=$1
    local instance_id=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type t2.micro \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP_ID \
        --subnet-id $SUBNET_ID \
        --associate-public-ip-address \
        --region $REGION \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" \
        --user-data file://user-data.sh \
        --query 'Instances[0].InstanceId' --output text)
    
    echo "✅ Instance launched: $name ($instance_id)"
    return 0
}

# Launch consolidated instances
launch_instance "kafka-mongodb-vm"    # Kafka + MongoDB + UIs
launch_instance "processor-producer-vm"  # Processor + Producer

echo "🎉 Infrastructure provisioning complete!"
echo "📋 Summary:"
echo "   VPC ID: $VPC_ID"
echo "   Subnet ID: $SUBNET_ID"
echo "   Security Group ID: $SECURITY_GROUP_ID"
echo "   Key Pair: $KEY_NAME"

# Save configuration for later use
cat > infrastructure-config.txt << EOF
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
SECURITY_GROUP_ID=$SECURITY_GROUP_ID
KEY_NAME=$KEY_NAME
REGION=$REGION
EOF

echo "💾 Configuration saved to infrastructure-config.txt"
echo "⏳ Wait 2-3 minutes for instances to initialize, then run: aws ec2 describe-instances --region $REGION"
echo "💡 Cost Optimization: Using 2 t2.micro instances instead of 4 larger instances"