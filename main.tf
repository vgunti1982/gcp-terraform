# Configure the Google Cloud Provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("./credentials.json")
}

# ========================================
# DATA SOURCE
# ========================================
data "google_client_config" "current" {}

# ========================================
# VPC NETWORK
# ========================================
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  description = "Main VPC network for ${var.project_id}"
}

# ========================================
# SUBNET
# ========================================
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id

  private_ip_google_access = true
  description              = "Subnet in ${var.region}"
}

# ========================================
# CLOUD ROUTER & NAT
# ========================================
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc_network.id

  description = "Cloud Router for NAT gateway"
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ========================================
# ROUTES
# ========================================
resource "google_compute_route" "default_route" {
  name             = "${var.vpc_name}-default-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc_network.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_route" "custom_route" {
  count            = var.create_custom_route ? 1 : 0
  name             = "${var.vpc_name}-custom-route"
  dest_range       = var.custom_route_cidr
  network          = google_compute_network.vpc_network.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1001
}

# ========================================
# FIREWALL RULES
# ========================================
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["ssh"]
  priority      = 1000
  description   = "Allow SSH access"
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.vpc_name}-allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http"]
  priority      = 1001
  description   = "Allow HTTP access"
}

resource "google_compute_firewall" "allow_https" {
  name    = "${var.vpc_name}-allow-https"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https"]
  priority      = 1002
  description   = "Allow HTTPS access"
}

resource "google_compute_firewall" "allow_custom_ports" {
  name    = "${var.vpc_name}-allow-custom-ports"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = var.custom_ingress_ports
  }

  source_ranges = var.custom_ports_source_ranges
  target_tags   = ["custom-ports"]
  priority      = 1003
  description   = "Allow custom application ports"
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr]
  priority      = 1004
  description   = "Allow internal subnet communication"
}

# ========================================
# SERVICE ACCOUNT
# ========================================
resource "google_service_account" "vm_service_account" {
  account_id   = "terraform-vm-sa"
  display_name = "Service Account for VMs"
  description  = "Service account for VM instances to access GCP resources"
}

# Grant necessary permissions
resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "vm_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# ========================================
# CLOUD STORAGE BUCKET
# ========================================
resource "google_storage_bucket" "app_bucket" {
  count         = var.create_storage_bucket ? 1 : 0
  name          = "${var.project_id}-app-bucket-${data.google_client_config.current.project}"
  location      = var.region
  force_destroy = var.force_destroy_bucket

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ========================================
# HEALTH CHECK
# ========================================
resource "google_compute_health_check" "app_health_check" {
  name        = "${var.vpc_name}-health-check"
  description = "Health check for app servers"

  http_health_check {
    port         = var.health_check_port
    request_path = var.health_check_path
  }

  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# ========================================
# INSTANCE TEMPLATE
# ========================================
resource "google_compute_instance_template" "app_template" {
  count       = var.enable_instance_template ? 1 : 0
  name_prefix = "app-template-"

  machine_type = var.machine_type

  disk {
    source_image = var.boot_disk_image
    disk_size_gb = var.boot_disk_size
    disk_type    = var.boot_disk_type
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      # Ephemeral IP
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["ssh", "http", "https", "custom-ports"]

  metadata = {
    enable-oslogin = "true"
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========================================
# COMPUTE INSTANCES
# ========================================
resource "google_compute_instance" "vm_instances" {
  for_each = var.vm_instances

  name         = each.value.name
  machine_type = each.value.machine_type
  zone         = each.value.zone

  boot_disk {
    initialize_params {
      image = each.value.boot_disk_image
      size  = each.value.boot_disk_size
      type  = each.value.boot_disk_type
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      nat_ip = each.value.assign_public_ip ? google_compute_address.vm_static_ip[each.key].address : null
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = each.value.instance_tags

  metadata = {
    enable-oslogin = "true"
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [google_compute_subnetwork.subnet]
}

# ========================================
# STATIC IP ADDRESSES
# ========================================
resource "google_compute_address" "vm_static_ip" {
  for_each = {
    for key, vm in var.vm_instances : key => vm if vm.assign_public_ip
  }

  name   = "${each.value.name}-static-ip"
  region = var.region

  address_type = "EXTERNAL"
}

# ========================================
# INSTANCE GROUPS (One per zone)
# ========================================
resource "google_compute_instance_group" "app_instance_group_a" {
  name        = "${var.vpc_name}-instance-group-a"
  description = "Instance group for load balancing - Zone A"
  zone        = "us-central1-a"

  instances = [for vm in google_compute_instance.vm_instances : vm.self_link if vm.zone == "us-central1-a"]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "app"
    port = 8000
  }
}

resource "google_compute_instance_group" "app_instance_group_b" {
  name        = "${var.vpc_name}-instance-group-b"
  description = "Instance group for load balancing - Zone B"
  zone        = "us-central1-b"

  instances = [for vm in google_compute_instance.vm_instances : vm.self_link if vm.zone == "us-central1-b"]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "app"
    port = 8000
  }
}

resource "google_compute_instance_group" "app_instance_group_c" {
  name        = "${var.vpc_name}-instance-group-c"
  description = "Instance group for load balancing - Zone C"
  zone        = "us-central1-c"

  instances = [for vm in google_compute_instance.vm_instances : vm.self_link if vm.zone == "us-central1-c"]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "app"
    port = 8000
  }
}

# ========================================
# BACKEND SERVICE
# ========================================
resource "google_compute_backend_service" "app_backend" {
  name                  = "${var.vpc_name}-backend-service"
  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"
  port_name             = "http"
  health_checks         = [google_compute_health_check.app_health_check.id]

  backend {
    group = google_compute_instance_group.app_instance_group_a.self_link
  }

  backend {
    group = google_compute_instance_group.app_instance_group_b.self_link
  }

  backend {
    group = google_compute_instance_group.app_instance_group_c.self_link
  }

  session_affinity = "CLIENT_IP"

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ========================================
# LOAD BALANCER - URL MAP
# ========================================
resource "google_compute_url_map" "app_lb" {
  name            = "${var.vpc_name}-load-balancer"
  default_service = google_compute_backend_service.app_backend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "default"
  }

  path_matcher {
    name            = "default"
    default_service = google_compute_backend_service.app_backend.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.app_backend.id
    }
  }
}

# ========================================
# LOAD BALANCER - HTTP PROXY
# ========================================
resource "google_compute_target_http_proxy" "app_proxy" {
  name            = "${var.vpc_name}-http-proxy"
  url_map         = google_compute_url_map.app_lb.id
}

# ========================================
# LOAD BALANCER - FORWARDING RULE
# ========================================
resource "google_compute_global_forwarding_rule" "app_forwarding" {
  name                  = "${var.vpc_name}-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.app_proxy.id
}

# ========================================
# MONITORING - ALERT POLICY
# ========================================
resource "google_monitoring_alert_policy" "cpu_alert" {
  count           = var.create_monitoring ? 1 : 0
  display_name    = "High CPU Usage Alert"
  combiner        = "OR"
  documentation {
    content   = "Alert triggered when CPU usage exceeds ${var.cpu_threshold}%"
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "CPU above ${var.cpu_threshold}%"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_threshold / 100

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# ========================================
# OUTPUTS
# ========================================
output "vpc_network_name" {
  value       = google_compute_network.vpc_network.name
  description = "Name of the VPC network"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Name of the subnet"
}

output "subnet_cidr" {
  value       = google_compute_subnetwork.subnet.ip_cidr_range
  description = "CIDR range of the subnet"
}

output "router_name" {
  value       = google_compute_router.router.name
  description = "Name of the Cloud Router"
}

output "nat_gateway_name" {
  value       = google_compute_router_nat.nat.name
  description = "Name of the NAT gateway"
}

output "service_account_email" {
  value       = google_service_account.vm_service_account.email
  description = "Service account email for VMs"
}

output "storage_bucket_name" {
  value       = var.create_storage_bucket ? google_storage_bucket.app_bucket[0].name : null
  description = "Cloud Storage bucket name"
}

output "health_check_name" {
  value       = google_compute_health_check.app_health_check.name
  description = "Health check name"
}

output "load_balancer_ip" {
  value       = google_compute_global_forwarding_rule.app_forwarding.ip_address
  description = "Load Balancer public IP address"
}

output "load_balancer_url" {
  value       = "http://${google_compute_global_forwarding_rule.app_forwarding.ip_address}"
  description = "Load Balancer URL"
}

output "backend_service_name" {
  value       = google_compute_backend_service.app_backend.name
  description = "Backend service name"
}

output "instance_group_name" {
  value       = "Groups: ${google_compute_instance_group.app_instance_group_a.name}, ${google_compute_instance_group.app_instance_group_b.name}, ${google_compute_instance_group.app_instance_group_c.name}"
  description = "Instance group names"
}

output "all_vm_details" {
  value = {
    for key, vm in google_compute_instance.vm_instances : vm.name => {
      public_ip   = vm.network_interface[0].access_config[0].nat_ip
      internal_ip = vm.network_interface[0].network_ip
      zone        = vm.zone
    }
  }
  description = "Details of all VM instances"
}