# Both border routers home into every spine, which is what makes the pair redundant:
# lose one router and the fabric still reaches the other through both spines. Neither
# module owns both ends - the pod owns the spines, the edge rack owns the routers - so
# the cabling lives here, the layer that sees both.
#
# A second pod lands on the MX204's other two 100G ports, as four more blocks.
data "netbox_device_interfaces" "edge_uplink" {
  name_regex = "^(et-0/0/[0-3]|Ethernet1/[56])$"
  depends_on = [module.edge, module.pod]
}

locals {
  # `...` plus the [0]s absorb a row the unscoped data source returned twice
  edge_uplink_ports = { for i in data.netbox_device_interfaces.edge_uplink.interfaces : "${i.device_id}/${i.name}" => i.id... }
}

# smf because these cross from the mmr to the pod
resource "netbox_cable" "pod1_spine1_rtr1" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.edge.router_ids["rtr1"]}/et-0/0/0"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.pod["pod1"].spine_ids["spine1"]}/Ethernet1/5"][0]
  }
}

resource "netbox_cable" "pod1_spine1_rtr2" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.edge.router_ids["rtr2"]}/et-0/0/0"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.pod["pod1"].spine_ids["spine1"]}/Ethernet1/6"][0]
  }
}

resource "netbox_cable" "pod1_spine2_rtr1" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.edge.router_ids["rtr1"]}/et-0/0/1"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.pod["pod1"].spine_ids["spine2"]}/Ethernet1/5"][0]
  }
}

resource "netbox_cable" "pod1_spine2_rtr2" {
  status = "connected"
  type   = "smf-os2"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.edge.router_ids["rtr2"]}/et-0/0/1"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.edge_uplink_ports["${module.pod["pod1"].spine_ids["spine2"]}/Ethernet1/6"][0]
  }
}
