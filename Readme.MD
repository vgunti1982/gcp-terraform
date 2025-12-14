Advanced GCP Terraform - Production Ready Setup
What's Included
1. Service Accounts & IAM
Dedicated service account for VMs
Proper IAM roles for logging, monitoring, and storage
Principle of least privilege
bash
# Check service account permissions
gcloud iam service-accounts list
gcloud iam service-accounts describe terraform-vm-sa@PROJECT_ID.iam.gserviceaccount.com
2. Cloud Storage
Versioning enabled (keeps 3 versions)
Automatic cleanup of old versions
Uniform bucket-level access
bash
# Upload files
gsutil cp file.txt gs://your-bucket/
gsutil ls gs://your-bucket/
3. Health Checks
HTTP health checks on port 80
Checks every 30 seconds
Marks VM unhealthy after 3 failed checks
Your app should respond with 200 OK on / endpoint.

4. Load Balancer
Distributes traffic across all VMs
Session affinity (same client → same VM)
Supports path-based routing
bash
# Get load balancer IP
terraform output load_balancer_ip

# Test it
curl http://LOAD_BALANCER_IP
5. Instance Groups
Automatically registers all VMs
Enables load balancing and auto-scaling
6. Monitoring & Alerts
Monitors CPU usage across all VMs
Sends alerts when CPU > 80%
Auto-closes alerts after 30 minutes
7. Instance Templates
Blueprint for creating new instances
Used for auto-scaling groups (future)
Ensures consistency across VMs
Deployment Steps
Step 1: Add Advanced Resources
bash
# Copy the advanced main.tf to your project
# Merge the advanced variables into variables.tf
# Merge the advanced tfvars into terraform.tfvars
Step 2: Enable Required APIs
bash
gcloud services enable compute.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable storage-api.googleapis.com
Step 3: Plan and Apply
bash
terraform plan
# Review the plan carefully
terraform apply
Step 4: Verify
bash
# Check load balancer
terraform output load_balancer_ip
curl http://LOAD_BALANCER_IP

# Check storage
gsutil ls

# Check service account
gcloud iam service-accounts list
Advanced Configurations
Enable Email Alerts
hcl
variable "notification_channels" {
  default = ["YOUR_NOTIFICATION_CHANNEL_ID"]
}
Get your notification channel ID:

bash
gcloud alpha monitoring channels list
Add Auto-Scaling
hcl
resource "google_compute_instance_group_manager" "app_igm" {
  name               = "app-igm"
  instance_template  = google_compute_instance_template.app_template[0].id
  base_instance_name = "app"
  zone               = var.zone
  target_size        = 4
}

resource "google_compute_autoscaler" "app_autoscaler" {
  name   = "app-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.app_igm.id

  autoscaling_policy {
    max_replicas    = 10
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }
}
Enable HTTPS (SSL)
hcl
resource "google_compute_managed_ssl_certificate" "app_cert" {
  name = "app-ssl-cert"
  managed {
    domains = ["example.com"]
  }
}

resource "google_compute_target_https_proxy" "app_proxy_https" {
  name             = "app-https-proxy"
  url_map          = google_compute_url_map.app_lb.id
  ssl_certificates = [google_compute_managed_ssl_certificate.app_cert.id]
}
Add Database
hcl
resource "google_sql_database_instance" "app_db" {
  name             = "app-database"
  database_version = "MYSQL_8_0"

  settings {
    tier = "db-f1-micro"
  }
}
Best Practices
Always run terraform plan before apply
bash
   terraform plan -out=tfplan
   terraform apply tfplan
Use remote state (not local)
hcl
   terraform {
     backend "gcs" {
       bucket = "my-terraform-state"
       prefix = "gcp"
     }
   }
Organize with workspaces
bash
   terraform workspace new production
   terraform workspace new staging
   terraform workspace select production
Use variables for secrets
hcl
   variable "db_password" {
     type      = string
     sensitive = true
   }
Tag everything
hcl
   labels = {
     environment = var.environment
     team        = "platform"
     cost-center = "engineering"
   }
Useful Commands
bash
# Plan with specific variable
terraform plan -var="cpu_threshold=75"

# Destroy specific resource
terraform destroy -target=google_storage_bucket.app_bucket

# Show current state
terraform state show google_compute_instance.vm_instances

# Refresh state from GCP
terraform refresh

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate
Next Steps
Remote State Backend - Move state to Cloud Storage
Auto-Scaling - Add instance group manager
HTTPS/SSL - Add managed SSL certificates
Database - Add Cloud SQL or Firestore
VPN - Secure connections between services
CDN - Cloud CDN for static content
Backup - Automated backup policies
Troubleshooting
Health Check Failing?
Make sure your app responds with 200 OK on /
SSH into VM and check: curl http://localhost/
Load Balancer Not Working?
Check firewall rules allow port 80
Verify instance group has healthy instances
Monitoring Not Working?
Enable required APIs: gcloud services enable monitoring.googleapis.com
Grant IAM roles to service account
You're now ready for production! 🚀

