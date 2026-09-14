resource "netbox_circuit_type" "epl" {
  name = "Ethernet Private Line"
  slug = "epl"
}

resource "netbox_circuit_type" "internet" {
  name = "Internet"
  slug = "internet"
}

resource "netbox_circuit_provider" "cogent" {
  name = "Cogent"
}

resource "netbox_circuit" "ewr_jfk" {
  cid         = "1-300123456"
  description = "ewr<->jfk"
  provider_id = netbox_circuit_provider.cogent.id
  type_id     = netbox_circuit_type.epl.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "ewr_jfk_a" {
  circuit_id = netbox_circuit.ewr_jfk.id
  term_side  = "A"
  site_id    = module.ewr.site_id
  port_speed = 10000000
}

resource "netbox_circuit_termination" "ewr_jfk_z" {
  circuit_id = netbox_circuit.ewr_jfk.id
  term_side  = "Z"
  site_id    = module.jfk.site_id
  port_speed = 10000000
}

resource "netbox_circuit_provider" "zayo" {
  name = "Zayo"
}

resource "netbox_circuit" "ewr_internet" {
  cid         = "OGKR/123456//ZYO"
  description = "165 halsey internet"
  provider_id = netbox_circuit_provider.zayo.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "ewr_internet_a" {
  circuit_id = netbox_circuit.ewr_internet.id
  term_side  = "A"
  site_id    = module.ewr.site_id
  port_speed = 1000000
}

resource "netbox_circuit_provider" "att" {
  name = "AT&T"
}

resource "netbox_circuit" "jfk_internet" {
  cid         = "ASE-4821637-NY"
  description = "375 pearl internet"
  provider_id = netbox_circuit_provider.att.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "jfk_internet_a" {
  circuit_id = netbox_circuit.jfk_internet.id
  term_side  = "A"
  site_id    = module.jfk.site_id
  port_speed = 1000000
}

resource "netbox_circuit_provider" "comcast" {
  name = "Comcast"
}

resource "netbox_circuit" "hq_internet" {
  cid         = "12.KQGS.487213"
  description = "hq internet"
  provider_id = netbox_circuit_provider.comcast.id
  type_id     = netbox_circuit_type.internet.id
  status      = "active"
  tenant_id   = netbox_tenant.vaulter.id
}

resource "netbox_circuit_termination" "hq_internet_a" {
  circuit_id = netbox_circuit.hq_internet.id
  term_side  = "A"
  site_id    = netbox_site.hq.id
  port_speed = 500000
}

# Each circuit lands on one border router: one handoff, one cable. Internet on rtr1,
# the site-to-site EPL on rtr2, so each router carries one circuit. The carrier's MMR
# panel is the colo's asset, not ours, so it is not modelled - NetBox has xconnect_id
# and pp_info on the termination for it, but this provider does not expose either.
# HQ has no devices, so its circuit stays scoped to the site with nothing to land on.
data "netbox_device_interfaces" "handoff" {
  name_regex = "^xe-0/1/0$"
  depends_on = [module.ewr, module.jfk]
}

locals {
  # `...` plus the [0]s absorb a row the unscoped data source returned twice
  handoff_ports = { for i in data.netbox_device_interfaces.handoff.interfaces : i.device_id => i.id... }
}

resource "netbox_cable" "ewr_internet_handoff" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "circuits.circuittermination"
    object_id   = netbox_circuit_termination.ewr_internet_a.id
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.handoff_ports[module.ewr.router_ids["rtr1"]][0]
  }
}

resource "netbox_cable" "ewr_epl_handoff" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "circuits.circuittermination"
    object_id   = netbox_circuit_termination.ewr_jfk_a.id
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.handoff_ports[module.ewr.router_ids["rtr2"]][0]
  }
}

resource "netbox_cable" "jfk_internet_handoff" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "circuits.circuittermination"
    object_id   = netbox_circuit_termination.jfk_internet_a.id
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.handoff_ports[module.jfk.router_ids["rtr1"]][0]
  }
}

resource "netbox_cable" "jfk_epl_handoff" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "circuits.circuittermination"
    object_id   = netbox_circuit_termination.ewr_jfk_z.id
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.handoff_ports[module.jfk.router_ids["rtr2"]][0]
  }
}
