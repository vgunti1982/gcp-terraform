variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
  default     = "your-project-id"  # Replace with your actual GCP project ID
}

variable "region" {
  description = "GCP region where resources will be created"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone where the VM will be created"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "my-first-vm"
}

variable "machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-micro"  # Free tier eligible
}