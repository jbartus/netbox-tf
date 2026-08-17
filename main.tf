# the modules look these up by name, so they must exist first
resource "terraform_data" "globals" {
  input = [
    terraform_data.ndx_import.id,
    netbox_tenant.vaulter.id,
    netbox_site_group.datacenter.id,
    netbox_device_role.server.id,
    netbox_device_role.pdu.id,
    netbox_device_role.leaf.id,
    netbox_device_role.router.id,
    netbox_device_role.spine.id,
    netbox_device_role.oob.id,
    netbox_rack_role.fabric.id,
    netbox_rack_role.edge.id,
    netbox_rack_role.compute.id,
    netbox_ipam_role.networking.id,
    netbox_ipam_role.mgmt.id,
    netbox_ipam_role.compute.id,
  ]
}

locals {
  netbox = {
    url   = var.netbox_server_url
    token = var.netbox_api_token
  }
}

module "ewr" {
  source     = "./modules/site"
  depends_on = [terraform_data.globals]

  name             = "ewr"
  facility         = "165 Halsey"
  description      = "https://www.165halsey.com"
  physical_address = "165 Halsey Street, Newark, NJ 07102"
  latitude         = "40.736906"
  longitude        = "-74.173213"
  timezone         = "America/New_York"
  dns_zone         = "ewr.vaulter.net"
  image            = "images/165-Halsey-St-Newark-NJ-Building.jpg"

  supernet          = "10.1.0.0/16"
  networking_prefix = "10.1.1.0/24"
  mgmt_prefix       = "10.1.2.0/24"
  edge_location     = "MMR2"
  ntp_servers       = ["0.pool.ntp.org", "1.pool.ntp.org"]

  pods = {
    pod1 = {
      racks = {
        r1 = { prefix = "10.1.16.0/24", vid = 316, spine_ports = [1, 2] }
        r2 = { prefix = "10.1.17.0/24", vid = 317, spine_ports = [3, 4] }
      }

      # one row centred in a 6x4m cage, fronts to the cold aisle. rack pitch is 85 =
      # 75 wide plus a 10 gap; orientation 0 faces +y, so 180 faces the aisle below.
      floorplan = {
        image = "images/ewr-pod1-floorplan.png"
        width = 600
        depth = 400
        grid  = 60
        scale = 2
        racks = {
          "ewr-edge"     = { x = 135, y = 140, orientation = "180" }
          "ewr-pod1-net" = { x = 220, y = 140, orientation = "180" }
          "ewr-pod1-r1"  = { x = 305, y = 140, orientation = "180" }
          "ewr-pod1-r2"  = { x = 390, y = 140, orientation = "180" }
        }
        # aisles are air, so they run out to the mesh
        zones = [
          { type = "cold-aisle", label = "cold aisle", x = [135, 465], y = [20, 140] },
          { type = "hot-aisle", label = "hot aisle", x = [135, 465], y = [260, 380] },
        ]
      }
    }
  }

  netbox = local.netbox
}

module "jfk" {
  source     = "./modules/site"
  depends_on = [terraform_data.globals]

  name             = "jfk"
  facility         = "375 Pearl"
  description      = "https://375pearl.com"
  physical_address = "375 Pearl St, New York, NY 10038"
  latitude         = "40.710945"
  longitude        = "-74.001178"
  timezone         = "America/New_York"
  dns_zone         = "jfk.vaulter.net"
  image            = "images/verizon-building.jpg"

  supernet          = "10.2.0.0/16"
  networking_prefix = "10.2.1.0/24"
  mgmt_prefix       = "10.2.2.0/24"
  edge_location     = "30th Floor"
  ntp_servers       = ["2.pool.ntp.org", "3.pool.ntp.org"]

  pods = {
    pod1 = {
      racks = {
        r1 = { prefix = "10.2.16.0/24", vid = 316, spine_ports = [1, 2] }
        r2 = { prefix = "10.2.17.0/24", vid = 317, spine_ports = [3, 4] }
      }
    }
  }

  netbox = local.netbox
}
