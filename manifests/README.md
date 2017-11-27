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
kubectl config set-cluster "${BOSH_DEPLOYMENT}" \
  --server="https://${master_host}:8443" \
  --insecure-skip-tls-verify=true
kubectl config set-credentials "${BOSH_DEPLOYMENT}-admin" --token="${admin_password}"
kubectl config set-context "${BOSH_DEPLOYMENT}" --cluster="${BOSH_DEPLOYMENT}" --user="${BOSH_DEPLOYMENT}-admin"
kubectl config use-context "${BOSH_DEPLOYMENT}"
```

To confirm that you are connected and configured to your Kubernetes cluster:

```
$ kubectl get all
NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.200.1   <none>        443/TCP   2h
```

## Integrate with Cloud Foundry TCP routing

If you are already running Cloud Foundry, then you can reuse its TCP router to provide public access to your Kubernetes services and the Kubernetes API.
