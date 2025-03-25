variable "service_name_mappings" {
  type = list(object({
    ecs_cluster_name = string,
    ecs_service_name = string,
    hosted_zone_id   = string,
    dns_name         = string,
    dns_ttl          = number
  }))
}

variable "lambda_name" {
  type    = string
  default = "ecs-dns-update"
}