resource "terraform_data" "spine_psu" {
  input            = [for s in netbox_device.spine : s.id]
  triggers_replace = [for s in netbox_device.spine : s.id]

  provisioner "local-exec" {
    command = "${path.root}/scripts/install-modules.sh"
    environment = {
      NETBOX_URL   = var.netbox.url
      NETBOX_TOKEN = var.netbox.token
      PART         = "NXA-PAC-1100W-PE2"
      BAYS         = "PS1\nPS2"
      DEVICES      = join(" ", self.input)
    }
  }
}

resource "terraform_data" "spine_draw" {
  input            = [for s in netbox_device.spine : s.id]
  triggers_replace = [for s in netbox_device.spine : s.id]
  depends_on       = [terraform_data.spine_psu]

  provisioner "local-exec" {
    command = "${path.root}/scripts/set-allocated-draw.sh"
    environment = {
      NETBOX_URL   = var.netbox.url
      NETBOX_TOKEN = var.netbox.token
      WATTS        = 400
      DEVICES      = join(" ", self.input)
    }
  }
}

data "netbox_device_power_ports" "spine" {
  name_regex = "^PSU[12]$"
  depends_on = [terraform_data.spine_psu]
}

data "netbox_device_power_ports" "whip" {
  name_regex = "^power whip$"
  depends_on = [netbox_device.net_pdu]
}

data "netbox_device_power_outlets" "pdu" {
  depends_on = [netbox_device.net_pdu]
}

# `...` plus the [0]s absorb a row the unscoped data source returned twice
locals {
  spine_ports = { for p in data.netbox_device_power_ports.spine.power_ports : "${p.device_id}/${p.name}" => p.id... }
  whip_ports  = { for p in data.netbox_device_power_ports.whip.power_ports : p.device_id => p.id... }
  pdu_outlets = { for o in data.netbox_device_power_outlets.pdu.power_outlets : "${o.device_id}/${o.name}" => o.id... }

  # one spine per feed leg, read top of rack down
  spine_outlets = { spine1 = "power outlet 1", spine2 = "power outlet 9" }
}

resource "netbox_cable" "net_whip" {
  for_each = {
    a = netbox_power_feed.net_a.id
    b = netbox_power_feed.net_b.id
  }
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.whip_ports[netbox_device.net_pdu[each.key].id][0]
  }
  b_termination {
    object_type = "dcim.powerfeed"
    object_id   = each.value
  }
}

resource "netbox_cable" "spine_psu_a" {
  for_each = netbox_device.spine
  status   = "connected"
  type     = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.spine_ports["${each.value.id}/PSU1"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.net_pdu["a"].id}/${local.spine_outlets[each.key]}"][0]
  }
}

resource "netbox_cable" "spine_psu_b" {
  for_each = netbox_device.spine
  status   = "connected"
  type     = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.spine_ports["${each.value.id}/PSU2"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.net_pdu["b"].id}/${local.spine_outlets[each.key]}"][0]
  }
}
