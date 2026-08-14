# servers to the leaf: data on 1-20, ilo on 21-40, both following the slot order so
# port n is the nth server down the rack. the leaf's uplinks live up on 49-52.
data "netbox_device_interfaces" "leaf_ports" {
  name_regex = "^Ethernet1/[0-9]+$"
  depends_on = [netbox_device.leaf]
}

locals {
  # `...` plus the [0]s absorb a row the unscoped data source returned twice
  leaf_ports = { for i in data.netbox_device_interfaces.leaf_ports.interfaces : "${i.device_id}/${i.name}" => i.id... }

  # ilo lands 20 ports further along than its server's data port
  ilo_port_offset = 20
}

resource "netbox_cable" "server_data" {
  count  = local.server_count
  status = "connected"
  type   = "dac-passive"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.server_nics["${netbox_device.server[count.index].id}/Ethernet/OCP1/1"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.leaf_ports["${netbox_device.leaf.id}/Ethernet1/${count.index + 1}"][0]
  }
}

# 1g copper sfp in an sfp28 port; netbox does not police the media match
resource "netbox_cable" "server_ilo" {
  count  = local.server_count
  status = "connected"
  type   = "cat6"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.server_nics["${netbox_device.server[count.index].id}/iLO"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.leaf_ports["${netbox_device.leaf.id}/Ethernet1/${count.index + local.ilo_port_offset + 1}"][0]
  }
}
