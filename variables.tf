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
  default     = ["0.0.0.0/0"]
}

# ========================================
# COMPUTE INSTANCE
# ========================================
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

# ========================================
# MULTIPLE VM INSTANCES
# ========================================
variable "vm_instances" {
  description = "Configuration for multiple VM instances"
  type = map(object({
    name             = string
    machine_type     = string
    zone             = string
    boot_disk_image  = string
    boot_disk_size   = number
    boot_disk_type   = string
    assign_public_ip = bool
    instance_tags    = list(string)
  }))

  default = {
    "vm1" = {
      name             = "app-server-1"
      machine_type     = "e2-micro"
      zone             = "us-central1-a"
      boot_disk_image  = "debian-cloud/debian-11"
      boot_disk_size   = 20
      boot_disk_type   = "pd-standard"
      assign_public_ip = true
      instance_tags    = ["ssh", "http", "https", "custom-ports"]
    }
    "vm2" = {
      name             = "app-server-2"
      machine_type     = "e2-micro"
      zone             = "us-central1-b"
      boot_disk_image  = "debian-cloud/debian-11"
      boot_disk_size   = 20
      boot_disk_type   = "pd-standard"
      assign_public_ip = true
      instance_tags    = ["ssh", "http", "https", "custom-ports"]
    }
    "vm3" = {
      name             = "app-server-3"
      machine_type     = "e2-micro"
      zone             = "us-central1-c"
      boot_disk_image  = "debian-cloud/debian-11"
      boot_disk_size   = 20
      boot_disk_type   = "pd-standard"
      assign_public_ip = true
      instance_tags    = ["ssh", "http", "https", "custom-ports"]
    }
    "vm4" = {
      name             = "app-server-4"
      machine_type     = "e2-micro"
      zone             = "us-central1-a"
      boot_disk_image  = "debian-cloud/debian-11"
      boot_disk_size   = 20
      boot_disk_type   = "pd-standard"
      assign_public_ip = true
      instance_tags    = ["ssh", "http", "https", "custom-ports"]
    }
  }
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

# ========================================
# STORAGE CONFIGURATION
# ========================================
variable "create_storage_bucket" {
  description = "Whether to create Cloud Storage bucket"
  type        = bool
  default     = true
}

variable "force_destroy_bucket" {
  description = "Allow Terraform to delete non-empty bucket"
  type        = bool
  default     = false
}

# ========================================
# HEALTH CHECK CONFIGURATION
# ========================================
variable "health_check_port" {
  description = "Port for health checks"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/"
}

# ========================================
# INSTANCE TEMPLATE
# ========================================
variable "enable_instance_template" {
  description = "Enable instance template for auto-scaling"
  type        = bool
  default     = true
}

# ========================================
# LOAD BALANCER CONFIGURATION
# ========================================
variable "create_reserved_ip" {
  description = "Create reserved IP for load balancer"
  type        = bool
  default     = true
}

# ========================================
# MONITORING & ALERTING
# ========================================
variable "create_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "cpu_threshold" {
  description = "CPU usage threshold for alerts (percentage)"
  type        = number
  default     = 80
}

variable "notification_channels" {
  description = "Notification channels for alerts (email, Slack, etc.)"
  type        = list(string)
  default     = []
}