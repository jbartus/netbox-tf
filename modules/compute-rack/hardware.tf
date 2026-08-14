# a compute rack has a fixed bill of materials
data "netbox_device_type" "server" {
  slug = "hpe-proliant-dl360-gen11"
}

data "netbox_device_type" "pdu" {
  slug = "apc-ap8965"
}

data "netbox_device_type" "leaf" {
  slug = "cisco-n9k-c93180yc-fx3"
}

data "netbox_rack_type" "rack" {
  slug = "apc-ar3355b2"
}

data "netbox_device_role" "server" {
  name = "server"
}

data "netbox_device_role" "pdu" {
  name = "PDU"
}

data "netbox_device_role" "leaf" {
  name = "leaf"
}

data "netbox_rack_role" "compute" {
  name = "Compute"
}

# psus, nics, anything bay-mounted installs the same way
locals {
  modules = {
    server_psu = { part = "P38995-B21", bays = ["PSU1", "PSU2"], devices = netbox_device.server[*].id }
    server_nic = { part = "P42044-B21", bays = ["OCP1"], devices = netbox_device.server[*].id }
    leaf_psu   = { part = "NXA-PAC-650W-PE", bays = ["PS1", "PS2"], devices = [netbox_device.leaf.id] }
  }
}

resource "terraform_data" "modules" {
  for_each         = local.modules
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
