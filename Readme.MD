# GCP Terraform Infrastructure as Code

A production-ready Terraform configuration for managing Google Cloud Platform infrastructure, including VMs, networking, load balancing, monitoring, and storage.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Features](#features)
- [Configuration](#configuration)
- [Usage](#usage)
- [Outputs](#outputs)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Overview

This Terraform project automates the deployment of a scalable, production-ready infrastructure on Google Cloud Platform. It includes:

- **4 Compute Instances** distributed across multiple zones
- **VPC Network** with custom subnet and routing
- **Load Balancer** for distributing traffic
- **Health Checks** for monitoring VM health
- **Cloud Storage** for backups and data
- **Service Accounts** with proper IAM permissions
- **Monitoring & Alerting** for infrastructure health
- **Firewall Rules** with custom port configuration

## Prerequisites

Before you begin, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads) (v1.0+)
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
- GCP Project with billing enabled
- Service Account JSON credentials file

### GCP Setup

1. Create a GCP Project
2. Enable required APIs:
   ```bash
   gcloud services enable \
     iam.googleapis.com \
     cloudresourcemanager.googleapis.com \
     compute.googleapis.com \
     storage-api.googleapis.com \
     monitoring.googleapis.com \
     logging.googleapis.com
   ```
3. Create a Service Account and download JSON key
4. Authenticate with gcloud:
   ```bash
   gcloud auth login
   gcloud config set project YOUR-PROJECT-ID
   ```

## Project Structure

```
my-gcp-terraform/
├── main.tf                 # Main infrastructure code
├── variables.tf            # Variable declarations
├── outputs.tf              # Output values (included in main.tf)
├── terraform.tfvars        # Variable values (not committed to git)
├── credentials.json        # GCP service account key (not committed to git)
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

## Quick Start

### 1. Clone or Create the Project

```bash
mkdir my-gcp-terraform
cd my-gcp-terraform
```

### 2. Create the Files

Copy the following files into your project:
- `main.tf` - Infrastructure code
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Your configuration values
- `.gitignore` - Git ignore rules

### 3. Update Configuration

Edit `terraform.tfvars` with your values:

```hcl
project_id   = "your-gcp-project-id"
region       = "us-central1"
zone         = "us-central1-a"
environment  = "production"
```

### 4. Place Credentials

Copy your GCP service account JSON file to the project:

```bash
cp ~/Downloads/your-sa-key.json ./credentials.json
```

### 5. Initialize Terraform

```bash
terraform init
```

### 6. Plan Infrastructure

```bash
terraform plan
```

### 7. Deploy Infrastructure

```bash
terraform apply
```

## Architecture

### Network Architecture

```
┌─────────────────────────────────────────────────────┐
│                    GCP Project                       │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │           VPC Network (main-vpc)              │  │
│  │      CIDR: 10.0.1.0/24                       │  │
│  │                                              │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  │
│  │  │   VM-1   │  │   VM-2   │  │   VM-3   │  │  │
│  │  │ Zone: A  │  │ Zone: B  │  │ Zone: C  │  │  │
│  │  └─────┬────┘  └─────┬────┘  └─────┬────┘  │  │
│  │        │             │             │       │  │
│  │  ┌─────────────────────────────────┐       │  │
│  │  │   Load Balancer (HTTP)          │       │  │
│  │  │   - Health Checks               │       │  │
│  │  │   - Instance Groups (per zone)  │       │  │
│  │  │   - Backend Service             │       │  │
│  │  └─────────────────────────────────┘       │  │
│  │                                              │  │
│  │  ┌─────────────────────────────────┐       │  │
│  │  │   Cloud Router + NAT Gateway    │       │  │
│  │  └─────────────────────────────────┘       │  │
│  │                                              │  │
│  └──────────────────────────────────────────────┘  │
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │  Cloud Storage Bucket (Versioned)            │  │
│  └──────────────────────────────────────────────┘  │
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │  Monitoring & Alerting (CPU Usage)           │  │
│  └──────────────────────────────────────────────┘  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Features

### 1. **Multi-Zone VM Deployment**
- 4 Compute instances across 3 zones (us-central1-a, b, c)
- Configurable machine types and disk sizes
- Automatic OS Login enabled
- Service account with proper permissions

### 2. **Networking**
- Custom VPC with configurable CIDR range
- Subnet with private IP Google Access
- Cloud Router for outbound NAT
- Custom routes support
- Regional routing mode

### 3. **Firewall Rules**
- SSH access (port 22)
- HTTP (port 80)
- HTTPS (port 443)
- Custom ports (8000, 8089, 9997) - configurable
- Internal subnet communication
- Configurable source ranges

### 4. **Load Balancing**
- HTTP Load Balancer (Layer 7)
- Multiple instance groups (one per zone)
- Health checks every 30 seconds
- Session affinity (CLIENT_IP)
- Path-based routing support
- Detailed logging

### 5. **Health Checks**
- HTTP health checks on port 80
- Configurable endpoint path
- Automatic VM health monitoring
- Healthy/Unhealthy thresholds

### 6. **Storage**
- Cloud Storage bucket with versioning
- Automatic cleanup of old versions
- Uniform bucket-level access
- Labels for resource tracking

### 7. **Service Accounts & IAM**
- Dedicated service account for VMs
- Logging Writer role
- Monitoring Metric Writer role
- Storage Object Viewer role
- Principle of least privilege

### 8. **Monitoring & Alerting**
- CPU usage monitoring
- Alert policies for high CPU
- Configurable thresholds
- Email/Slack notifications (optional)
- Auto-close alerts after 30 minutes

### 9. **Instance Templates**
- Blueprint for consistent VM deployment
- Used for auto-scaling (future enhancement)
- Automatic OS Login enabled

## Configuration

### Main Variables

#### Project & Region
```hcl
project_id  = "your-gcp-project-id"    # Your GCP project
region      = "us-central1"             # Primary region
zone        = "us-central1-a"           # Primary zone
environment = "production"               # Environment name
```

#### VPC & Networking
```hcl
vpc_name      = "main-vpc"
subnet_name   = "main-subnet"
subnet_cidr   = "10.0.1.0/24"           # CIDR range
ssh_source_ranges = ["0.0.0.0/0"]       # SSH access (restrict for security)
```

#### VM Configuration
```hcl
vm_instances = {
  "vm1" = {
    name             = "app-server-1"
    machine_type     = "e2-micro"       # Free tier eligible
    zone             = "us-central1-a"
    boot_disk_image  = "debian-cloud/debian-11"
    boot_disk_size   = 20               # GB
    boot_disk_type   = "pd-standard"
    assign_public_ip = true
    instance_tags    = ["ssh", "http", "https", "custom-ports"]
  }
  # Add more VMs here
}
```

#### Ingress Ports
```hcl
custom_ingress_ports       = ["8000", "8089", "9997"]
custom_ports_source_ranges = ["0.0.0.0/0"]    # Restrict for security
```

#### Load Balancer & Health Check
```hcl
health_check_port  = 80
health_check_path  = "/"
create_reserved_ip = true
```

#### Monitoring
```hcl
create_monitoring = true
cpu_threshold     = 80                  # Alert if CPU > 80%
notification_channels = []              # Add email/Slack channels
```

### Full Configuration Reference

See `variables.tf` for all available configuration options with descriptions.

## Usage

### Viewing Current State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show google_compute_instance.vm_instances

# View outputs
terraform output
terraform output load_balancer_ip
terraform output all_vm_details
```

### Making Changes

#### Add a New VM

Edit `terraform.tfvars` and add:

```hcl
vm_instances = {
  # ... existing VMs ...
  "vm5" = {
    name             = "app-server-5"
    machine_type     = "e2-small"
    zone             = "us-central1-b"
    boot_disk_image  = "debian-cloud/debian-11"
    boot_disk_size   = 20
    boot_disk_type   = "pd-standard"
    assign_public_ip = true
    instance_tags    = ["ssh", "http", "https", "custom-ports"]
  }
}
```

Then apply:

```bash
terraform plan
terraform apply
```

#### Modify Ingress Ports

Edit `terraform.tfvars`:

```hcl
custom_ingress_ports = ["8000", "8089", "9997", "3000", "5000"]
```

Then apply:

```bash
terraform plan
terraform apply
```

#### Change Machine Type

Edit `terraform.tfvars`:

```hcl
vm_instances = {
  "vm1" = {
    machine_type = "e2-small"  # Changed from e2-micro
    # ... other config ...
  }
}
```

Then apply (will restart the VM):

```bash
terraform plan
terraform apply
```

### Destroying Infrastructure

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=google_storage_bucket.app_bucket
```

## Outputs

After successful deployment, Terraform outputs important information:

```bash
# Get load balancer IP
terraform output load_balancer_ip

# Get all VM details
terraform output all_vm_details

# Get all outputs
terraform output
```

### Key Outputs

| Output | Description |
|--------|-------------|
| `load_balancer_ip` | Load Balancer public IP address |
| `load_balancer_url` | Complete URL for accessing load balancer |
| `all_vm_details` | Public and internal IPs of all VMs |
| `vpc_network_name` | VPC network name |
| `subnet_cidr` | Subnet CIDR range |
| `service_account_email` | Service account email |
| `storage_bucket_name` | Cloud Storage bucket name |

## Troubleshooting

### Health Check Failing

**Problem:** Load balancer shows unhealthy instances

**Solution:**
1. SSH into VM and check if app responds on port 80:
   ```bash
   gcloud compute ssh app-server-1 --zone=us-central1-a
   curl http://localhost/
   ```
2. Verify firewall rule allows port 80
3. Check application logs on the VM

### Load Balancer Not Working

**Problem:** Can't reach load balancer IP

**Solution:**
1. Verify health checks are passing:
   ```bash
   terraform output health_check_name
   ```
2. Check firewall rules allow port 80 (tcp)
3. Verify instance groups have instances:
   ```bash
   gcloud compute instance-groups list
   ```

### Terraform Errors

**API Not Enabled:**
```bash
gcloud services enable SERVICE_NAME
```

**Permission Denied:**
Ensure service account has necessary IAM roles:
```bash
gcloud projects get-iam-policy PROJECT_ID
```

**State Lock:**
If Terraform is stuck, check for stale locks:
```bash
terraform force-unlock LOCK_ID
```

## Testing the Infrastructure

### Test Load Balancer

```bash
# Get load balancer IP
LB_IP=$(terraform output -raw load_balancer_ip)

# Test HTTP access
curl http://$LB_IP

# Load test with multiple requests
for i in {1..10}; do curl http://$LB_IP; done
```

### SSH into VMs

```bash
gcloud compute ssh app-server-1 --zone=us-central1-a
gcloud compute ssh app-server-2 --zone=us-central1-b
gcloud compute ssh app-server-3 --zone=us-central1-c
gcloud compute ssh app-server-4 --zone=us-central1-a
```

### Check Storage Bucket

```bash
gsutil ls
gsutil ls gs://your-bucket-name/
```

## Git Workflow

### Files NOT Committed (in .gitignore)

- `credentials.json` - Service account key
- `terraform.tfstate*` - State files
- `*.tfvars` - Variable values with sensitive data
- `.terraform/` - Provider plugins

### Files TO Commit

- `main.tf` - Infrastructure code
- `variables.tf` - Variable definitions
- `terraform.tfvars.example` - Template for tfvars
- `.gitignore` - Git ignore rules
- `README.md` - Documentation

### Setup Git

```bash
git init
git add main.tf variables.tf .gitignore README.md
git commit -m "Initial Terraform GCP infrastructure"
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

## Cost Estimation

### Free Tier

- **Compute Engine:** 1 e2-micro VM + 30 GB storage (free for 12 months)
- **Cloud Storage:** 5 GB storage (always free)
- **Monitoring:** Basic monitoring (always free)

### Current Setup (4 e2-micro VMs)

If you exceed free tier:
- **4 e2-micro VMs:** ~$30-40/month
- **Load Balancer:** ~$15/month (ingress free)
- **Cloud Storage:** ~$0.02/month
- **Monitoring:** ~$5/month

**Total:** ~$50-60/month

To reduce costs:
```hcl
# Use only 1 VM for testing
vm_instances = {
  "vm1" = { ... }  # Keep only this one
}

# Use smaller disk
boot_disk_size = 10  # Reduce to 10 GB
```

## Security Best Practices

1. **Restrict SSH Access**
   ```hcl
   ssh_source_ranges = ["YOUR_IP/32"]  # Restrict to your IP
   ```

2. **Use Service Accounts**
   - Already implemented with minimal required roles

3. **Enable VPC Flow Logs**
   ```hcl
   enable_flow_logs = true
   ```

4. **Keep Credentials Secure**
   - Never commit `credentials.json`
   - Use service account instead of user credentials

5. **Regular Backups**
   - Cloud Storage bucket auto-versions files
   - Backup snapshots of persistent disks

6. **Enable Audit Logging**
   - Already configured in this setup

## Next Steps

### Ready to Enhance?

1. **Auto-Scaling Groups** - Scale VMs based on CPU/load
2. **HTTPS/SSL Certificates** - Add managed SSL certificates
3. **Cloud SQL Database** - Add MySQL/PostgreSQL
4. **Cloud CDN** - Cache content globally
5. **VPN/Cloud Interconnect** - Secure site-to-site connectivity
6. **Remote State Backend** - Store state in Cloud Storage
7. **Terraform Modules** - Organize code for reusability
8. **CI/CD Integration** - Automate deployments

### Resources

- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Cloud Terraform Best Practices](https://cloud.google.com/docs/terraform/best-practices)
- [Terraform Tutorial](https://learn.hashicorp.com/terraform)

## Support & Troubleshooting

### Common Issues

- **Module not found:** Run `terraform init`
- **State corrupted:** Use `terraform refresh`
- **Resource conflicts:** Check GCP console for manually created resources

### Getting Help

1. Check Terraform logs: `TF_LOG=DEBUG terraform plan`
2. Review GCP error messages in terminal
3. Check GCP Cloud Console for resource status
4. Review `.terraform/logs` for detailed logs

## License

This Terraform configuration is provided as-is for educational and production use.

---

**Last Updated:** December 13, 2025

**Contributors:** Learning Terraform with Claude

**Status:** Production Ready ✅