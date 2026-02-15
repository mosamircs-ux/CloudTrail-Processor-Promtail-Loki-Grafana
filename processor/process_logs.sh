#!/bin/bash

# CloudTrail Log Processing Script
# Runs continuously and processes new logs at regular intervals

INTERVAL=${PROCESSING_INTERVAL:-300}  # Default: 5 minutes

echo "Starting CloudTrail log processor..."
echo "Processing interval: ${INTERVAL} seconds"
echo "S3 Bucket: ${S3_BUCKET}"
echo "AWS Region: ${AWS_REGION}"

while true; do
    echo "================================================"
    echo "Processing CloudTrail logs at $(date)"
    echo "================================================"
    
    python3 /app/cloudtrail_processor.py
    
    if [ $? -eq 0 ]; then
        echo "Processing completed successfully"
    else
        echo "Processing failed with error code $?"
    fi
    
    echo "Waiting ${INTERVAL} seconds before next run..."
    sleep ${INTERVAL}
done
