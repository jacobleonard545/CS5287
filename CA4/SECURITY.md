# CA4 Security Configuration

## ⚠️ IMPORTANT: Secrets Management

This repository contains **TEMPLATE FILES ONLY** for secrets and credentials. Never commit actual secrets to version control.

## Files to Configure Before Deployment

### 1. Cloud Environment Variables

**File**: `.env.cloud` (gitignored)
**Template**: `.env.cloud.template`

```bash
# Copy template and edit
cp .env.cloud.template .env.cloud

# Generate secure values
INFLUXDB_PASSWORD=$(openssl rand -base64 16)
INFLUXDB_TOKEN=$(openssl rand -base64 32)
GRAFANA_PASSWORD=$(openssl rand -base64 16)

# Edit .env.cloud with generated values
```

### 2. Kubernetes Secrets

**File**: `k8s/secrets.yaml` (gitignored after first use)
**Template**: `k8s/secrets.yaml.template`

```bash
# The repository version has placeholders like REPLACE_WITH_*
# Generate secure values before deployment:

# API Key
openssl rand -base64 32

# InfluxDB Token
openssl rand -base64 32

# Passwords
openssl rand -base64 16
```

### 3. SSH Keys

**Files**: `~/.ssh/ca4-key`, `~/.ssh/ca4-key.pub` (never in repo)

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ca4-key -C "ca4-deployment"

# Terraform will use the public key
```

### 4. TLS Certificates

**Files**: `tls-certs/*.pem` (gitignored, regenerate per deployment)

```bash
# Generate self-signed certificates for InfluxDB
cd CA4/tls-certs
openssl genrsa -out influxdb-key.pem 2048
openssl req -new -key influxdb-key.pem -out influxdb-csr.pem -subj "/C=US/ST=Tennessee/L=Nashville/O=VanderbiltU/CN=influxdb"
openssl x509 -req -days 365 -in influxdb-csr.pem -signkey influxdb-key.pem -out influxdb-cert.pem
```

## Security Best Practices

### ✅ What IS Safe to Commit
- Template files (`.template` suffix)
- Configuration files with placeholders (`REPLACE_WITH_*`)
- Documentation and README files
- Scripts that don't contain credentials
- `.gitignore` file

### ❌ What to NEVER Commit
- Actual `.env` files with real credentials
- SSH private keys (`.pem`, `.key` files)
- TLS certificates and private keys
- `terraform.tfstate` (contains sensitive infrastructure data)
- `k8s/secrets.yaml` with actual values
- AWS credentials or access keys
- Any file containing passwords, tokens, or API keys

## Files Currently Gitignored

The following file patterns are protected by `.gitignore`:

```
.env
.env.cloud
.env.local
*.pem
*.key
ca4-key
tls-certs/*.pem
tls-certs/*.key
k8s/secrets.yaml
terraform/*.tfstate
terraform/.terraform/
.ssh/
```

## Production Security Recommendations

For production deployments, consider:

1. **Secrets Management**:
   - Use HashiCorp Vault or AWS Secrets Manager
   - Never use environment variables for secrets in production
   - Rotate credentials regularly

2. **Certificate Management**:
   - Use Let's Encrypt or corporate PKI
   - Automate certificate rotation with cert-manager
   - Never use self-signed certificates in production

3. **Access Control**:
   - Implement RBAC in Kubernetes
   - Use IAM roles instead of access keys in AWS
   - Enable MFA for all admin accounts
   - Restrict security group rules to specific IPs

4. **Network Security**:
   - Use VPN or PrivateLink instead of SSH tunnels
   - Implement service mesh with mTLS
   - Enable encryption in transit for all services
   - Use network policies to segment traffic

5. **Audit and Compliance**:
   - Enable CloudTrail for AWS API logging
   - Use Kubernetes audit logs
   - Implement log aggregation with retention
   - Regular security scans and penetration testing

## Current Security Measures (CA4)

### ✅ Implemented
- SSH key-based authentication (no passwords)
- TLS/HTTPS for InfluxDB
- AWS Security Groups with minimal open ports
- Docker container memory limits
- Grafana authentication required
- Git-ignored secrets files

### ⚠️ Demo/Development Only
- Self-signed TLS certificates
- Hardcoded demo credentials in templates
- Public SSH access (port 22 open to 0.0.0.0/0)
- Grafana HTTP port exposed (port 3000)
- No secrets rotation
- No audit logging

### 🔧 TODO for Production
- [ ] Replace self-signed certs with CA-signed
- [ ] Integrate with Vault or AWS Secrets Manager
- [ ] Implement automated secrets rotation
- [ ] Enable CloudTrail and audit logging
- [ ] Add Falco for runtime security
- [ ] Implement network segmentation
- [ ] Add intrusion detection (AWS GuardDuty)
- [ ] Enable encryption at rest for InfluxDB

## Incident Response

If credentials are accidentally committed:

1. **Immediate Actions**:
   ```bash
   # Remove from history
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch <file>" \
     --prune-empty --tag-name-filter cat -- --all

   # Force push (requires team coordination)
   git push origin --force --all
   ```

2. **Rotate All Credentials**:
   - Generate new passwords and tokens
   - Update deployed applications
   - Revoke old credentials
   - Document the incident

3. **Review and Prevent**:
   - Update `.gitignore` if needed
   - Add pre-commit hooks to check for secrets
   - Consider using tools like `git-secrets` or `detect-secrets`

## Contact

For security issues or questions about secrets management:
- Review this document first
- Check `.gitignore` for protected files
- Verify templates have `REPLACE_WITH_` placeholders
- Never commit actual credentials

## References

- [OWASP Secrets Management](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/)
