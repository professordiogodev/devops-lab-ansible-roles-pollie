#!/usr/bin/env bash
# Removes everything the lab created. Run:  ./teardown.sh
set -uo pipefail
cd "$(dirname "$0")"
LAB=ansible-roles-pollie
ids=$(docker ps -a -q --filter label=lab=$LAB)
extra=$(docker ps -a --format '{{.Names}}' | grep -E '^pr-' || true)
[ -n "$ids" ] && docker rm -f -v $ids >/dev/null
[ -n "$extra" ] && docker rm -f -v $extra >/dev/null
docker network ls -q --filter label=lab=$LAB | xargs -r docker network rm >/dev/null 2>&1 || true
docker network rm pr-net >/dev/null 2>&1 || true
rm -rf keys pollie
echo "Removed the servers, the network, the SSH keys and the cloned Pollie source. Your Ansible files stay. Now run ./verify-teardown.sh to prove it."
