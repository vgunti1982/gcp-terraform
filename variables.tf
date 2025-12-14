variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# ========================================
# VPC & NETWORKING
# ========================================
variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "main-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "main-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "create_custom_route" {
  description = "Whether to create a custom route"
  type        = bool
  default     = false
}

variable "custom_route_cidr" {
  description = "CIDR range for custom route"
  type        = string
  default     = "192.168.0.0/16"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change to your IP for security
}

# ========================================
# COMPUTE INSTANCE
# ========================================
variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "my-vm"
}

variable "machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_image" {
  description = "Boot disk image"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "pd-standard"
}

variable "assign_public_ip" {
  description = "Whether to assign a static public IP"
  type        = bool
  default     = true
}

variable "instance_tags" {
  description = "Network tags for the VM"
  type        = list(string)
  default     = ["ssh", "http", "https", "custom-ports"]
}

# ========================================
# INGRESS PORTS
# ========================================
variable "custom_ingress_ports" {
  description = "List of custom TCP ports to allow ingress"
  type        = list(string)
  default     = ["8000", "8089", "9997"]
}

variable "custom_ports_source_ranges" {
  description = "CIDR ranges allowed for custom ports"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}