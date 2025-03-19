variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "dns_name" {
  type = string
}

variable "dns_ttl" {
  type    = number
  default = 300
}