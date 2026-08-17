#!/usr/bin/env bash
# Attach an image to any netbox object. There is no terraform resource for image
# attachments, so this goes over the API - and the upload is multipart, not json.
#
#   OBJECT_TYPE  app.model of the thing to attach to, e.g. dcim.site
#   OBJECT_ID    its id
#   FILE         path to the image
set -euo pipefail

api="$NETBOX_URL/api/extras/image-attachments"
auth="Authorization: Token $NETBOX_TOKEN"

# unlike module bays there is no natural "already filled" check - posting twice just
# gives you two attachments - so see whether this object already has one
existing=$(curl -sS --fail-with-body -G -H "$auth" "$api/" \
  --data-urlencode "object_type=$OBJECT_TYPE" \
  --data-urlencode "object_id=$OBJECT_ID" | jq -r '.results[].id')

# already there, so this is a re-run - leave it alone
[ -z "$existing" ] || exit 0

curl -sS --fail-with-body -X POST "$api/" -H "$auth" \
  -F "object_type=$OBJECT_TYPE" \
  -F "object_id=$OBJECT_ID" \
  -F "image=@$FILE" >/dev/null
