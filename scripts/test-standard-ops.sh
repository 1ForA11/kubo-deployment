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
      check_interpolation "cf-routing.yml" "-l example-vars-files/cf-routing.yml"
      check_interpolation "worker-haproxy.yml" "-v worker_haproxy_tcp_backend_port=8443" "-v worker_haproxy_tcp_frontend_port=8888"
    popd > /dev/null # operations
  popd > /dev/null
  exit $exit_code
}
