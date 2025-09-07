#!/bin/bash

# User Data Script for EC2 Instances
# Installs Docker, Docker Compose, and basic utilities

# Update system
apt-get update -y
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    unzip \
    jq \
    htop \
    net-tools \
    ufw \
    fail2ban

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Configure UFW Firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 9092/tcp  # Kafka (will be restricted to VPC in security groups)
ufw allow 27017/tcp # MongoDB (will be restricted to VPC in security groups) 
ufw allow 8080/tcp  # Kafka UI
ufw allow 8081/tcp  # Mongo Express
ufw --force enable

# Security hardening
echo "# Security hardening" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_source_route = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
sysctl -p

# Disable password authentication for SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

# Configure fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

# Enable Docker service
systemctl enable docker
systemctl start docker

# Create application directories
mkdir -p /opt/kafka-pipeline/{config,data,logs}
chown -R ubuntu:ubuntu /opt/kafka-pipeline

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Clean up
rm -f awscliv2.zip
rm -rf aws/

# Set timezone
timedatectl set-timezone UTC

# Configure log rotation
cat > /etc/logrotate.d/kafka-pipeline << 'EOF'
/opt/kafka-pipeline/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 ubuntu ubuntu
}
EOF

# Install Java (for Kafka and processor)
apt-get install -y openjdk-17-jdk

# Install Python (for producer)
apt-get install -y python3 python3-pip python3-venv

# Create startup script placeholder
cat > /opt/kafka-pipeline/start-services.sh << 'EOF'
#!/bin/bash
# This script will be populated with service-specific startup commands
echo "Starting services..."
EOF

chmod +x /opt/kafka-pipeline/start-services.sh

# Log completion
echo "$(date): User data script completed successfully" > /var/log/user-data.log