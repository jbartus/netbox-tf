# leaf 49/50 to spine1, 51/52 to spine2, on the ports named in var.racks
data "netbox_device_interfaces" "fabric" {
  name_regex = "^Ethernet1/[0-9]+$"
  depends_on = [netbox_device.spine, module.compute]
}

locals {
  # `...` plus the [0]s absorb a row the unscoped data source returned twice
  fabric_ports = { for i in data.netbox_device_interfaces.fabric.interfaces : "${i.device_id}/${i.name}" => i.id... }

  # leaf uplink port -> which spine it lands on, and which of the rack's two spine ports
  uplinks = {
    "49" = { spine = "spine1", slot = 0 }
    "50" = { spine = "spine1", slot = 1 }
    "51" = { spine = "spine2", slot = 0 }
    "52" = { spine = "spine2", slot = 1 }
  }

  # one cable per rack per uplink port
  fabric_cables = merge([
    for rack, cfg in var.racks : {
      for port, up in local.uplinks : "${rack}-${port}" => {
        leaf_id    = module.compute[rack].leaf_id
        leaf_port  = "Ethernet1/${port}"
        spine_id   = netbox_device.spine[up.spine].id
        spine_port = "Ethernet1/${cfg.spine_ports[up.slot]}"
      }
    }
  ]...)
}

resource "netbox_cable" "uplink" {
  for_each = local.fabric_cables
  status   = "connected"
  type     = "mmf-om4"

  a_termination {
    object_type = "dcim.interface"
    object_id   = local.fabric_ports["${each.value.leaf_id}/${each.value.leaf_port}"][0]
  }
  b_termination {
    object_type = "dcim.interface"
    object_id   = local.fabric_ports["${each.value.spine_id}/${each.value.spine_port}"][0]
  }
}
