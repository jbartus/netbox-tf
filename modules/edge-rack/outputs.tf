# the site cables these to the pods' spines, and the root terminates circuits on them
output "router_ids" {
  value = {
    rtr1 = netbox_device.rtr["rtr1"].id
    rtr2 = netbox_device.rtr["rtr2"].id
  }
}

# the pods' floorplans place this rack, so they need a real dependency on it
output "rack_id" {
  value = netbox_rack.this.id
}
