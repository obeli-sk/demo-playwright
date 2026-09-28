#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

{
  printf 'curl %s\n' "$(curl --version | awk 'NR == 1 { print $2 }')"
  printf 'docker %s\n' "$(docker --version | awk '{ gsub(",", "", $3); print $3 }')"
  printf 'jq %s\n' "$(jq --version | sed 's/^jq-//')"
  just --version
  printf 'node %s\n' "$(node --version | sed 's/^v//')"
  obelisk --version
  qemu-system-x86_64 --version | awk 'NR == 1 { print "qemu", $4 }'
  socat -V | awk '/^socat version / { print $1, $2, $3 }'
} > dev-deps.txt
