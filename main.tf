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
# COMPUTE INSTANCES (Multiple VMs)
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
# STATIC IP ADDRESSES (Optional)
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

output "vm_details" {
  value = {
    for key, vm in google_compute_instance.vm_instances : vm.name => {
      public_ip  = vm.network_interface[0].access_config[0].nat_ip
      internal_ip = vm.network_interface[0].network_ip
      zone       = vm.zone
    }
  }
  description = "Details of all VM instances"
}

output "vm_names" {
  value       = [for vm in google_compute_instance.vm_instances : vm.name]
  description = "Names of all VM instances"
}

output "vm_public_ips" {
  value       = [for vm in google_compute_instance.vm_instances : vm.network_interface[0].access_config[0].nat_ip]
  description = "Public IPs of all VM instances"
}

output "vm_internal_ips" {
  value       = [for vm in google_compute_instance.vm_instances : vm.network_interface[0].network_ip]
  description = "Internal IPs of all VM instances"
}