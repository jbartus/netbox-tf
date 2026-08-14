resource "netbox_site" "hq" {
  name             = "Headquarters"
  tenant_id        = netbox_tenant.vaulter.id
  timezone         = "America/New_York"
  physical_address = "209 Elizabeth St, New York, NY 10012"
  latitude         = "40.722790"
  longitude        = "-73.994690"
}

resource "netbox_site_group" "datacenter" {
  name = "Data Centers"
}

resource "netbox_device_role" "server" {
  name      = "server"
  color_hex = "8bc34a"
}

resource "netbox_device_role" "pdu" {
  name      = "PDU"
  color_hex = "ff9800"
}

resource "netbox_device_role" "leaf" {
  name      = "leaf"
  color_hex = "00bcd4"
}

resource "netbox_device_role" "router" {
  name      = "router"
  color_hex = "9c27b0"
}

resource "netbox_device_role" "spine" {
  name      = "spine"
  color_hex = "3f51b5"
}

resource "netbox_device_role" "oob" {
  name      = "oob"
  color_hex = "607d8b"
}

resource "netbox_rack_role" "fabric" {
  name      = "Fabric"
  color_hex = "4caf50"
}

resource "netbox_rack_role" "edge" {
  name      = "Edge"
  color_hex = "e91e63"
}

resource "netbox_rack_role" "compute" {
  name      = "Compute"
  color_hex = "2196f3"
}
