#!/bin/bash
# Apply the Conveyor Line Speed Monitoring dashboard with dynamic configuration

set -e

echo "🌐 Applying Conveyor Line Speed Monitoring Dashboard with Dynamic Configuration..."

# Run the automated dashboard configuration script
./configure_dashboard.sh

echo "🎉 Dashboard application completed using automated configuration!"
echo ""
echo "📊 The dashboard has been configured with:"
echo "   ✅ Dynamic IP addresses from Terraform"
echo "   ✅ Automatically discovered datasource UID"
echo "   ✅ Current InfluxDB bucket and token configuration"
echo "   ✅ Exact configuration from CA1\\Conveyor Line Speed Monitoring-1758520134746.json"
echo ""
echo "💡 To reconfigure the dashboard anytime with updated values, run:"
echo "   ./configure_dashboard.sh"