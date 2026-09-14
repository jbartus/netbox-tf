output "site_id" {
  value = netbox_site.this.id
}

# the root terminates this site's circuits on these
output "router_ids" {
  value = module.edge.router_ids
}
