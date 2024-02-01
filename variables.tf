variable "yc_token" {
  type = string
  sensitive = true
}

variable "cloud_id" {
  type = string
}

#variable "folder_id" {
#  type = string
#}

variable "zone" {
  type    = string
  default = "ru-central1-b"
}

variable "domain_name" {
  type = string
}

#variable "domain_token" {
#  type = string
#}