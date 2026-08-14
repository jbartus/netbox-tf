locals {
  ndx_ids = [
    "cisco/cisco-c9300-48t",
    "cisco/cisco-n9k-c93180yc-fx3",
    "cisco/cisco-n9k-c9336c-fx2",
    "cisco/NXA-PAC-650W-PE",
    "cisco/NXA-PAC-1100W-PE2",
    "cisco/PWR-C1-350WAC",
    "hpe/hpe-proliant-dl360-gen11",
    "hpe/P38995-B21",
    "hpe/P42044-B21",
    "juniper/juniper-mx204",
    "juniper/JPSU-650W-AC-AFO",
    "schneider-electric/apc-ar3355b2",
    "schneider-electric/apc-ap8965",
  ]
}

# no ndx in the tf provider, but there is a rest api
resource "terraform_data" "ndx_import" {
  input            = local.ndx_ids
  triggers_replace = local.ndx_ids

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      auth="Authorization: Token ${var.netbox_api_token}"
      base="${var.netbox_server_url}/api/plugins/ndx"
      ids='${jsonencode(self.input)}'

      curl -sS --fail-with-body -X POST "$base/import/" \
        -H "$auth" -H "Content-Type: application/json" \
        -d '${jsonencode({ ndx_ids = self.input })}' >/dev/null

      # small batches import inline, bigger ones queue - either way wait for the records
      for _ in $(seq 60); do
        have=$(curl -sS --fail-with-body -H "$auth" "$base/import-records/?limit=0" \
          | jq -c '[.results[].ndx_id]')
        [ "$(jq -n --argjson want "$ids" --argjson have "$have" '$want - $have | length')" = 0 ] && exit 0
        sleep 2
      done

      echo "ndx import still incomplete after 120s" >&2
      exit 1
    EOT
  }
}
