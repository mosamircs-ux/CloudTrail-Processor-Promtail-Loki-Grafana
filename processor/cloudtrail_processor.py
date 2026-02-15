#!/usr/bin/env python3
"""
CloudTrail Log Processor for Access Key Monitoring
Extracts access key usage and resource information from CloudTrail logs
"""

import json
import gzip
import os
import sys
from datetime import datetime
from pathlib import Path
import boto3
from botocore.exceptions import ClientError
from botocore.config import Config
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CloudTrailProcessor:
    """Process CloudTrail logs and extract access key and resource information"""
    
    def __init__(self, s3_bucket, aws_region='me-south-1'):
        self.s3_bucket = s3_bucket
        self.aws_region = aws_region
        # For opt-in regions like me-south-1, explicitly set region_name
        # This ensures boto3 uses the correct regional endpoint
        self.s3_client = boto3.client(
            's3',
            region_name=aws_region,
            config=Config(
                signature_version='s3v4',
                s3={'addressing_style': 'path'}
            )
        )
        self.processed_files = self._load_processed_files()
        
    def _load_processed_files(self):
        """Load list of already processed files"""
        processed_file = Path('/app/processed/.processed_files.txt')
        if processed_file.exists():
            with open(processed_file, 'r') as f:
                return set(line.strip() for line in f)
        return set()
    
    def _save_processed_file(self, file_key):
        """Save processed file to tracking list"""
        processed_file = Path('/app/processed/.processed_files.txt')
        with open(processed_file, 'a') as f:
            f.write(f"{file_key}\n")
        self.processed_files.add(file_key)
    
    def extract_access_key(self, user_identity):
        """Extract access key from userIdentity"""
        if not user_identity:
            return "Unknown"
        
        # Direct access key
        if 'accessKeyId' in user_identity and user_identity['accessKeyId']:
            return user_identity['accessKeyId']
        
        # Session context (for assumed roles)
        if 'sessionContext' in user_identity:
            session_context = user_identity.get('sessionContext', {})
            session_issuer = session_context.get('sessionIssuer', {})
            if 'userName' in session_issuer:
                return f"Role:{session_issuer['userName']}"
        
        # Principal ID
        if 'principalId' in user_identity:
            principal_id = user_identity['principalId']
            if principal_id.startswith('AKIA'):
                return principal_id
            return f"Principal:{principal_id}"
        
        # ARN-based identification
        if 'arn' in user_identity:
            arn = user_identity['arn']
            if ':user/' in arn:
                return f"User:{arn.split(':user/')[-1]}"
            elif ':role/' in arn:
                return f"Role:{arn.split(':role/')[-1]}"
            elif ':root' in arn:
                return "Root"
        
        # User type
        user_type = user_identity.get('type', 'Unknown')
        return f"{user_type}:Unknown"
    
    def extract_resources(self, event):
        """Extract resource information from CloudTrail event"""
        resources = []
        
        # Check resources array
        if 'resources' in event and event['resources']:
            for resource in event['resources']:
                resource_info = {
                    'type': resource.get('type', 'Unknown'),
                    'name': resource.get('ARN', 'Unknown'),
                    'arn': resource.get('ARN', 'Unknown')
                }
                resources.append(resource_info)
        
        # Extract from requestParameters
        request_params = event.get('requestParameters', {})
        if request_params:
            # EC2 instances
            if 'instancesSet' in request_params:
                for instance in request_params['instancesSet'].get('items', []):
                    instance_id = instance.get('instanceId', 'Unknown')
                    resources.append({
                        'type': 'AWS::EC2::Instance',
                        'name': instance_id,
                        'arn': f"arn:aws:ec2:{event.get('awsRegion', 'unknown')}:{event.get('recipientAccountId', 'unknown')}:instance/{instance_id}"
                    })
            
            # S3 buckets
            if 'bucketName' in request_params:
                bucket_name = request_params['bucketName']
                resources.append({
                    'type': 'AWS::S3::Bucket',
                    'name': bucket_name,
                    'arn': f"arn:aws:s3:::{bucket_name}"
                })
            
            # RDS instances
            if 'dBInstanceIdentifier' in request_params:
                db_id = request_params['dBInstanceIdentifier']
                resources.append({
                    'type': 'AWS::RDS::DBInstance',
                    'name': db_id,
                    'arn': f"arn:aws:rds:{event.get('awsRegion', 'unknown')}:{event.get('recipientAccountId', 'unknown')}:db:{db_id}"
                })
            
            # Lambda functions
            if 'functionName' in request_params:
                func_name = request_params['functionName']
                resources.append({
                    'type': 'AWS::Lambda::Function',
                    'name': func_name,
                    'arn': f"arn:aws:lambda:{event.get('awsRegion', 'unknown')}:{event.get('recipientAccountId', 'unknown')}:function:{func_name}"
                })
        
        # Extract from responseElements
        response_elements = event.get('responseElements', {})
        if response_elements:
            # EC2 instances from response
            if 'instancesSet' in response_elements:
                for instance in response_elements['instancesSet'].get('items', []):
                    instance_id = instance.get('instanceId', 'Unknown')
                    resources.append({
                        'type': 'AWS::EC2::Instance',
                        'name': instance_id,
                        'arn': f"arn:aws:ec2:{event.get('awsRegion', 'unknown')}:{event.get('recipientAccountId', 'unknown')}:instance/{instance_id}"
                    })
        
        # If no resources found, create a generic one based on event
        if not resources:
            event_source = event.get('eventSource', 'unknown.amazonaws.com')
            service = event_source.replace('.amazonaws.com', '')
            resources.append({
                'type': f'AWS::{service.upper()}::Resource',
                'name': event.get('eventName', 'Unknown'),
                'arn': f"arn:aws:{service}:{event.get('awsRegion', 'unknown')}:{event.get('recipientAccountId', 'unknown')}:*"
            })
        
        return resources
    
    def process_event(self, event):
        """Process a single CloudTrail event"""
        try:
            user_identity = event.get('userIdentity', {})
            access_key = self.extract_access_key(user_identity)
            resources = self.extract_resources(event)
            
            # Create log entries for each resource
            processed_events = []
            for resource in resources:
                log_entry = {
                    'eventTime': event.get('eventTime'),
                    'eventName': event.get('eventName'),
                    'eventSource': event.get('eventSource'),
                    'awsRegion': event.get('awsRegion'),
                    'sourceIPAddress': event.get('sourceIPAddress'),
                    'userAgent': event.get('userAgent'),
                    'requestID': event.get('requestID'),
                    'errorCode': event.get('errorCode'),
                    'errorMessage': event.get('errorMessage'),
                    'userIdentity': {
                        'accessKeyId': access_key,
                        'principalId': user_identity.get('principalId', 'Unknown'),
                        'type': user_identity.get('type', 'Unknown'),
                        'arn': user_identity.get('arn', 'Unknown'),
                        'accountId': user_identity.get('accountId', 'Unknown')
                    },
                    'resourceType': resource['type'],
                    'resourceName': resource['name'],
                    'resourceARN': resource['arn']
                }
                processed_events.append(log_entry)
            
            return processed_events
        except Exception as e:
            logger.error(f"Error processing event: {e}")
            return []
    
    def download_and_process_logs(self):
        """Download CloudTrail logs from S3 and process them"""
        try:
            # List objects in S3 bucket
            logger.info(f"Listing objects in S3 bucket: {self.s3_bucket}")
            paginator = self.s3_client.get_paginator('list_objects_v2')
            
            for page in paginator.paginate(Bucket=self.s3_bucket):
                if 'Contents' not in page:
                    continue
                
                for obj in page['Contents']:
                    key = obj['Key']
                    
                    # Skip if already processed
                    if key in self.processed_files:
                        continue
                    
                    # Only process .json.gz files
                    if not key.endswith('.json.gz'):
                        continue
                    
                    logger.info(f"Processing: {key}")
                    
                    try:
                        # Download file
                        response = self.s3_client.get_object(Bucket=self.s3_bucket, Key=key)
                        
                        # Decompress and parse
                        with gzip.GzipFile(fileobj=response['Body']) as gzipfile:
                            content = gzipfile.read()
                            data = json.loads(content)
                        
                        # Process events
                        all_processed_events = []
                        for record in data.get('Records', []):
                            processed_events = self.process_event(record)
                            all_processed_events.extend(processed_events)
                        
                        # Write to output file
                        if all_processed_events:
                            output_file = Path('/app/processed') / f"{Path(key).stem}.jsonl"
                            with open(output_file, 'w') as f:
                                for event in all_processed_events:
                                    f.write(json.dumps(event) + '\n')
                            logger.info(f"Wrote {len(all_processed_events)} events to {output_file}")
                        
                        # Mark as processed
                        self._save_processed_file(key)
                        
                    except Exception as e:
                        logger.error(f"Error processing {key}: {e}")
                        continue
            
            logger.info("Processing complete")
            
        except ClientError as e:
            logger.error(f"AWS Error: {e}")
            sys.exit(1)
        except Exception as e:
            logger.error(f"Error: {e}")
            sys.exit(1)


def main():
    """Main entry point"""
    s3_bucket = os.environ.get('S3_BUCKET')
    aws_region = os.environ.get('AWS_REGION', 'me-south-1')
    
    if not s3_bucket:
        logger.error("S3_BUCKET environment variable not set")
        sys.exit(1)
    
    processor = CloudTrailProcessor(s3_bucket, aws_region)
    processor.download_and_process_logs()


if __name__ == '__main__':
    main()
