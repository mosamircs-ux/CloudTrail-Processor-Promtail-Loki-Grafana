#!/bin/bash

# Quick Fix Script - Update Region to me-south-1
# Run this on your Ubuntu EC2 instance

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Fixing Region Configuration - me-south-1                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Update .env file
echo "Updating .env file..."
cat > .env << 'EOF'
# AWS Configuration
AWS_REGION=me-south-1
S3_BUCKET=aws-cloudtrail-logs-124737196430-56a3b94b

# Processing Configuration
PROCESSING_INTERVAL=300  # seconds (5 minutes)

# Grafana Configuration
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
EOF

echo "✓ .env file updated"
echo ""

# Show the configuration
echo "Current configuration:"
cat .env
echo ""

# Restart the processor
echo "Restarting CloudTrail processor..."
docker-compose restart cloudtrail-processor
echo "✓ Processor restarted"
echo ""

# Wait a moment
echo "Waiting 5 seconds for processor to initialize..."
sleep 5

# Show logs
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Processor Logs (watching for success)                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Looking for 'AWS Region: me-south-1'..."
docker logs cloudtrail-processor 2>&1 | tail -20

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Next Steps                                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Monitor logs:"
echo "   docker logs -f cloudtrail-processor"
echo ""
echo "2. You should see:"
echo "   ✓ AWS Region: me-south-1"
echo "   ✓ Processing: AWSLogs/124737196430/CloudTrail/me-south-1/..."
echo "   ✓ Wrote X events to /app/processed/..."
echo ""
echo "3. Check processed files (after 5 minutes):"
echo "   ls -lh processed/"
echo ""
echo "4. Data should appear in Grafana within 10 minutes"
echo ""
