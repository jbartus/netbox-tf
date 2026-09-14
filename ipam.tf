resource "netbox_prefix" "ewr_internet" {
  prefix      = "64.125.196.24/30"
  status      = "active"
  site_id     = module.ewr.site_id
  tenant_id   = netbox_tenant.vaulter.id
  description = "Zayo uplink transit"
}

resource "netbox_ip_address" "ewr_internet_gw" {
  ip_address  = "64.125.196.25/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "Zayo upstream gateway / default route"
}

resource "netbox_ip_address" "ewr_cpe_outside" {
  ip_address          = "64.125.196.26/30"
  device_interface_id = local.handoff_ports[module.ewr.router_ids["rtr1"]][0]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  description         = "165 Halsey CPE outside interface"
}

resource "netbox_prefix" "jfk_internet" {
  prefix      = "12.185.44.72/30"
  status      = "active"
  site_id     = module.jfk.site_id
  tenant_id   = netbox_tenant.vaulter.id
  description = "AT&T uplink transit"
}

resource "netbox_ip_address" "jfk_internet_gw" {
  ip_address  = "12.185.44.73/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "AT&T upstream gateway / default route"
}

resource "netbox_ip_address" "jfk_cpe_outside" {
  ip_address          = "12.185.44.74/30"
  device_interface_id = local.handoff_ports[module.jfk.router_ids["rtr1"]][0]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  description         = "375 Pearl CPE outside interface"
}

resource "netbox_prefix" "hq_internet" {
  prefix      = "96.114.212.184/30"
  status      = "active"
  site_id     = netbox_site.hq.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "Comcast uplink transit"
}

resource "netbox_ip_address" "hq_internet_gw" {
  ip_address  = "96.114.212.185/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  description = "Comcast upstream gateway / default route"
}

resource "netbox_ip_address" "hq_cpe_outside" {
  ip_address  = "96.114.212.186/30"
  status      = "reserved"
  tenant_id   = netbox_tenant.vaulter.id
  description = "HQ CPE outside interface"
}

# the outside address is the only one a border router has, so it is the primary
resource "netbox_device_primary_ip" "ewr_rtr1" {
  device_id     = module.ewr.router_ids["rtr1"]
  ip_address_id = netbox_ip_address.ewr_cpe_outside.id
}

resource "netbox_device_primary_ip" "jfk_rtr1" {
  device_id     = module.jfk.router_ids["rtr1"]
  ip_address_id = netbox_ip_address.jfk_cpe_outside.id
}

# the sites hold 10.1/16 and 10.2/16, so 10.0/16 belongs to neither. Unscoped like the
# aggregate, since a link between two sites cannot honestly be scoped to one of them
resource "netbox_prefix" "backbone" {
  prefix      = "10.0.0.0/24"
  status      = "container"
  tenant_id   = netbox_tenant.vaulter.id
  role_id     = netbox_ipam_role.networking.id
  description = "inter-site point-to-point links"
}

resource "netbox_prefix" "ewr_jfk_epl" {
  prefix      = "10.0.0.0/30"
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
  role_id     = netbox_ipam_role.networking.id
  description = "ewr<->jfk EPL"
}

# both ends are ours, unlike the carrier-assigned transit /30s above
resource "netbox_ip_address" "ewr_epl" {
  ip_address          = "10.0.0.1/30"
  device_interface_id = local.handoff_ports[module.ewr.router_ids["rtr2"]][0]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  description         = "ewr<->jfk EPL, ewr end"
}

resource "netbox_ip_address" "jfk_epl" {
  ip_address          = "10.0.0.2/30"
  device_interface_id = local.handoff_ports[module.jfk.router_ids["rtr2"]][0]
  status              = "active"
  tenant_id           = netbox_tenant.vaulter.id
  description         = "ewr<->jfk EPL, jfk end"
}

resource "netbox_device_primary_ip" "ewr_rtr2" {
  device_id     = module.ewr.router_ids["rtr2"]
  ip_address_id = netbox_ip_address.ewr_epl.id
}

resource "netbox_device_primary_ip" "jfk_rtr2" {
  device_id     = module.jfk.router_ids["rtr2"]
  ip_address_id = netbox_ip_address.jfk_epl.id
}

resource "netbox_ipam_role" "networking" {
  name = "Networking"
  slug = "networking"
}

resource "netbox_ipam_role" "mgmt" {
  name = "Management"
  slug = "mgmt"
}

resource "netbox_ipam_role" "compute" {
  name = "Compute"
  slug = "compute"
}

# the transit /30s are provider-assigned, so we hold no aggregate for them
resource "netbox_rir" "rfc1918" {
  name       = "RFC 1918"
  slug       = "rfc1918"
  is_private = true
}

resource "netbox_aggregate" "rfc1918" {
  prefix      = "10.0.0.0/8"
  rir_id      = netbox_rir.rfc1918.id
  tenant_id   = netbox_tenant.vaulter.id
  description = "private address space"
}
