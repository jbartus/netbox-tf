# netbox-tf

Terraform for an ephemeral NetBox demo instance. The instance is wiped and rebuilt
constantly — never migrate, never preserve data, never warn about replacement.

## Running it

Resetting the instance is a DB restore, never a `terraform destroy`:

    ./scripts/nbc-restore-db.sh

It reads `ORG_ID`, `TARGET_NB_ID`, `BACKUP_ID` and `API_KEY` from `scripts/.env`.

The script returns as soon as it POSTs the restore — it does not wait for it. The
restore takes 3-5 minutes (observed: 165s), and the instance stops answering
entirely partway through, so neither "the script exited" nor "the API errored" tells
you anything. Be patient, and take three clean reads in a row before believing it —
a single good read once came back from a process that then went away, and the apply
died on 503s a couple of hundred resources in:

    sleep 150
    ok=0
    until [ $ok = 3 ]; do
      sleep 5
      c=$(curl -sf -H "Authorization: Token $T" "$U/api/dcim/devices/?limit=1" | jq -r '.count // empty')
      if [ "$c" = 0 ]; then ok=$((ok + 1)); else ok=0; fi
    done
    sleep 5

Then delete the state:

    rm -f terraform.tfstate*

Otherwise Terraform believes the provisioner-backed resources already ran, never
re-imports the NDX device types, and every `data.netbox_device_type` lookup fails.

## Structure

    main.tf                  globals sentinel + two site modules
    modules/site             site, VLAN group, site-wide vlans/prefixes
      modules/edge-rack      MMR location, panels, rack, 2x MX204, OOB switch
      modules/pod            pod location, panels, spine rack, leaf-spine uplinks, floorplan
        modules/compute-rack rack, 2 PDUs, leaf, servers, per-rack IPAM

Adding a compute rack is one line in a pod's `racks` map. Adding a pod is one entry
in a site's `pods`. Adding a site is one module block.

Root .tf files follow NetBox's Django apps: circuits, dcim, extras, ipam, tenancy.
Plus ndx.tf (a plugin) and providers.tf.

## Floorplans

`ewr-pod1` has a cage floorplan for the Visual Explorer, drawn by `netbox_physical_
geometry`: a floorplan per location, an image layer, a shape per rack and a zone per
aisle. The plugin has no Terraform resources, so `scripts/apply-floorplan.sh` builds
the whole tree in one pass from a JSON spec — one script rather than four because
local-exec cannot hand the new floorplan and layer ids to a later resource. Deleting
a floorplan cascades to its children, so the script deletes and recreates, which makes
edits land instead of stacking duplicates.

The layout lives in main.tf under the pod's entry, keyed by rack *name*, because a
floorplan may place racks the pod does not own — the edge rack is in the edge module.
That is also why `module.pod` carries `depends_on = [module.edge]`.

`images/ewr-pod1-floorplan.svg` is the source, the `.png` beside it is what NetBox
gets. Both are committed. Regenerate with:

    rsvg-convert -o images/ewr-pod1-floorplan.png images/ewr-pod1-floorplan.svg

Five things about this plugin that cost real time to work out:

- **`image_origin_*` is in image pixels, not the base unit,** and anchors the bottom
  of the image, so origin_y is `depth * scale` — not 0. Getting it wrong slides the
  background a whole floorplan away from the racks.
- **`orientation = "0"` faces +Y.** A rack north of its cold aisle needs `180`. Get it
  backwards and the PSU fans face the cold aisle.
- **`layer.order` must be >= 1.** Zero is a validation error.
- **The layer image is a Django ImageField, so SVG is rejected** — Pillow has to
  decode it. Hence the committed PNG.
- **A shape can reference a rack in any location** and the API will not complain, but
  the explorer only draws it when its scope selector is on "all locations".

SVG y runs down while the floorplan's y runs up: `svg_y = (depth - y) * scale`.

## Conventions

Names carry their position: `ewr-pod1-r1-01`, `ewr-pod1-r1-leaf`, `ewr-pod1-spine1`,
`ewr-edge`, `ewr-pod1-net`.

One /24 and one VLAN per compute rack, VID matching the third octet:

    10.1.16.0/24  vid 316   ewr-pod1-r1
      .1          gateway (reserved, no owner yet)
      .2 - .9     dhcp pool (mark_populated + mark_utilized)
      .10 - .99   servers   (ip range)
      .100 - .199 their iLOs (ip range)

So the nth server is .10+n and its iLO is .100+n. The two ranges only say where the
halves are; a rack tops out at 90 servers, which no realistic 42U layout reaches.
They deliberately omit mark_populated/mark_utilized, unlike the dhcp pool: the
addresses inside them are real NetBox objects, so utilization should come from those.
And they document, they don't enforce — nothing stops an iLO landing in the server
half.

Compute rack layout lives in `local.slots` — U position paired with outlet so they
can't drift apart, one server group per PDU feed leg.

## Things that will bite

**Exclusivity.** Cable terminations, rack units and PDU outlets each hold one thing.
Renumbering any of them is a destroy-then-create, never an in-place update. A plan
that looks like a tidy shuffle will fail partway with duplicate-termination or
"U27 is already occupied".

**Device type changes are a silent trap.** Terraform plans `device_type_id` as an
in-place update, but NetBox does not re-instantiate components. The device keeps its
old interfaces while reporting the new type. Force replacement.

**Renaming a resource address leaves no dependency edge.** Terraform will try to
destroy the old object before the things referencing it have moved.

**Bulk API calls silently skip items.** A single call covering 80 devices returns 2xx
having missed a handful. The provisioner scripts loop one device at a time on purpose.

**Provider filters are limited.** The component data sources accept only name, tag and
device_id — no rack_id or location_id — so they read every object of that type in the
instance. `tag` does not help: on a component endpoint it matches the component's own
tags, not the parent device's, and nothing here tags components.

Because the reads are unscoped, one rack paginates over a list the other racks are
still inserting into, and offset pagination over a moving result set hands back some
rows twice. So the 11 locals built from those data sources group with `...` and every
lookup ends in `[0]`:

    psu_ports = { for p in ... : "${p.device_id}/${p.name}" => p.id... }
    object_id = local.psu_ports["${dev}/PSU1"][0]

This tolerates the race rather than removing it — safe because device_id + name is
unique in NetBox, so a repeated key is always the same object. Rows can only be
duplicated, never missed: a miss needs a row's sort position to move earlier, which
takes a delete or a rename, and a cold apply only inserts.

**When the provider learns rack_id/location_id, undo the dedupe.** Add the filter to
each of the 11 data sources, then strip `...` from the locals and `[0]` from the
lookups in modules/{compute-rack/{power,ipam},pod/{power,uplinks},edge-rack/power}.tf.
Leaving it in place is harmless, just noise.

**Expect in-place rack changes on every plan.** Every rack plans a diff clearing
`max_weight`, `mounting_depth`, `outer_*` and `weight*` back to null — the provider
doesn't track the fields a rack inherits from its rack type. Provider bug, not drift,
and applying it changes nothing — don't try to fix it, don't report it as drift.
