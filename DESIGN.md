# Design notes

Why things are the way they are. The code says what; this says why.

## Pod owns both spines and leaves

A pod is a location holding its own power, a spine pair, and the compute racks that
uplink into them. That boundary exists so the pod can cable its own uplinks — it sees
both ends. If spines lived at site level, something above would have to allocate spine
ports across pods, and port assignment would become positional and fragile.

Border routers and the OOB switch stay in the site's edge rack, because one border
pair serves every pod at that site.

## Subnet per rack

Each compute rack gets its own /24 and VLAN, gateway on that rack's leaf. This is the
pure-L3 model: nothing is stretched, the fabric routes between racks.

It is also what keeps `compute-rack` self-contained — the module is handed a prefix and
a VID and needs no coordination with its siblings. An EVPN-VXLAN design would move
subnets up to the fabric and the racks would stop being independent. The empty
`10.x.1.0/24` networking prefix is where an underlay would go if that ever changes.

## iLOs are on the fabric leaf, not a separate OOB network

Deliberate. If the leaf is dead the servers behind it are offline anyway, so iLO
access at that moment does not restore service. The daily value of iLO — power cycle
a wedged box, console, reinstall — all works over the production path, because in
those cases the switch is healthy and the server is the problem.

Out-of-band matters for the *switch*, where the thing you need to reach is the thing
carrying your access. That is what the edge rack's OOB switch is for.

## Roles are looked up by name, behind a sentinel

Modules resolve device roles, rack roles, IPAM roles, tenant and site group by name
rather than taking IDs, to keep the call sites small. `terraform_data.globals`
references every one of those objects, and each site module has a single
`depends_on = [terraform_data.globals]` — which covers nested modules and their data
sources too. That is the "root first, then modules" ordering.

## Provisioner scripts loop per device

`install-modules.sh` and `set-allocated-draw.sh` do one device at a time. Bulk calls
covering the whole fleet returned 2xx while silently skipping ~5% of ports, leaving
power allocation quietly short. Per-device is slower and correct.

Module bays and template-instantiated ports have no Terraform data source, which is
why these run over the API at all.

## NDX import polls rather than reading the response

The import endpoint returns results inline for small batches and queues for larger
ones. Rather than branch on the shape, it POSTs and then polls `import-records` until
every id appears. Works for both, one code path.

Manufacturers are not declared here — NDX creates them. Declaring our own caused
duplicate-slug collisions and blocked `terraform destroy` on the FK.

## Open

- `.1` is a reserved IP with no owner; it wants an SVI on each rack's leaf
- Circuits terminate at the site, not on the border routers
- Spines have no path to the border routers, so the fabric is an island
- PDU management interfaces are uncabled; the net racks have no local switch to take them
- PDU/feed utilization depends on NDX importing `power_port` on outlets
