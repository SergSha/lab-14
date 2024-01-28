#variable "folder_id" {
#  type = string
#}

variable "vpc_name" {
  description = "VPC name"
  type = string
}

variable "zone" {
  description = "zone"
  type = string
  default = "ru-central1-b"
}

variable "network_interface" {
  description = "Additional network interface to attach to the instance"
  type        = map(map(string))
  default     = {}
}

#variable "subnet_name" {
#  description = "subnet name"
#  type = string
#}

#variable "subnet_id" {
#  description = "subnet id"
#  type = string
#}

#variable "subnet_cidrs" {
#  description = "CIDRs"
#  type = list(string)
#}
/*
variable "subnet_cidrs" {}
*/
## VM parameters
variable "vm_name" {
  description = "VM name"
  type        = string
}

variable "cpu" {
  description = "VM CPU count"
  type        = number
  default     = 2
}

variable "memory" {
  description = "VM RAM size"
  type        = number
  default     = 2
}

variable "core_fraction" {
  description = "Core fraction, default 100%"
  type        = number
  default     = 50
}

variable "disk" {
  description = "VM Disk size"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Disk type"
  type        = string
  default     = "network-ssd"
}
variable "secondary_disk" {
  description = "Additional secondary disk to attach to the instance"
  type        = map(map(string))
  default     = {}
}
variable "allow_stopping_for_update" {
  description = "If true, allows Terraform to stop the instance in order to update its properties. If you try to update a property that requires stopping the instance without setting this field, the update will fail."
  type        = bool
  default     = true
}

# yc compute image list --folder-id standard-images

#variable "image_id" {
#  description = "Default image ID Ubuntu 20"
#  default     = "fd879gb88170to70d38a" # ubuntu-20-04-lts-v20220404
#  type        = string
#}

#variable "image_id" {
#  description = "Default image ID Debian 11"
#  default     = "fd83u9thmahrv9lgedrk" # debian-11-v20230814
#  type        = string
#}

variable "image_id" {
  description = "Default image ID AlmaLinux 9"
  default     = "fd877fuskeokm2plco89" # almalinux-9-v20240108
  type        = string
}

#variable "image_id" {
#  description = "Default image ID AlmaLinux 8"
#  default     = "fd84itfojin92kj38vmb" # almalinux-8-v20230925
#  type        = string
#}

#variable "image_id" {
#  description = "Default image ID CentOS 7"
#  default     = "fd85qh2iveusn11jcup6" # centos-7-v20230911
#  type        = string
#}

variable "nat" {
  type    = bool
  default = true
}

variable "platform_id" {
  type    = string
  default = "standard-v3"
}

variable "internal_ip_address" {
  type    = string
  default = null
}

variable "nat_ip_address" {
  type    = string
  default = null
}

variable "vm_user" {
  type        = string
  description = "vm user"
  default = ""
}

variable "ssh_public_key" {
  type        = string
  description = "cloud-config ssh public key"
  default = ""
}

variable "ssh_private_key" {
  type        = string
  description = "cloud-config ssh private key"
  default = ""
}

variable "user-data" {
  type        = string
  description = "user data"
  default = ""
}