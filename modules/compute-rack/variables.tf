variable "name" {
  type        = string
  description = "Rack name, and the prefix for every device in it, e.g. ewr-r3"
}

variable "prefix" {
  type        = string
  description = "This rack's subnet, e.g. 10.1.16.0/24"
}

variable "vid" { type = number }

variable "site" {
  description = "Everything a rack inherits from the site it sits in"
  type = object({
    site_id       = number
    location_id   = number
    tenant_id     = number
    dns_zone      = string
    panel_a_id    = number
    panel_b_id    = number
    vlan_group_id = number
    ipam_role_id  = number
  })
}

variable "netbox" {
  description = "Where the provisioner scripts talk to"
  type = object({
    url   = string
    token = string
  })
  sensitive = true
}
