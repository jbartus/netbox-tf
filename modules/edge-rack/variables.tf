variable "name" {
  type        = string
  description = "Site short name; the rack becomes <name>-edge"
}

variable "site_id" { type = number }
variable "tenant_id" { type = number }

variable "location_name" {
  type        = string
  description = "Where the edge rack sits, e.g. MMR2 - carrier handoffs land here"
}

variable "netbox" {
  type = object({
    url   = string
    token = string
  })
  sensitive = true
}
