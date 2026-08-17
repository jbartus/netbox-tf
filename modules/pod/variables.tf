variable "name" {
  type        = string
  description = "Pod name; becomes the location every rack in it sits in, e.g. ewr-pod1"
}

variable "site_id" { type = number }
variable "tenant_id" { type = number }

variable "dns_zone" {
  type        = string
  description = "Appended to device names for dns_name, e.g. ewr.vaulter.net"
}

variable "vlan_group_id" { type = number }
variable "ipam_role_id" { type = number }

variable "racks" {
  description = "One entry per compute rack, keyed by a short suffix - the pod prefixes its own name. spine_ports are the two spine interfaces this rack's leaf uplinks into, on both spines."
  type = map(object({
    prefix      = string
    vid         = number
    spine_ports = list(number)
  }))
}

variable "netbox" {
  description = "Where the provisioner scripts talk to"
  type = object({
    url   = string
    token = string
  })
  sensitive = true
}

# Cage geometry for the visual explorer. Racks are keyed by name rather than derived,
# because a floorplan can hold racks this pod does not own - the edge rack, say.
variable "floorplan" {
  type = object({
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
  })
  default     = null
  description = "Omit for a pod with no floorplan"
}
