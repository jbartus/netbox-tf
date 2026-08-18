#!/usr/bin/env bash
# Build a physical-geometry floorplan for a location: the floorplan itself, one image
# layer, a shape per rack and a zone per aisle. No terraform resources exist for this
# plugin, and local-exec cannot hand the new floorplan/layer ids to a later resource,
# so the whole tree is created here in one pass.
#
# Deleting a floorplan cascades to its layers, shapes and zones, so this deletes any
# floorplan of the same name at the same location first and starts clean. That makes
# it re-runnable and makes edits land, rather than stacking duplicates.
#
#   LOCATION   name of the dcim.location the floorplan belongs to
#   NAME       floorplan name
#   IMAGE      path to the background png - the image field is a django ImageField,
#              so pillow has to decode it and an svg is rejected
#   SPEC       json: {width, depth, grid, scale, racks:{<rack name>:{x,y,orientation}},
#              zones:[{type,label,x:[x1,x2],y:[y1,y2]}]}
set -euo pipefail

api="$NETBOX_URL/api"
g="$api/plugins/physical-geometry"
auth="Authorization: Token $NETBOX_TOKEN"
json="Content-Type: application/json"

id_of() { # endpoint, query -> first id or empty
  curl -sS --fail-with-body -G -H "$auth" "$1" --data-urlencode "$2" | jq -r '.results[0].id // empty'
}

location=$(id_of "$api/dcim/locations/" "name=$LOCATION")
[ -n "$location" ] || { echo "no location named $LOCATION" >&2; exit 1; }

# start clean - the cascade takes the layer, shapes and zones with it
old=$(curl -sS --fail-with-body -G -H "$auth" "$g/floorplans/" \
  --data-urlencode "name=$NAME" --data-urlencode "location_id=$location" | jq -r '.results[].id')
for f in $old; do
  curl -sS --fail-with-body -X DELETE -H "$auth" "$g/floorplans/$f/"
done

read -r width depth grid scale <<<"$(jq -r '"\(.width) \(.depth) \(.grid) \(.scale)"' <<<"$SPEC")"

fp=$(curl -sS --fail-with-body -X POST "$g/floorplans/" -H "$auth" -H "$json" \
  -d "{\"name\":\"$NAME\",\"location\":$location,\"base_unit\":\"cm\",
       \"width\":$width,\"depth\":$depth,\"grid_interval\":$grid}" | jq -re .id)

# image_origin_* is the pixel coordinate within the image at which floorplan (0,0)
# falls. The room fills the image, so that is the image's bottom-left: depth * scale.
# order is 1-1000.
layer=$(curl -sS --fail-with-body -X POST "$g/layers/" -H "$auth" \
  -F "floorplan=$fp" -F "name=cage" -F "order=1" -F "is_visible=true" -F "opacity=100" \
  -F "image=@$IMAGE" -F "image_scale=$scale" -F "image_scale_unit=cm" \
  -F "image_origin_x=0" -F "image_origin_y=$((depth * scale))" | jq -re .id)

# a shape can point at a rack in any location - the explorer only draws it when its
# scope selector is on all locations, but the geometry is valid either way
# tab delimited throughout, because zone labels have spaces in them
while IFS=$'\t' read -r rack x y orientation; do
  rid=$(id_of "$api/dcim/racks/" "name=$rack")
  [ -n "$rid" ] || { echo "no rack named $rack" >&2; exit 1; }
  # rack outer dimensions are mm here, as every rack type comes from ndx
  read -r rw rd <<<"$(curl -sS --fail-with-body -H "$auth" "$api/dcim/racks/$rid/" \
    | jq -r '"\((.outer_width // 750) / 10 | floor) \((.outer_depth // 1200) / 10 | floor)"')"
  curl -sS --fail-with-body -X POST "$g/shapes/" -H "$auth" -H "$json" \
    -d "{\"floorplan\":$fp,\"layer\":$layer,\"label\":\"$rack\",\"type\":\"rack\",
         \"x\":$x,\"y\":$y,\"width\":$rw,\"depth\":$rd,
         \"orientation\":\"$orientation\",\"object_type\":\"dcim.rack\",\"object_id\":$rid}" >/dev/null
done < <(jq -r '.racks | to_entries[] | [.key, .value.x, .value.y, .value.orientation] | @tsv' <<<"$SPEC")

while IFS=$'\t' read -r type label x1 x2 y1 y2; do
  curl -sS --fail-with-body -X POST "$g/zones/" -H "$auth" -H "$json" \
    -d "{\"floorplan\":$fp,\"layer\":$layer,\"type\":\"$type\",\"label\":\"$label\",
         \"coordinates\":[[$x1,$y1],[$x2,$y1],[$x2,$y2],[$x1,$y2]]}" >/dev/null
done < <(jq -r '.zones[] | [.type, .label, .x[0], .x[1], .y[0], .y[1]] | @tsv' <<<"$SPEC")
