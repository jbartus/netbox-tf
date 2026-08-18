# netbox-tf

Terraform for an ephemeral NetBox demo instance. The instance is wiped and rebuilt
constantly — never migrate, never preserve data, never warn about replacement.

## Running it

Reset with a DB restore, never `terraform destroy`:

    ./scripts/nbc-restore-db.sh        # credentials in scripts/.env

It returns as soon as it POSTs. The restore takes 3-5 minutes and the instance stops
answering partway through, so neither the script exiting nor the API erroring means
anything. Poll until the device count reads 0 three times running:

    sleep 150
    ok=0
    until [ $ok = 3 ]; do
      sleep 5
      c=$(curl -sf -H "Authorization: Token $T" "$U/api/dcim/devices/?limit=1" | jq -r '.count // empty')
      if [ "$c" = 0 ]; then ok=$((ok + 1)); else ok=0; fi
    done

Then `rm -f terraform.tfstate*`, or Terraform believes the provisioner-backed resources
already ran, never re-imports the NDX device types, and every `data.netbox_device_type`
lookup fails.

A cold apply is ~900 objects. Use `-parallelism=6` or lower; the default overloads the
instance into 502s.

## Structure

    main.tf                  globals sentinel + two site modules
    modules/site             site, VLAN group, site-wide vlans/prefixes
      modules/edge-rack      MMR location, panels, rack, 2x MX204, OOB switch
      modules/pod            pod location, panels, spine rack, uplinks, floorplan
        modules/compute-rack rack, 2 PDUs, leaf, servers, per-rack IPAM and cabling

Adding a compute rack is one line in a pod's `racks` map. Adding a pod is one entry in
a site's `pods`. Adding a site is one module block.

Root .tf files follow NetBox's Django apps: circuits, dcim, extras, ipam, tenancy, plus
ndx.tf and providers.tf.

## Conventions

Names carry their position: `ewr-pod1-r1-01`, `ewr-pod1-r1-leaf`, `ewr-pod1-spine1`,
`ewr-edge`, `ewr-pod1-net`.

One /24 and one VLAN per compute rack, VID matching the third octet:

    10.1.16.0/24  vid 316   ewr-pod1-r1
      .1          gateway, reserved
      .2 - .9     dhcp pool     (mark_populated + mark_utilized; the dhcp server owns these)
      .10 - .99   servers       (ip range, unmarked - the addresses are real objects)
      .100 - .199 their iLOs    (ip range, unmarked)

Server n is .10+n and its iLO .100+n. The ranges document the halves, they don't
enforce them.

Compute rack layout is `local.slots` — U position paired with PDU outlet so they can't
drift apart, one server group per feed leg.

## Floorplans

Both pods carry a floorplan for Visual Explorer, from the `netbox_physical_geometry`
plugin. Field reference: <https://netboxlabs.com/docs/visual-explorer/floorplans/>

`ewr-pod1` is a 6x4m cage: mesh, sliding door, one row of four between its aisles.
`jfk-pod1` is a 10.2x4.2m slice of a shared hall with no cage, our four racks mid-row;
the neighbouring racks are drawn into the image rather than modelled, since they are
not ours, and the aisles run the full width.

The plugin has no Terraform resources, so `scripts/apply-floorplan.sh` builds the
floorplan, layer, shapes and zones in one pass from a JSON spec — one script rather
than four because local-exec cannot hand the new ids to a later resource. Deleting a
floorplan cascades to its children, so the script deletes and recreates.

Each layout lives in main.tf under its pod, keyed by rack name rather than derived,
because both place their site's edge rack and the edge module owns that. Hence
`depends_on = [module.edge]` on `module.pod`.

The `images/*-floorplan.svg` files are the source; the `.png` beside each is what the
layer takes, as the image field will not accept SVG. Both are committed. Regenerate:

    rsvg-convert -o images/ewr-pod1-floorplan.png images/ewr-pod1-floorplan.svg

SVG y runs down while floorplan y runs up: `svg_y = (depth - y) * scale`.

Two things the field reference does not cover:

- `image_origin_x/y` are pixel offsets giving where floorplan (0,0) falls within the
  image. Both rooms fill their image, so origin_y is `depth * scale`.
- A dark plane renders below the floor, slightly narrower and deeper than the
  floorplan. It does not track the floorplan dimensions and comes from the frontend,
  so there is nothing to set here.

## Things that will bite

**Exclusivity.** Cable terminations, rack units and PDU outlets hold one thing each.
Renumbering any of them is destroy-then-create; a plan that looks like a tidy shuffle
fails partway with duplicate-termination or "U27 is already occupied".

**Device type changes.** Terraform plans `device_type_id` as an in-place update, but
NetBox does not re-instantiate components — the device keeps its old interfaces while
reporting the new type. Force replacement.

**Bulk API calls silently skip items.** One call covering 80 devices returns 2xx having
missed a handful, so the provisioner scripts loop one device at a time.

**Component data sources are unscoped.** They accept only name, tag and device_id — no
rack_id or location_id — so each one reads every object of that type in the instance.
`tag` does not help: on a component endpoint it matches the component's own tags, not
the parent device's, and nothing here tags components.

Two consequences. Reads get slower with every rack added. And offset pagination over a
list other modules are still inserting into returns some rows twice, so the 12 locals
built from these data sources group with `...` and all 25 lookups end in `[0]`:

    psu_ports = { for p in ... : "${p.device_id}/${p.name}" => p.id... }
    object_id = local.psu_ports["${dev}/PSU1"][0]

Safe because device_id + name is unique in NetBox, so a repeated key is always the same
object. When the provider learns rack_id/location_id, add the filter and strip `...`
and `[0]` from modules/{compute-rack/{power,ipam,cabling},pod/{power,uplinks},edge-rack/power}.tf.

**Expect in-place rack changes on every plan.** Every rack plans a diff clearing
`max_weight`, `mounting_depth`, `outer_*` and `weight*` back to null. Provider bug, not
drift; applying it changes nothing.
