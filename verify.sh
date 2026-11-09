#!/usr/bin/env bash
# Run with: ./verify.sh   (it applies your roles several times, so it takes a few minutes)
cd "$(dirname "$0")"
command -v ansible-playbook >/dev/null || { echo "Ansible is not installed (try: pipx install ansible-core)"; exit 1; }
docker inspect pr-web >/dev/null 2>&1 || { echo "Run ./setup.sh first (or the lab was already torn down)"; exit 1; }
pass=0; failn=0; total=0
check() { local d="$1"; shift; total=$((total+1)); if "$@" >/dev/null 2>&1; then echo "PASS  $d"; pass=$((pass+1)); else echo "FAIL  $d"; failn=$((failn+1)); fi; }
on() { local h=$1; shift; docker exec "$h" sh -c "$*"; }
export ANSIBLE_FORCE_COLOR=0 ANSIBLE_NOCOLOR=1
clean3() { [ "$(echo "$1" | grep 'ok=' | grep -c 'changed=0 .*unreachable=0 .*failed=0')" = 3 ]; }
has() { echo "$1" | grep -q "$2"; }
hasnt() { ! echo "$1" | grep -q "$2"; }
api() { curl -s --max-time 5 "$@"; }
wait_ready() { local i=0; while [ $i -lt 30 ]; do api localhost:8080/api/readyz | grep -q '"status":"ready"' && return 0; i=$((i+1)); sleep 2; done; return 1; }
nonempty() { grep -vE '^[[:space:]]*(#|---|$)' "$1" 2>/dev/null | grep -q .; }

echo "== Structure =="
for r in database pollie web; do
  check "role $r: tasks, defaults and handlers are filled in" bash -c "for f in roles/$r/tasks/main.yml roles/$r/defaults/main.yml roles/$r/handlers/main.yml; do grep -vE '^[[:space:]]*(#|---|\$)' \$f | grep -q . || exit 1; done"
done
check "roles/pollie has at least two .j2 templates (env file and systemd unit)" bash -c "[ \$(ls roles/pollie/templates/*.j2 | wc -l) -ge 2 ]"
check "roles/web has a .j2 template" bash -c "ls roles/web/templates/*.j2"
check "requirements.yml pins community.postgresql" bash -c "grep -q 'community.postgresql' requirements.yml && grep -q 'version' requirements.yml"
check "the collection is installed" bash -c "ansible-galaxy collection list community.postgresql 2>/dev/null | grep -q community.postgresql"
check "no shell/command/raw/script tasks in site.yml or your roles" python3 .lab/no_shell.py
check "site.yml passes --syntax-check and uses roles" bash -c "ansible-playbook site.yml --syntax-check && grep -q 'roles:' site.yml"
check "ansible all -m ping reaches all three servers" bash -c "[ \"\$(ansible all -m ping 2>/dev/null | grep -c SUCCESS)\" = 3 ]"

echo "== Apply =="
run1=$(ansible-playbook site.yml 2>&1); rc1=$?
check "the playbook applies without errors" bash -c "[ $rc1 -eq 0 ]"
run2=$(ansible-playbook site.yml 2>&1)
check "second run changes nothing (idempotent)" clean3 "$run2"
wait_ready

echo "== Pollie works across three servers =="
check "web: / serves the Pollie page" bash -c "curl -s --max-time 5 localhost:8080/ | grep -q '<title>Pollie</title>'"
check "web: X-Served-By: pr-web" bash -c "curl -sI --max-time 5 localhost:8080/ | tr -d '\r' | grep -qi '^X-Served-By: pr-web\$'"
check "/api/healthz answers through Nginx" bash -c "curl -s --max-time 5 localhost:8080/api/healthz | grep -q '\"status\":\"ok\"'"
check "/api/readyz says database and redis are reachable" bash -c "curl -s --max-time 5 localhost:8080/api/readyz | grep -q '\"database\":true' && curl -s --max-time 5 localhost:8080/api/readyz | grep -q '\"redis\":true'"
poll=$(api -X POST -H 'content-type: application/json' -d '{"question":"Verify poll?","options":["yes","no"]}' localhost:8080/api/polls)
pid=$(echo "$poll" | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])' 2>/dev/null)
oid=$(echo "$poll" | python3 -c 'import json,sys;print(json.load(sys.stdin)["options"][0]["id"])' 2>/dev/null)
check "a poll can be created through the web server" bash -c "[ -n '$pid' ]"
vbody=$(printf '{"option_id":%s,"voter_id":"verify-%s"}' "${oid:-0}" "$$")
vcode=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'content-type: application/json' -d "$vbody" "localhost:8080/api/polls/${pid:-0}/votes")
check "a vote is accepted (202)" bash -c "[ '$vcode' = 202 ]"
got=0; i=0; while [ $i -lt 15 ]; do got=$(api "localhost:8080/api/polls/${pid:-0}/results" | python3 -c 'import json,sys;print(json.load(sys.stdin)["total_votes"])' 2>/dev/null); [ "$got" = 1 ] && break; i=$((i+1)); sleep 1; done
check "the vote travels API -> Redis -> worker -> PostgreSQL and shows in the results" bash -c "[ '$got' = 1 ]"

echo "== How it is installed =="
check "pollie-api and pollie-worker are active and enabled" on pr-app 'systemctl is-active pollie-api pollie-worker && systemctl is-enabled pollie-api pollie-worker'
check "the services run as the pollie user, not root" on pr-app '[ "$(systemctl show -p User --value pollie-api)" = pollie ] && [ "$(systemctl show -p User --value pollie-worker)" = pollie ]'
check "/etc/pollie/pollie.env is 0640 root:pollie (it holds passwords)" on pr-app '[ "$(stat -c "%a %U:%G" /etc/pollie/pollie.env)" = "640 root:pollie" ]'
check "pr-web has no PostgreSQL or Redis, pr-app has no nginx" bash -c "! docker exec pr-web dpkg -s postgresql && ! docker exec pr-web dpkg -s redis-server && ! docker exec pr-app dpkg -s nginx"
check "PostgreSQL has a pg_hba rule for pollie and never allows 0.0.0.0/0" on pr-db 'grep -E "^host[[:space:]]+pollie[[:space:]]+pollie" /etc/postgresql/16/main/pg_hba.conf && ! grep -E "0\.0\.0\.0/0|all[[:space:]]+all[[:space:]]+0\.0" /etc/postgresql/16/main/pg_hba.conf'
check "Redis refuses clients without the password" bash -c "docker exec pr-db redis-cli ping | grep -q NOAUTH"

echo "== Change a setting without touching a server =="
before=$(docker exec pr-app systemctl show -p ActiveEnterTimestampMonotonic --value pollie-api)
webbefore=$(docker exec pr-web systemctl show -p ActiveEnterTimestampMonotonic --value nginx)
chg=$(ansible-playbook site.yml -e pollie_log_level=debug --diff 2>&1)
check "the change reaches the env file (LOG_LEVEL=debug)" on pr-app 'grep -q "^LOG_LEVEL=debug" /etc/pollie/pollie.env'
check "the pollie handler restarted the services" has "$chg" 'RUNNING HANDLER \[pollie'
check "Nginx was not restarted (the web role had nothing to do)" bash -c "[ \"\$(docker exec pr-web systemctl show -p ActiveEnterTimestampMonotonic --value nginx)\" = '$webbefore' ] && ! echo \"\$1\" | grep -q 'RUNNING HANDLER \[web'" _ "$chg"
check "the services really restarted" bash -c "[ \"\$(docker exec pr-app systemctl show -p ActiveEnterTimestampMonotonic --value pollie-api)\" != '$before' ]"
check "no password appears in Ansible's output, even with --diff (no_log)" bash -c "! echo \"\$1\" | grep -qE 'w0rd:42|w0rd%3A42|r3dis|s3cret'" _ "$chg"
wait_ready
check "Pollie is still healthy after the change" bash -c "curl -s --max-time 5 localhost:8080/api/readyz | grep -q '\"status\":\"ready\"'"
ansible-playbook site.yml >/dev/null 2>&1
check "dropping the override restores LOG_LEVEL=info" on pr-app 'grep -q "^LOG_LEVEL=info" /etc/pollie/pollie.env'

echo "== Drift =="
docker exec pr-app systemctl stop pollie-worker
dr=$(ansible-playbook site.yml --tags pollie --check 2>&1)
check "--check --tags pollie reports the stopped worker without touching it" bash -c "echo \"\$1\" | grep 'pr-app' | grep 'ok=' | grep -vq 'changed=0' && ! docker exec pr-app systemctl is-active pollie-worker" _ "$dr"
ansible-playbook site.yml --tags pollie >/dev/null 2>&1
check "applying only the pollie tag starts the worker again" on pr-app 'systemctl is-active pollie-worker'
check "and everything is idempotent again" clean3 "$(ansible-playbook site.yml 2>&1)"

echo
if [ "$failn" -eq 0 ]; then echo "ALL CHECKS PASSED ($pass/$total)"; else echo "$failn check(s) failed, $pass passed. Fix the FAIL lines and run ./verify.sh again."; fi
exit "$failn"
