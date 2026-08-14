locals {
  # one device per feed leg, read top of rack down
  outlets = {
    rtr1 = "power outlet 1"
    rtr2 = "power outlet 2"
    oob1 = "power outlet 9"
  }
}

resource "terraform_data" "modules" {
  for_each = {
    router = { part = "JPSU-650W-AC-AFO", bays = ["Power Supply 0", "Power Supply 1"], devices = values(netbox_device.rtr)[*].id }
    oob    = { part = "PWR-C1-350WAC", bays = ["PS-A", "PS-B"], devices = [netbox_device.oob.id] }
  }
  input            = each.value
  triggers_replace = each.value

  provisioner "local-exec" {
    command = "${path.root}/scripts/install-modules.sh"
    environment = {
      NETBOX_URL   = var.netbox.url
      NETBOX_TOKEN = var.netbox.token
      PART         = self.input.part
      BAYS         = join("\n", self.input.bays)
      DEVICES      = join(" ", self.input.devices)
    }
  }
}

resource "terraform_data" "allocated_draw" {
  for_each = {
    router = { watts = 300, devices = values(netbox_device.rtr)[*].id }
    oob    = { watts = 150, devices = [netbox_device.oob.id] }
  }
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
  name_regex = "^(PEM [01]|PS-[AB])$"
  depends_on = [terraform_data.modules]
}

data "netbox_device_power_ports" "whip" {
  name_regex = "^power whip$"
  depends_on = [netbox_device.pdu]
}

data "netbox_device_power_outlets" "pdu" {
  depends_on = [netbox_device.pdu]
}

# `...` plus the [0]s absorb a row the unscoped data source returned twice
locals {
  psu_ports   = { for p in data.netbox_device_power_ports.psu.power_ports : "${p.device_id}/${p.name}" => p.id... }
  whip_ports  = { for p in data.netbox_device_power_ports.whip.power_ports : p.device_id => p.id... }
  pdu_outlets = { for o in data.netbox_device_power_outlets.pdu.power_outlets : "${o.device_id}/${o.name}" => o.id... }
}

resource "netbox_cable" "whip" {
  for_each = netbox_power_feed.this
  status   = "connected"
  type     = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.whip_ports[netbox_device.pdu[each.key].id][0]
  }
  b_termination {
    object_type = "dcim.powerfeed"
    object_id   = each.value.id
  }
}

resource "netbox_cable" "rtr_psu" {
  for_each = merge([
    for name, dev in netbox_device.rtr : {
      "${name}-a" = { port = "PEM 0", dev = dev.id, pdu = "a", outlet = local.outlets[name] }
      "${name}-b" = { port = "PEM 1", dev = dev.id, pdu = "b", outlet = local.outlets[name] }
    }
  ]...)
  status = "connected"
  type   = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${each.value.dev}/${each.value.port}"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.pdu[each.value.pdu].id}/${each.value.outlet}"][0]
  }
}

resource "netbox_cable" "oob_psu" {
  for_each = { "PS-A" = "a", "PS-B" = "b" }
  status   = "connected"
  type     = "power"

  a_termination {
    object_type = "dcim.powerport"
    object_id   = local.psu_ports["${netbox_device.oob.id}/${each.key}"][0]
  }
  b_termination {
    object_type = "dcim.poweroutlet"
    object_id   = local.pdu_outlets["${netbox_device.pdu[each.value].id}/${local.outlets["oob1"]}"][0]
  }
}
