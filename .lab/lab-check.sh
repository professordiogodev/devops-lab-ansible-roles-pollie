#!/usr/bin/env bash
rc=0
need() { if [ -s "$1" ] && grep -vE '^\s*(#|---|$)' "$1" >/dev/null 2>&1; then echo "- ✅ $1 has content"; else echo "- ❌ $1 is still the empty starter"; rc=1; fi; }
for r in database pollie web; do need roles/$r/tasks/main.yml; need roles/$r/handlers/main.yml; need roles/$r/defaults/main.yml; done
n=$(ls roles/pollie/templates/*.j2 2>/dev/null | wc -l); [ "$n" -ge 2 ] && echo "- ✅ roles/pollie has $n templates" || { echo "- ❌ roles/pollie needs at least two templates (env file, systemd unit)"; rc=1; }
n=$(ls roles/web/templates/*.j2 2>/dev/null | wc -l); [ "$n" -ge 1 ] && echo "- ✅ roles/web has a template" || { echo "- ❌ roles/web needs a template"; rc=1; }
grep -q 'community.postgresql' requirements.yml 2>/dev/null && echo "- ✅ requirements.yml lists community.postgresql" || { echo "- ❌ requirements.yml must list the collection you use"; rc=1; }
if python3 .lab/no_shell.py; then echo "- ✅ no shell/command/raw/script tasks"; else echo "- ❌ a role uses shell/command/raw/script: use modules"; rc=1; fi
grep -qE '^ALL CHECKS PASSED \(' SUBMISSION.md && echo "- ✅ SUBMISSION.md shows ALL CHECKS PASSED" || { echo "- ❌ paste the verify.sh output ('ALL CHECKS PASSED') into SUBMISSION.md"; rc=1; }
exit $rc
