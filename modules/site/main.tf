# an edge rack plus some pods, and the addressing they share
data "netbox_ipam_role" "networking" {
  name = "Networking"
}

data "netbox_ipam_role" "mgmt" {
  name = "Management"
}

data "netbox_ipam_role" "compute" {
  name = "Compute"
}

data "netbox_tenant" "this" {
  name = var.tenant
}

data "netbox_site_group" "this" {
  name = var.site_group
}

resource "netbox_site" "this" {
  name             = upper(var.name)
  facility         = var.facility
  group_id         = data.netbox_site_group.this.id
  tenant_id        = data.netbox_tenant.this.id
  description      = var.description
  timezone         = var.timezone
  physical_address = var.physical_address
  latitude         = var.latitude
  longitude        = var.longitude
}

resource "netbox_vlan_group" "this" {
  name       = upper(var.name)
  slug       = var.name
  scope_type = "dcim.site"
  scope_id   = netbox_site.this.id
  vid_ranges = [[100, 399]]
}

resource "netbox_prefix" "supernet" {
  prefix      = var.supernet
  status      = "container"
  site_id     = netbox_site.this.id
  tenant_id   = data.netbox_tenant.this.id
  description = upper(var.name)
}

# site-wide vlans; compute is per-rack and lives in the pods
resource "netbox_vlan" "site" {
  for_each = {
    networking = { vid = 100, prefix = var.networking_prefix, role = data.netbox_ipam_role.networking.id }
    mgmt       = { vid = 200, prefix = var.mgmt_prefix, role = data.netbox_ipam_role.mgmt.id }
  }
  name      = each.key
  vid       = each.value.vid
  site_id   = netbox_site.this.id
  group_id  = netbox_vlan_group.this.id
  role_id   = each.value.role
  tenant_id = data.netbox_tenant.this.id
  status    = "active"
}

resource "netbox_prefix" "site" {
  for_each = {
    networking = { prefix = var.networking_prefix, role = data.netbox_ipam_role.networking.id }
    mgmt       = { prefix = var.mgmt_prefix, role = data.netbox_ipam_role.mgmt.id }
  }
  prefix    = each.value.prefix
  status    = "active"
  site_id   = netbox_site.this.id
  vlan_id   = netbox_vlan.site[each.key].id
  role_id   = each.value.role
  tenant_id = data.netbox_tenant.this.id
}

resource "netbox_config_context" "ntp" {
  name  = "${var.name}-ntp"
  sites = [netbox_site.this.id]
  data = jsonencode({
    ntp_servers = var.ntp_servers
  })
}

module "edge" {
  source = "../edge-rack"

  name          = var.name
  site_id       = netbox_site.this.id
  tenant_id     = data.netbox_tenant.this.id
  location_name = var.edge_location

  netbox = var.netbox
}

module "pod" {
  for_each = var.pods
  source   = "../pod"

  name      = "${var.name}-${each.key}"
  site_id   = netbox_site.this.id
  tenant_id = data.netbox_tenant.this.id
  dns_zone  = var.dns_zone

  vlan_group_id = netbox_vlan_group.this.id
  ipam_role_id  = data.netbox_ipam_role.compute.id
  racks         = each.value.racks

  netbox = var.netbox
}
