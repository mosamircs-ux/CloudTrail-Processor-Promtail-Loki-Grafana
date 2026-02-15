#!/bin/bash

# CloudTrail Monitoring - Quick Diagnostics
# Run this on your Ubuntu EC2 to check why there's no data

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   CloudTrail Monitoring Stack - Diagnostics               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: Docker Services
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Docker Services Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker-compose ps
echo ""

# Check 2: AWS Credentials
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  AWS Credentials Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker exec cloudtrail-processor aws sts get-caller-identity 2>&1 | grep -q "UserId"; then
    echo -e "${GREEN}✓ AWS credentials are valid${NC}"
    docker exec cloudtrail-processor aws sts get-caller-identity
else
    echo -e "${RED}✗ AWS credentials test failed${NC}"
    docker exec cloudtrail-processor aws sts get-caller-identity 2>&1 | head -5
fi
echo ""

# Check 3: S3 Bucket Access
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  S3 Bucket Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
S3_BUCKET=$(grep S3_BUCKET .env | cut -d '=' -f2)
echo "Bucket: $S3_BUCKET"
if docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET 2>&1 | grep -q "AWSLogs"; then
    echo -e "${GREEN}✓ S3 bucket is accessible${NC}"
    echo "Contents:"
    docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET
else
    echo -e "${RED}✗ Cannot access S3 bucket${NC}"
    docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET 2>&1
fi
echo ""

# Check 4: CloudTrail Logs Exist
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  CloudTrail Logs in S3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOG_COUNT=$(docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET/AWSLogs/124737196430/CloudTrail/me-south-1/ --recursive 2>/dev/null | grep ".json.gz" | wc -l)
if [ "$LOG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $LOG_COUNT CloudTrail log files${NC}"
    echo "Recent logs:"
    docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET/AWSLogs/124737196430/CloudTrail/me-south-1/ --recursive 2>/dev/null | grep ".json.gz" | tail -5
else
    echo -e "${RED}✗ No CloudTrail logs found in S3${NC}"
    echo -e "${YELLOW}⚠ CloudTrail might not be enabled or configured${NC}"
fi
echo ""

# Check 5: Processed Files
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Processed Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "processed" ]; then
    FILE_COUNT=$(ls -1 processed/*.jsonl 2>/dev/null | wc -l)
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $FILE_COUNT processed files${NC}"
        ls -lh processed/ | head -10
    else
        echo -e "${YELLOW}⚠ No processed files yet${NC}"
        echo "Processor may not have run successfully"
    fi
else
    echo -e "${RED}✗ Processed directory doesn't exist${NC}"
    mkdir -p processed
fi
echo ""

# Check 6: Processor Logs
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  CloudTrail Processor Logs (last 30 lines)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker logs cloudtrail-processor 2>&1 | tail -30
echo ""

# Check 7: Promtail Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7️⃣  Promtail Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if docker logs promtail 2>&1 | grep -q "POST.*loki.*push"; then
    echo -e "${GREEN}✓ Promtail is shipping logs to Loki${NC}"
    echo "Recent shipments:"
    docker logs promtail 2>&1 | grep "POST.*loki.*push" | tail -5
else
    echo -e "${YELLOW}⚠ Promtail hasn't shipped any logs yet${NC}"
    echo "Recent Promtail logs:"
    docker logs promtail 2>&1 | tail -10
fi
echo ""

# Check 8: Loki Data
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8️⃣  Loki Data Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LOKI_LABELS=$(docker exec loki wget -qO- 'http://localhost:3100/loki/api/v1/label/job/values' 2>/dev/null)
if echo "$LOKI_LABELS" | grep -q "cloudtrail"; then
    echo -e "${GREEN}✓ Loki has CloudTrail data${NC}"
    echo "$LOKI_LABELS"
else
    echo -e "${YELLOW}⚠ No CloudTrail data in Loki yet${NC}"
    echo "Response: $LOKI_LABELS"
fi
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   SUMMARY & RECOMMENDATIONS                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Determine issues
ISSUES=0

if ! docker-compose ps | grep -q "cloudtrail-processor.*Up"; then
    echo -e "${RED}❌ CloudTrail processor is not running${NC}"
    echo "   Fix: docker-compose restart cloudtrail-processor"
    ISSUES=$((ISSUES+1))
fi

if ! docker exec cloudtrail-processor aws sts get-caller-identity 2>&1 | grep -q "UserId"; then
    echo -e "${RED}❌ AWS credentials are invalid or missing${NC}"
    echo "   Fix: Edit config/aws-credentials with valid credentials"
    ISSUES=$((ISSUES+1))
fi

if ! docker exec cloudtrail-processor aws s3 ls s3://$S3_BUCKET 2>&1 | grep -q "AWSLogs"; then
    echo -e "${RED}❌ Cannot access S3 bucket${NC}"
    echo "   Fix: Apply IAM policy from iam-policy.json"
    ISSUES=$((ISSUES+1))
fi

if [ "$LOG_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No CloudTrail logs found in S3${NC}"
    echo "   Fix: Enable CloudTrail in AWS Console"
    ISSUES=$((ISSUES+1))
fi

if [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No processed files yet${NC}"
    echo "   Wait: Processor runs every 5 minutes"
    echo "   Or: Run manually: docker exec cloudtrail-processor python3 /app/cloudtrail_processor.py"
fi

if [ "$ISSUES" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ No critical issues found!${NC}"
    echo ""
    echo "If still no data in Grafana:"
    echo "  1. Wait 10 minutes for processing cycle"
    echo "  2. Check Grafana at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
    echo "  3. Manually run processor: docker exec cloudtrail-processor python3 /app/cloudtrail_processor.py"
else
    echo ""
    echo -e "${RED}Found $ISSUES critical issue(s) - fix them first${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "For detailed troubleshooting, see: TROUBLESHOOTING.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
