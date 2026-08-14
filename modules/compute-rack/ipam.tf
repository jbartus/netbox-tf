resource "netbox_vlan" "this" {
  name      = var.name
  vid       = var.vid
  site_id   = var.site.site_id
  group_id  = var.site.vlan_group_id
  role_id   = var.site.ipam_role_id
  tenant_id = var.site.tenant_id
  status    = "active"
}

resource "netbox_prefix" "this" {
  prefix    = var.prefix
  status    = "active"
  site_id   = var.site.site_id
  vlan_id   = netbox_vlan.this.id
  role_id   = var.site.ipam_role_id
  tenant_id = var.site.tenant_id
}

resource "netbox_ip_address" "gateway" {
  ip_address  = "${local.gateway}/${split("/", var.prefix)[1]}"
  status      = "reserved"
  tenant_id   = var.site.tenant_id
  description = "default gateway"
}

# the dhcp server owns these, not netbox
resource "netbox_ip_range" "dhcp" {
  start_address  = "${cidrhost(var.prefix, 2)}/${split("/", var.prefix)[1]}"
  end_address    = "${cidrhost(var.prefix, 9)}/${split("/", var.prefix)[1]}"
  status         = "active"
  role_id        = var.site.ipam_role_id
  tenant_id      = var.site.tenant_id
  mark_populated = true
  mark_utilized  = true
  description    = "dhcp pool"
}

# the two halves of the subnet, which are otherwise invisible in netbox. no
# mark_populated/mark_utilized, unlike dhcp above: the addresses below are real
# objects, so let them drive utilization.
resource "netbox_ip_range" "server" {
  start_address = "${cidrhost(var.prefix, 10)}/${local.mask}"
  end_address   = "${cidrhost(var.prefix, 99)}/${local.mask}"
  status        = "active"
  role_id       = var.site.ipam_role_id
  tenant_id     = var.site.tenant_id
  description   = "servers"
}

resource "netbox_ip_range" "ilo" {
  start_address = "${cidrhost(var.prefix, 100)}/${local.mask}"
  end_address   = "${cidrhost(var.prefix, 199)}/${local.mask}"
  status        = "active"
  role_id       = var.site.ipam_role_id
  tenant_id     = var.site.tenant_id
  description   = "ilos"
}

# ethernet/ocp1/1 arrives with the nic module, so terraform never sees its id
data "netbox_device_interfaces" "server_nics" {
  name_regex = "^(Ethernet/OCP1/1|iLO)$"
  depends_on = [terraform_data.modules]
}

locals {
  # `...` plus the [0]s absorb a row the unscoped data source returned twice
  server_nics = { for i in data.netbox_device_interfaces.server_nics.interfaces : "${i.device_id}/${i.name}" => i.id... }
  mask        = split("/", var.prefix)[1]
}

resource "netbox_ip_address" "server" {
  count               = local.server_count
  ip_address          = "${cidrhost(var.prefix, local.server_offset + count.index)}/${local.mask}"
  device_interface_id = local.server_nics["${netbox_device.server[count.index].id}/Ethernet/OCP1/1"][0]
  status              = "active"
  tenant_id           = var.site.tenant_id
  dns_name            = "${netbox_device.server[count.index].name}.${var.site.dns_zone}"
}

resource "netbox_ip_address" "ilo" {
  count               = local.server_count
  ip_address          = "${cidrhost(var.prefix, local.ilo_offset + count.index)}/${local.mask}"
  device_interface_id = local.server_nics["${netbox_device.server[count.index].id}/iLO"][0]
  status              = "active"
  tenant_id           = var.site.tenant_id
  dns_name            = "${netbox_device.server[count.index].name}-ilo.${var.site.dns_zone}"
}

resource "netbox_device_primary_ip" "server" {
  count         = local.server_count
  device_id     = netbox_device.server[count.index].id
  ip_address_id = netbox_ip_address.server[count.index].id
}
