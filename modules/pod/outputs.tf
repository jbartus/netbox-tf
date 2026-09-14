# the site cables these to the edge rack's routers
output "spine_ids" {
  value = {
    spine1 = netbox_device.spine["spine1"].id
    spine2 = netbox_device.spine["spine2"].id
  }
}
