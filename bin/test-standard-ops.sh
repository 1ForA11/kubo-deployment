#!/bin/bash

test_standard_ops() {
  # Padded for pretty output
  suite_name="STANDARD    "

  pushd ${home}/manifests > /dev/null
    pushd ops-files > /dev/null
      if interpolate ""; then
        pass "cfcr.yml"
      else
        fail "cfcr.yml"
      fi

      check_interpolation "misc/bootstrap.yml" "-l example-vars-files/misc/bootstrap.yml"

      # Infrastructure
      check_interpolation "iaas/aws/cloud-provider.yml"
      check_interpolation "iaas/aws/lb.yml" "-v kubernetes_cluster_tag=test"
      check_interpolation "iaas/gcp/cloud-provider.yml" "-l example-vars-files/iaas/gcp/cloud-provider.yml"
      check_interpolation "iaas/openstack/master-static-ip.yml" "-v kubernetes_master_host=10.11.12.13"
      check_interpolation "iaas/vsphere/cloud-provider.yml" "-l example-vars-files/iaas/vsphere/cloud-provider.yml"
      check_interpolation "iaas/vsphere/master-static-ip.yml" "-v kubernetes_master_host=10.11.12.13"

      # Routing Variations
      check_interpolation "cf-routing.yml" "-l example-vars-files/cf-routing.yml"
      check_interpolation "cf-routing-links.yml" "-l example-vars-files/cf-routing-links.yml"
      check_interpolation "worker-haproxy.yml" "-l example-vars-files/worker-haproxy.yml"
      check_interpolation "worker-haproxy.yml" "-o iaas/vsphere/worker-haproxy.yml" "-v worker_haproxy_ip_addresses=10.10.10.10" "-l example-vars-files/worker-haproxy.yml"
      check_interpolation "worker-haproxy.yml" "-o iaas/openstack/worker-haproxy.yml" "-v worker_haproxy_ip_addresses=10.10.10.10" "-l example-vars-files/worker-haproxy.yml"

      # HTTP proxy options
      check_interpolation "add-http-proxy.yml" "-v http_proxy=10.10.10.10:8000"
      check_interpolation "add-https-proxy.yml" "-v https_proxy=10.10.10.10:8000"
      check_interpolation "add-no-proxy.yml" "-v no_proxy=localhost,127.0.0.1"

      check_interpolation "addons-spec.yml" "-v authorization-mode=rbac" "-v addons-spec={}"
      check_interpolation "use-runtime-config-bosh-dns.yml"


    popd > /dev/null # operations
  popd > /dev/null
  exit $exit_code
}
