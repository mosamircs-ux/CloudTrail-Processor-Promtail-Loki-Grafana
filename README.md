# AWS CloudTrail Monitoring Stack (Processor + Promtail + Loki + Grafana)

An enterprise-grade, end-to-end log monitoring and analytics pipeline for **AWS CloudTrail**. This project periodically fetches, decompresses, and formats CloudTrail audit logs from AWS S3, ingests them into **Grafana Loki** via **Promtail**, and provides visual security analytics dashboards in **Grafana**.

---

## 📌 Project Overview

AWS CloudTrail records API calls and account activities across your AWS infrastructure. However, raw CloudTrail logs stored in S3 as compressed `.json.gz` files can be challenging to query and analyze in real time. 

This stack automates the entire pipeline:
1. **CloudTrail Processor**: Downloads `.json.gz` logs from S3, extracts individual CloudTrail events, formats them into structured JSON Lines (`.jsonl`), and saves them locally.
2. **Promtail**: Scrapes the processed JSONL logs and streams them to Loki with structured metadata tags.
3. **Grafana Loki**: Indexes and stores log streams efficiently.
4. **Grafana**: Visualizes security events, user activity, access key usage, and suspicious API actions using pre-built dashboards.

---

## 🏗️ Architecture Breakdown

```
 ┌─────────────────┐       ┌────────────────────────┐       ┌────────────────┐
 │   AWS S3 Bucket │ ────► │  cloudtrail-processor  │ ────► │ ./processed/*. │
 │ (CloudTrail GZ) │       │   (Python container)   │       │     jsonl      │
 └─────────────────┘       └────────────────────────┘       ───────┬────────┘
                                                                    │
 ┌─────────────────┐       ┌────────────────────────┐               │
 │ Grafana Dashboards│ ◄─── │  Grafana Loki (3100)   │ ◄─────────────┘
 │  (Port 3000)    │       │     (Log Store)        │   (Scraped by Promtail)
 └─────────────────┘       └────────────────────────┘
```

### Stack Components

| Service | Container Name | Description | Ports / Volumes |
| :--- | :--- | :--- | :--- |
| **CloudTrail Processor** | `cloudtrail-processor` | Custom Python service fetching logs from AWS S3 and formatting them. | `./logs`, `./processed` |
| **Promtail** | `promtail` | Log collector shipping logs to Loki. | Scrapes `./processed` |
| **Loki** | `loki` | High-performance log aggregation engine. | `3100:3100` |
| **Grafana** | `grafana` | Analytics UI with pre-configured Loki datasource & security dashboards. | `3000:3000` |

---

## 🚀 Deployment Guide on VPS / AWS EC2 (Ubuntu)

Follow these steps to deploy the monitoring stack on a remote Virtual Private Server (VPS) or AWS EC2 instance.

### 1. Prerequisites

Before starting, ensure your VPS or EC2 instance has:
* **Docker** & **Docker Compose** installed.
* Ports **3000** (Grafana) open in your security group / firewall.
* An active **AWS CloudTrail** trail writing logs to an S3 bucket.
* IAM credentials with read permissions to your CloudTrail S3 bucket.

---

### 2. Uploading Project to VPS

#### Option A: From Windows using PowerShell (`upload-to-ec2.ps1`)
If you are uploading from a local Windows machine, edit `upload-to-ec2.ps1` with your server IP and key path, then run:

```powershell
.\upload-to-ec2.ps1
```

#### Option B: Via SSH / Git Clone
Connect to your VPS and clone or extract the repository into your home directory:

```bash
ssh -i /path/to/your-key.pem ubuntu@<YOUR_VPS_IP>
cd ~/CloudTrail-Processor-Promtail-Loki-Grafana
```

---

### 3. AWS Credentials Configuration

Copy the template file and insert your AWS IAM Access Key ID and Secret Access Key:

```bash
cp config/aws-credentials.template config/aws-credentials
nano config/aws-credentials
```

Set your credentials in `config/aws-credentials`:
```ini
[default]
aws_access_key_id = YOUR_AWS_ACCESS_KEY_ID
aws_secret_access_key = YOUR_AWS_SECRET_ACCESS_KEY
```

> 🔒 **Security Note**: Ensure your IAM user has the permissions specified in `iam-policy.json`.

---

### 4. Environment Variables Configuration

Copy the example environment file and configure your S3 bucket and region:

```bash
cp .env.example .env
nano .env
```

Update the variables accordingly:
```env
# AWS Configuration
AWS_REGION=me-south-1
S3_BUCKET=your-cloudtrail-s3-bucket-name

# Processing Configuration (Fetch interval in seconds)
PROCESSING_INTERVAL=300

# Grafana Admin Credentials
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=your_secure_password
```

---

### 5. Launch the Monitoring Stack

Start all containers in detached mode using Docker Compose:

```bash
docker compose up -d
```

Verify that all 4 containers are up and running:

```bash
docker compose ps
```

---

### 6. Accessing Grafana & Dashboards

1. Open your web browser and navigate to: `http://<YOUR_VPS_IP>:3000`
2. Log in with the credentials configured in `.env` (Default: `admin` / `admin` or your updated password).
3. Navigate to **Dashboards** in Grafana to view the pre-imported **CloudTrail Access Key Monitoring** dashboard.

---

## 🛠️ Diagnostics & Utilities

This repository includes operational bash scripts to manage and troubleshoot the environment.

### Run Diagnostics (`diagnose.sh`)
If no data is appearing in Grafana or you suspect connectivity issues, run the automated diagnostic check:

```bash
chmod +x diagnose.sh
./diagnose.sh
```
This script validates:
* Docker container health.
* AWS credential validity (`sts get-caller-identity`).
* S3 bucket reachability & log file detection.
* Promtail shipping status and Loki indexing status.

### Quick Region Update (`fix-region.sh`)
To quickly switch AWS regions and restart the processing container:

```bash
chmod +x fix-region.sh
./fix-region.sh
```

### Rebuild Processor (`rebuild-processor.sh`)
To apply code changes to the Python processor and recreate the container:

```bash
chmod +x rebuild-processor.sh
./rebuild-processor.sh
```

---

## 🔐 Required AWS IAM Policy

Attach the following policy (found in `iam-policy.json`) to the IAM user whose access keys are configured in `config/aws-credentials`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudTrailS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::YOUR_S3_BUCKET_NAME",
        "arn:aws:s3:::YOUR_S3_BUCKET_NAME/*"
      ]
    },
    {
      "Sid": "CloudTrailDescribeAccess",
      "Effect": "Allow",
      "Action": [
        "cloudtrail:DescribeTrails",
        "cloudtrail:GetTrailStatus",
        "cloudtrail:LookupEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 📜 License & Contribution

Distributed under the MIT License. Contributions and improvements are welcome!
