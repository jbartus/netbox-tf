variable "name" { type = string }

variable "facility" { type = string }
variable "description" { type = string }
variable "physical_address" { type = string }
variable "latitude" { type = string }
variable "longitude" { type = string }
variable "timezone" { type = string }

variable "image" {
  type        = string
  default     = null
  description = "Photo of the building, path relative to the repo root"
}

variable "site_group" {
  type    = string
  default = "Data Centers"
}
variable "tenant" {
  type    = string
  default = "Vaulter"
}

variable "dns_zone" { type = string }

variable "supernet" {
  type        = string
  description = "The site's whole allocation, e.g. 10.1.0.0/16"
}

variable "networking_prefix" { type = string }
variable "mgmt_prefix" { type = string }

variable "edge_location" {
  type        = string
  description = "Where the edge rack sits, e.g. MMR2"
}

variable "pods" {
  description = "One entry per pod; each holds its own map of compute racks"
  type = map(object({
    racks = map(object({
      prefix      = string
      vid         = number
      spine_ports = list(number)
    }))
    floorplan = optional(object({
      image = string
      width = number
      depth = number
      grid  = number
      scale = number
      racks = map(object({
        x           = number
        y           = number
        orientation = string
      }))
      zones = list(object({
        type  = string
        label = string
        x     = list(number)
        y     = list(number)
      }))
    }))
  }))
}

variable "netbox" {
  type = object({
    url   = string
    token = string
  })
  sensitive = true
}

variable "ntp_servers" {
  type        = list(string)
  description = "Handed to every device at this site via config context"
}
