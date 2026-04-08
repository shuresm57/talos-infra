variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "project_name" {
  type = string
}

variable "talos_image_id" {
  type        = string
  description = "Hetzner snapshot ID for the Talos Linux image"
}

variable "location" {
  type    = string
  default = "fsn1"
}

variable "server_type" {
  type    = string
  default = "cx22"
}
