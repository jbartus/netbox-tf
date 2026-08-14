# a location with its own power, spine pair, and the compute racks that uplink into them
data "netbox_rack_type" "rack" {
  slug = "apc-ar3355b2"
}

data "netbox_device_type" "spine" {
  slug = "cisco-n9k-c9336c-fx2"
}

data "netbox_rack_role" "fabric" {
  name = "Fabric"
}

data "netbox_device_role" "spine" {
  name = "spine"
}

data "netbox_device_role" "pdu" {
  name = "PDU"
}

data "netbox_device_type" "pdu" {
  slug = "apc-ap8965"
}

resource "netbox_location" "this" {
  name    = var.name
  site_id = var.site_id
}

resource "netbox_power_panel" "a" {
  name    = "${var.name}-panel-a"
  site_id = var.site_id
}

resource "netbox_power_panel" "b" {
  name    = "${var.name}-panel-b"
  site_id = var.site_id
}

# the spines live in the pod's own rack
resource "netbox_rack" "net" {
  name         = "${var.name}-net"
  status       = "active"
  role_id      = data.netbox_rack_role.fabric.id
  site_id      = var.site_id
  location_id  = netbox_location.this.id
  tenant_id    = var.tenant_id
  rack_type_id = data.netbox_rack_type.rack.id
}

resource "netbox_power_feed" "net_a" {
  name                    = "${var.name}-net-a"
  power_panel_id          = netbox_power_panel.a.id
  rack_id                 = netbox_rack.net.id
  type                    = "primary"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_power_feed" "net_b" {
  name                    = "${var.name}-net-b"
  power_panel_id          = netbox_power_panel.b.id
  rack_id                 = netbox_rack.net.id
  type                    = "redundant"
  status                  = "active"
  supply                  = "ac"
  voltage                 = 208
  amperage                = 30
  phase                   = "three-phase"
  max_percent_utilization = 80
}

resource "netbox_device" "net_pdu" {
  for_each       = toset(["a", "b"])
  name           = "${var.name}-net-pdu-${each.key}"
  rack_id        = netbox_rack.net.id
  device_type_id = data.netbox_device_type.pdu.id
  role_id        = data.netbox_device_role.pdu.id
  site_id        = var.site_id
  location_id    = netbox_location.this.id
  tenant_id      = var.tenant_id
  status         = "active"
}

resource "netbox_device" "spine" {
  for_each       = { spine1 = 42, spine2 = 40 }
  name           = "${var.name}-${each.key}"
  rack_id        = netbox_rack.net.id
  device_type_id = data.netbox_device_type.spine.id
  role_id        = data.netbox_device_role.spine.id
  site_id        = var.site_id
  location_id    = netbox_location.this.id
  rack_face      = "front"
  rack_position  = each.value
  tenant_id      = var.tenant_id
  status         = "active"
}

module "compute" {
  for_each = var.racks
  source   = "../compute-rack"

  name   = "${var.name}-${each.key}"
  prefix = each.value.prefix
  vid    = each.value.vid

  site = {
    site_id       = var.site_id
    location_id   = netbox_location.this.id
    tenant_id     = var.tenant_id
    dns_zone      = var.dns_zone
    panel_a_id    = netbox_power_panel.a.id
    panel_b_id    = netbox_power_panel.b.id
    vlan_group_id = var.vlan_group_id
    ipam_role_id  = var.ipam_role_id
  }

  netbox = var.netbox
}
