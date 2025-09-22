# Local values for consistent naming and resource management

locals {
  # Create unique suffix for resource naming
  deployment_suffix = var.deployment_id != "" ? "-${var.deployment_id}" : ""

  # Consistent naming convention for all resources
  name_prefix = "${var.project_name}-${var.environment}${local.deployment_suffix}"

  # Common tags for all resources
  common_tags = {
    Project       = var.project_name
    Environment   = var.environment
    DeploymentId  = var.deployment_id
    ManagedBy     = "Terraform"
    CreatedBy     = "CA1-Infrastructure"
  }
}