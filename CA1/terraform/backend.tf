# Remote State Backend Configuration
# Uncomment and configure for team/multi-machine usage

# Option 1: S3 Backend (Recommended for teams)
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "ca1/terraform.tfstate"
#     region         = "us-east-2"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"  # For state locking
#   }
# }

# Option 2: Terraform Cloud (Recommended for individuals)
# terraform {
#   cloud {
#     organization = "your-org-name"
#     workspaces {
#       name = "ca1-infrastructure"
#     }
#   }
# }

# Instructions:
# 1. Create S3 bucket for state storage
# 2. Create DynamoDB table for state locking
# 3. Uncomment and update the backend configuration
# 4. Run: terraform init -migrate-state