# where the site meets the outside world; transit terminates on the routers here
data "netbox_rack_type" "rack" {
  slug = "apc-ar3355b2"
}

data "netbox_device_type" "router" {
  slug = "juniper-mx204"
}

data "netbox_device_type" "oob" {
  slug = "cisco-c9300-48t"
}

data "netbox_rack_role" "edge" {
  name = "Edge"
}

data "netbox_device_role" "router" {
  name = "router"
}

data "netbox_device_role" "oob" {
  name = "oob"
}

data "netbox_device_role" "pdu" {
  name = "PDU"
}

data "netbox_device_type" "pdu" {
  slug = "apc-ap8965"
}

resource "netbox_location" "this" {
  name    = var.location_name
  site_id = var.site_id
}

resource "netbox_power_panel" "a" {
  name    = "${var.name}-edge-panel-a"
  site_id = var.site_id
}

resource "netbox_power_panel" "b" {
  name    = "${var.name}-edge-panel-b"
  site_id = var.site_id
}

resource "netbox_rack" "this" {
  name         = "${var.name}-edge"
  status       = "active"
  role_id      = data.netbox_rack_role.edge.id
  site_id      = var.site_id
  location_id  = netbox_location.this.id
  tenant_id    = var.tenant_id
  rack_type_id = data.netbox_rack_type.rack.id
}

resource "netbox_power_feed" "a" {
  name                    = "${var.name}-edge-a"
  power_panel_id          = netbox_power_panel.a.id
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
  name                    = "${var.name}-edge-b"
  power_panel_id          = netbox_power_panel.b.id
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
  name           = "${var.name}-edge-pdu-${each.key}"
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.pdu.id
  role_id        = data.netbox_device_role.pdu.id
  site_id        = var.site_id
  location_id    = netbox_location.this.id
  tenant_id      = var.tenant_id
  status         = "active"
}

resource "netbox_device" "rtr" {
  for_each       = { rtr1 = 44, rtr2 = 43 }
  name           = each.key
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.router.id
  role_id        = data.netbox_device_role.router.id
  site_id        = var.site_id
  location_id    = netbox_location.this.id
  rack_face      = "front"
  rack_position  = each.value
  tenant_id      = var.tenant_id
  status         = "active"
}

resource "netbox_device" "oob" {
  name           = "oob1"
  rack_id        = netbox_rack.this.id
  device_type_id = data.netbox_device_type.oob.id
  role_id        = data.netbox_device_role.oob.id
  site_id        = var.site_id
  location_id    = netbox_location.this.id
  rack_face      = "front"
  rack_position  = 41
  tenant_id      = var.tenant_id
  status         = "active"
}
