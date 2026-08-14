# what is this
a learning exercise in using terraform with netbox

designed to be modular.  the site module deploys an instance of the edge-rack module and one or more instances of the pod module.  the pod module deploys one or more instances of the compute rack module.

the main thing to keep in mind here is the combination of netbox's richly interdependant data model, an unofficial and volunteer maintained provider, and the use of local-exec/bash-scripts means that `apply` runs that try to move or change things after they're first created will often break.  `destroy` is a mixed bag too.  in effect, this isn't a proper terraform project so much as using the terraform dsl to automate a one time netbox instance data population run.  use `./scripts/nbc-restore-db.sh` to "destroy".

# pre-requisites
`terraform`, `curl`, `jq`.

plus a netbox cloud instance with a write-capable api token, and a netbox labs platform api key for the restore script.

# setup
```
terraform init
cp terraform.tfvars.example terraform.tfvars
cp scripts/.env.example scripts/.env
```
then fill both of those in.

# main loop
1. reset the instance
   ```
   ./scripts/nbc-restore-db.sh
   ```
   it returns as soon as it POSTs the restore, it does not wait. the restore takes 3-5 minutes and the instance stops answering partway through, so wait for the device count to read 0 a few times in a row - poll loop is in `CLAUDE.md`.

1. delete the state
   ```
   rm -f terraform.tfstate*
   ```
   skip this and every `data.netbox_device_type` lookup fails.

1. build it
   ```
   terraform apply
   ```
   about 900 objects, a few minutes, one pass.

# what it builds
two sites, ewr (165 halsey) and jfk (375 pearl). each has an edge rack with two border routers and an oob switch, and a pod holding a spine pair plus two compute racks of twenty servers.

everything is powered a/b down to the outlet, and cabled

adding a compute rack is one line in a pod's `racks` map. adding a pod is one entry in a site's `pods`. adding a site is one module block.

# the rest
root `.tf` files follow netbox's own django apps, plus `ndx.tf` and `providers.tf`. the sites are nested modules: `site` > `edge-rack` and `pod` > `compute-rack`.

`DESIGN.md` covers why things are the way they are. `CLAUDE.md` is the working reference, including the traps worth knowing before you edit anything.
