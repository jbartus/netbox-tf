locals {
  # a property of the build, not of the psu part
  draws = {
    server = { watts = 300, devices = netbox_device.server[*].id }
    leaf   = { watts = 350, devices = [netbox_device.leaf.id] }
  }
}

resource "terraform_data" "allocated_draw" {
  for_each         = local.draws
  input            = each.value
  triggers_replace = each.value
  depends_on       = [terraform_data.modules]

  provisioner "local-exec" {
    command = "${path.root}/scripts/set-allocated-draw.sh"
    environment = {
      NETBOX_URL   = var.netbox.url
      NETBOX_TOKEN = var.netbox.token
      WATTS        = self.input.watts
      DEVICES      = join(" ", self.input.devices)
    }
  }
}

data "netbox_device_power_ports" "psu" {
  name_regex = "^PSU[12]$"
  depends_on = [terraform_data.modules]
}

data "netbox_device_power_ports" "whip" {
  name_regex = "^power whip$"
  depends_on = [netbox_device.pdu]
}

data "netbox_device_power_outlets" "pdu" {
  depends_on = [netbox_device.pdu]
}

# the `...` grouping and the [0]s below absorb a row the unscoped data source returned
# twice. device_id + name is unique in netbox, so a repeated key is the same object.
locals {
  psu_ports   = { for p in data.netbox_device_power_ports.psu.power_ports : "${p.device_id}/${p.name}" => p.id... }
  whip_ports  = { for p in data.netbox_device_power_ports.whip.power_ports : p.device_id => p.id... }
  pdu_outlets = { for o in data.netbox_device_power_outlets.pdu.power_outlets : "${o.device_id}/${o.name}" => o.id... }
}

resource "netbox_cable" "whip" {
  for_each = {
    a = netbox_power_feed.a.id
    b = netbox_power_feed.b.id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.whip_ports[netbox_device.pdu[each.key].id][0]
  }
  b_termination {
    object_type = "dcim.powerfeed"
    object_id   = each.value
  }
}

resource "netbox_cable" "leaf_psu" {
  for_each = { "1" = "a", "2" = "b" }
  status   = "connected"
  type     = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.leaf.id}/PSU${each.key}"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.pdu[each.value].id}/${local.leaf_outlet}"][0]
  }
}

resource "netbox_cable" "server_psu1" {
  count  = local.server_count
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.server[count.index].id}/PSU1"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.pdu["a"].id}/${local.slots[count.index].outlet}"][0]
  }
}

resource "netbox_cable" "server_psu2" {
  count  = local.server_count
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.server[count.index].id}/PSU2"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.pdu["b"].id}/${local.slots[count.index].outlet}"][0]
  }
}
