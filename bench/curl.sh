#!/usr/bin/env bash
set -euo pipefail
if curl -fsS -o /dev/null http://127.0.0.1:8090/; then
  printf '"ok"\n'
else
  printf '"cannot fetch local page"\n'
  exit 1
fi
