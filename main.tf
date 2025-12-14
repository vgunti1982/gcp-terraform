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
# INTERNET GATEWAY (Cloud Router + NAT)
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
# Default route to internet
resource "google_compute_route" "default_route" {
  name             = "${var.vpc_name}-default-route"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc_network.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# Custom route example (optional)
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
# Allow SSH from anywhere
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

# Allow HTTP
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

# Allow HTTPS
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

# Allow custom ports (configurable via tfvars)
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

# Allow internal communication
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
# COMPUTE INSTANCE
# ========================================
resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      nat_ip = var.assign_public_ip ? google_compute_address.vm_static_ip[0].address : null
    }
  }

  tags = var.instance_tags

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
# STATIC IP ADDRESS (Optional)
# ========================================
resource "google_compute_address" "vm_static_ip" {
  count  = var.assign_public_ip ? 1 : 0
  name   = "${var.instance_name}-static-ip"
  region = var.region

  address_type = "EXTERNAL"
}

# ========================================
# NETWORK INTERFACE DETAILS
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

output "vm_public_ip" {
  value       = var.assign_public_ip ? google_compute_address.vm_static_ip[0].address : null
  description = "Static public IP of the VM"
}

output "vm_internal_ip" {
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
  description = "Internal IP of the VM"
}

output "vm_name" {
  value       = google_compute_instance.vm_instance.name
  description = "Name of the VM instance"
}