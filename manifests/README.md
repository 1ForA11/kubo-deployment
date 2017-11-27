# Deploying CFCR

The base manifest "just works" and will deploy a running cluster of Kubernetes:

```
bosh deploy kubo-deployment/manifests/cfcr.yml
```

## Dependencies

The only dependencies are that your BOSH environment has:

* Local DNS - Learn more at https://bosh.io/docs/dns.html including the `runtime-config/dns.yml` runtime configuration so as to add `bosh-dns` job to all instances
* Credhub/UAA
* Cloud Config with `vm_types` named `minimal`, `small`, and `small-highmem` as per similar requirements of [cf-deployment](https://github.com/cloudfoundry/cf-deployment)
* Cloud Config has a network named `default`as per similar requirements of [cf-deployment](https://github.com/cloudfoundry/cf-deployment)
* Not a bosh-lite
* Ubuntu Trusty stemcell `3468` is uploaded (it's up to you to keep up to date with latest `3468.X` versions and update your BOSH deployments)

## Getting Started

You can get started with one `bosh deploy` command. It will download and deploy everything for you.

```
export BOSH_ENVIRONMENT=<bosh-name>
export BOSH_DEPLOYMENT=cfcr
git clone https://github.com/cloudfoundry-incubator/kubo-deployment
bosh deploy kubo-deployment/manifests/cfcr.yml
```

To see the running cluster:

```
$ bosh instances

Deployment 'cfcr'

Instance                                     Process State  AZ  IPs
master/bde7bc5a-a9fd-4bcc-9ba7-b66752fad159  running        z1  10.10.1.20
worker/4518c694-3328-4538-bc08-dedf8a3bf400  running        z1  10.10.1.22
worker/49d317d0-dff2-44a3-b00c-0406ce8a010e  running        z1  10.10.1.23
worker/e00ac851-fadb-4b7d-94c4-8917042ba6cb  running        z1  10.10.1.21
```

Once the deployment is running, you can setup your `kubectl` CLI to connect and authenticate you.

First, get the randomly generated Kubernetes API admin password from Credhub:

```
admin_password=$(bosh int <(credhub get -n "${BOSH_ENVIRONMENT}/${BOSH_DEPLOYMENT}/kubo-admin-password" --output-json) --path=/value)
```

Next, get the dynamically assigned IP address of the `master/0` instance:

```
master_host=$(bosh int <(bosh instances --json) --path /Tables/0/Rows/0/ips)
```

Finally, setup your local `kubectl` configuration:

```
cluster_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}"
user_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}-admin"
context_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}"

kubectl config set-cluster "${cluster_name}" \
  --server="https://${master_host}:8443" \
  --insecure-skip-tls-verify=true
kubectl config set-credentials "${user_name}" --token="${admin_password}"
kubectl config set-context "${context_name}" --cluster="${cluster_name}" --user="${user_name}"
kubectl config use-context "${context_name}"
```

To confirm that you are connected and configured to your Kubernetes cluster:

```
$ kubectl get all
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.200.1   <none>        443/TCP   2h
```

## Example Elastic Search

```
git clone https://github.com/kubernetes/examples kubernetes-examples
cat kubernetes-examples/staging/elasticsearch/README.md
```

## Integrate with Cloud Foundry TCP routing

If you are already running Cloud Foundry, then you can reuse its TCP router to provide public access to your Kubernetes services and the Kubernetes API.

We will also be changing how we interact with the Kubernetes API. Instead of using https://IP:8443 we will access it through the Cloud Foundry TCP routing hostname and the selected port; such as https://tcp.mycompany.com:8443

So we need need to have some certificates regenerated to include the new hostname. Delete them from Credhub:

```
export BOSH_ENVIRONMENT=<bosh-name>
export BOSH_DEPLOYMENT=cfcr
credhub delete -n /$BOSH_ENVIRONMENT/$BOSH_DEPLOYMENT/tls-kubernetes
credhub delete -n /$BOSH_ENVIRONMENT/$BOSH_DEPLOYMENT/tls-kubelet
```

Next, we need to document information about your Cloud Foundry and how CFCR will be allowed to register TCP routes.

Create a file `cf-vars.yml` which might look like:

```yaml
kubernetes_master_host: tcp.apps.mycompany.com
kubernetes_master_port: 8443
routing-cf-api-url: https://api.system.mycompany.com
routing-cf-uaa-url: https://uaa.system.mycompany.com
routing-cf-app-domain-name: apps.mycompany.com
routing-cf-client-id: routing_api_client
routing-cf-client-secret: <<credhub get -n my-bosh/cf/uaa_clients_routing_api_client_secret>>
routing-cf-nats-internal-ips: [10.10.1.6,10.10.1.7,10.10.1.8]
routing-cf-nats-port: 4222
routing-cf-nats-username: nats
routing-cf-nats-password: <<credhub get -n my-bosh/cf/nats_password>>
```

You can try a helper script which might be able to use `bosh`, `cf`, and `credhub` CLIs to look up all the information:

```
./kubo-deployment/manifests/helper/cf-routing-vars.sh > cf-vars.yml
```

In the example `cf-vars.yml` above:

* the Cloud Foundry TCP router is available as hostname `tcp.apps.mycompany.com`, and route `tcp.apps.mycompany.com:8443` will be registered to route to the Kubernetes API running on all `master` instances of our deployment
* the Cloud Foundry internal NATS IPs are available via `bosh instances -d cf`
* extract the Credhub secrets and copy them into `cf-vars.yml`

    ```
    credhub get -n $BOSH_ENVIRONMENT/cf/uaa_clients_routing_api_client_secret --output-json | jq -r .value
    credhub get -n $BOSH_ENVIRONMENT/cf/nats_password --output-json | jq -r .value
    ```

NOTE: in future we can get rid of the `routing-cf-nats-*` variables and instead use the `nats` link from the `cf` deployment from the same BOSH. https://github.com/cloudfoundry-incubator/kubo-release/pull/134

NOTE: hopefully one day `cf` deployment will expose its URLs, admin credentials, and UAA clients via links and remove most of the other variables above. E.g. https://github.com/cloudfoundry/capi-release/pull/65

```
bosh deploy kubo-deployment/manifests/cfcr.yml \
  -o kubo-deployment/manifests/ops-files/cf-routing.yml \
  -l cf-vars.yml
```

We can now re-configure `kubectl` to use the new hostname and its matching certificate (rather than use the smelly `--insecure-skip-tls-verify` flag).

First, get the randomly generated Kubernetes API admin password from Credhub:

```
admin_password=$(bosh int <(credhub get -n "${BOSH_ENVIRONMENT}/${BOSH_DEPLOYMENT}/kubo-admin-password" --output-json) --path=/value)
```

Next, get your TCP hostname from your `cf-vars.yml` (e.g. `tcp.apps.mycompany.com`):

```
master_host=$(bosh int cf-vars.yml --path /kubernetes_master_host)
```

Then, store the root certificate in a temporary file:

```
tmp_ca_file="$(mktemp)"
bosh int <(credhub get -n "${BOSH_ENVIRONMENT}/${BOSH_DEPLOYMENT}/tls-kubernetes" --output-json) --path=/value/ca > "${tmp_ca_file}"
```

Finally, setup your local `kubectl` configuration:

```
cluster_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}"
user_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}-admin"
context_name="cfcr:${BOSH_ENVIRONMENT}:${BOSH_DEPLOYMENT}"

kubectl config set-cluster "${cluster_name}" \
  --server="https://${master_host}:8443" \
  --certificate-authority="${tmp_ca_file}" \
  --embed-certs=true
kubectl config set-credentials "${user_name}" --token="${admin_password}"
kubectl config set-context "${context_name}" --cluster="${cluster_name}" --user="${user_name}"
kubectl config use-context "${context_name}"
```

Confirm that the `:8443` TCP route and certificate for Kubernetes API are working:

```
kubectl get all
```
