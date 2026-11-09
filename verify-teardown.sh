#!/usr/bin/env bash
# Proves the lab environment is gone. Run with: ./verify-teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
docker info >/dev/null 2>&1 || { echo "Docker is not running"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
none() { [ -z "$(eval "$1")" ]; }
check "no container named pr-*" none "docker ps -a --format '{{.Names}}' | grep -E '^pr-'"
check "no container with the label lab=ansible-roles-pollie" none "docker ps -a -q --filter label=lab=ansible-roles-pollie"
check "no network with the lab label" none "docker network ls -q --filter label=lab=ansible-roles-pollie"
check "the SSH keys are deleted" bash -c "[ ! -e keys/id_ed25519 ]"
check "the cloned pollie source is deleted" bash -c "[ ! -d pollie ]"
for p in 2231 2232 2233 8080; do
  check "port $p is free" bash -c "! (exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null"
done
echo
if [ "$failn" -eq 0 ]; then echo "TEARDOWN VERIFIED ($pass/$total)"; else echo "NOT CLEAN: $failn leftover(s). Finish the tear down steps and run this again."; fi
exit "$failn"
