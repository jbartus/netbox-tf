# read top down: leaf at u40, then three groups of servers with 2u gaps. each group
# takes one pdu feed leg. u and outlet travel together so they can't drift apart.
locals {
  slots = [
    # leg a - six, because the leaf has outlet 1
    { u = 37, outlet = "power outlet 2" },
    { u = 36, outlet = "power outlet 3" },
    { u = 35, outlet = "power outlet 4" },
    { u = 34, outlet = "power outlet 5" },
    { u = 33, outlet = "power outlet 6" },
    { u = 32, outlet = "power outlet 7" },
    # leg b
    { u = 29, outlet = "power outlet 9" },
    { u = 28, outlet = "power outlet 10" },
    { u = 27, outlet = "power outlet 11" },
    { u = 26, outlet = "power outlet 12" },
    { u = 25, outlet = "power outlet 13" },
    { u = 24, outlet = "power outlet 14" },
    { u = 23, outlet = "power outlet 15" },
    # leg c
    { u = 20, outlet = "power outlet 17" },
    { u = 19, outlet = "power outlet 18" },
    { u = 18, outlet = "power outlet 19" },
    { u = 17, outlet = "power outlet 20" },
    { u = 16, outlet = "power outlet 21" },
    { u = 15, outlet = "power outlet 22" },
    { u = 14, outlet = "power outlet 23" },
  ]
  leaf_outlet  = "power outlet 1"
  server_count = length(local.slots)

  # .1 gateway, .2-.9 dhcp, .10-.99 servers, .100-.199 their ilos
  net           = cidrhost(var.prefix, 0)
  gateway       = cidrhost(var.prefix, 1)
  server_offset = 10
  ilo_offset    = 100
}

resource "netbox_rack" "this" {
  name         = var.name
  status       = "active"
  role_id      = data.netbox_rack_role.compute.id
  site_id      = var.site.site_id
  location_id  = var.site.location_id
  tenant_id    = var.site.tenant_id
  rack_type_id = data.netbox_rack_type.rack.id
}

resource "netbox_power_feed" "a" {
  name                    = "${var.name}-a"
  power_panel_id          = var.site.panel_a_id
  rack_id                 = netbox_rack.this.id
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "b" {
  name                    = "${var.name}-b"
  power_panel_id          = var.site.panel_b_id
  rack_id                 = netbox_rack.this.id
  type                    = "redundant"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_device" "pdu" {
  for_each       = toset(["a", "b"])
  name           = "${var.name}-pdu-${each.key}"
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.pdu.id
  role_id        = data.netbox_device_role.pdu.id
  site_id        = var.site.site_id
  location_id    = var.site.location_id
  tenant_id      = var.site.tenant_id
  status         = "active"
}

resource "netbox_device" "leaf" {
  name           = "${var.name}-leaf"
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.leaf.id
  role_id        = data.netbox_device_role.leaf.id
  site_id        = var.site.site_id
  location_id    = var.site.location_id
  rack_face      = "front"
  rack_position  = 40
  tenant_id      = var.site.tenant_id
  status         = "active"
}

resource "netbox_device" "server" {
  count          = local.server_count
  name           = format("%s-%02d", var.name, count.index + 1)
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.server.id
  role_id        = data.netbox_device_role.server.id
  site_id        = var.site.site_id
  location_id    = var.site.location_id
  rack_face      = "front"
  rack_position  = local.slots[count.index].u
  tenant_id      = var.site.tenant_id
  status         = "active"
}
