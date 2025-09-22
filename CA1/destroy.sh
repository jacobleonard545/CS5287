#!/bin/bash
# CA1 Infrastructure Cleanup Script
# Safely destroys all CA1 infrastructure resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

echo -e "${BLUE}=== CA1 Infrastructure Cleanup ===${NC}"
echo "This will destroy all CA1 infrastructure resources"
echo ""

# Show current resources
show_current_resources() {
    echo -e "${YELLOW}Current resources:${NC}"

    cd "$TERRAFORM_DIR"

    if [ -f "terraform.tfstate" ]; then
        echo "Instances:"
        /c/Users/J14Le/bin/terraform.exe output producer_instance_ip 2>/dev/null && echo "  ✓ CA1-conveyor-producer"
        /c/Users/J14Le/bin/terraform.exe output kafka_instance_ip 2>/dev/null && echo "  ✓ CA1-kafka-hub"
        /c/Users/J14Le/bin/terraform.exe output processor_instance_ip 2>/dev/null && echo "  ✓ CA1-data-processor"
        /c/Users/J14Le/bin/terraform.exe output influxdb_instance_ip 2>/dev/null && echo "  ✓ CA1-influx-db"
        /c/Users/J14Le/bin/terraform.exe output grafana_instance_ip 2>/dev/null && echo "  ✓ CA1-grafana-dash"

        echo ""
        echo "Infrastructure:"
        /c/Users/J14Le/bin/terraform.exe output vpc_id 2>/dev/null && echo "  ✓ VPC"
        /c/Users/J14Le/bin/terraform.exe output public_subnet_id 2>/dev/null && echo "  ✓ Subnet"
        echo "  ✓ Security Groups"
        echo "  ✓ SSH Key Pair"
    else
        echo "No Terraform state found - nothing to destroy"
        exit 0
    fi
    echo ""
}

# Confirm destruction
confirm_destruction() {
    echo -e "${RED}⚠️  WARNING: This will permanently delete all CA1 resources!${NC}"
    echo ""
    echo "This includes:"
    echo "  • All 5 EC2 instances"
    echo "  • VPC and networking components"
    echo "  • Security groups"
    echo "  • SSH key pair"
    echo "  • All data in InfluxDB and Kafka"
    echo ""

    read -p "Are you sure you want to destroy all CA1 resources? (type 'yes' to confirm): " confirmation

    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Destruction cancelled${NC}"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}Proceeding with destruction...${NC}"
}

# Destroy infrastructure
destroy_infrastructure() {
    echo -e "${YELLOW}Destroying infrastructure...${NC}"

    cd "$TERRAFORM_DIR"

    # Plan destruction
    echo "Creating destruction plan..."
    /c/Users/J14Le/bin/terraform.exe plan -destroy -out=destroy.tfplan

    # Apply destruction
    echo "Applying destruction..."
    /c/Users/J14Le/bin/terraform.exe apply destroy.tfplan

    # Clean up plan files
    rm -f destroy.tfplan tfplan

    echo -e "${GREEN}✅ Infrastructure destroyed successfully${NC}"
    echo ""
}

# Clean up local files (optional)
cleanup_local_files() {
    echo -e "${YELLOW}Cleaning up local files...${NC}"

    read -p "Remove SSH key (~/.ssh/ca1-demo-key)? (y/n): " remove_key

    if [ "$remove_key" = "y" ] || [ "$remove_key" = "Y" ]; then
        rm -f ~/.ssh/ca1-demo-key ~/.ssh/ca1-demo-key.pub
        echo -e "${GREEN}✅ SSH key removed${NC}"
    else
        echo -e "${BLUE}ℹ️  SSH key preserved for future use${NC}"
    fi

    echo ""
}

# Show cleanup summary
show_cleanup_summary() {
    echo -e "${BLUE}=== Cleanup Summary ===${NC}"
    echo -e "${GREEN}✅ All CA1 infrastructure resources destroyed${NC}"
    echo -e "${GREEN}✅ AWS charges stopped${NC}"
    echo ""

    if [ -f ~/.ssh/ca1-demo-key ]; then
        echo -e "${BLUE}ℹ️  SSH key preserved: ~/.ssh/ca1-demo-key${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Verify no unexpected AWS charges"
    echo "2. Run './deploy.sh' to redeploy if needed"
    echo "3. Check AWS console to confirm resource deletion"
}

# Main execution
main() {
    echo "Starting CA1 cleanup..."
    echo "Timestamp: $(date)"
    echo ""

    show_current_resources
    confirm_destruction
    destroy_infrastructure
    cleanup_local_files
    show_cleanup_summary

    echo -e "${GREEN}🎉 CA1 cleanup script completed!${NC}"
}

# Error handling
trap 'echo -e "${RED}❌ Cleanup failed at line $LINENO${NC}"' ERR

# Run main function
main "$@"