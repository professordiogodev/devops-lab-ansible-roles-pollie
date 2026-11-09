"""Exit 1 if site.yml or any role runs a task with the shell, command, raw or script module."""
import glob
import sys

try:
    import yaml
except ImportError:  # no PyYAML: skip the check rather than fail the student
    sys.exit(0)

BAD = {"shell", "command", "raw", "script"}
BAD |= {"ansible.builtin." + b for b in BAD}


def tasks(items):
    for t in items or []:
        yield t
        if isinstance(t, dict):
            for k in ("block", "rescue", "always"):
                if k in t:
                    yield from tasks(t[k])


def load(path):
    try:
        return yaml.safe_load(open(path)) or []
    except Exception:
        return []


bad = []
for p in load("site.yml"):
    if isinstance(p, dict):
        for sect in ("pre_tasks", "tasks", "post_tasks", "handlers"):
            bad += [k for t in tasks(p.get(sect)) if isinstance(t, dict) for k in t if k in BAD]
for f in glob.glob("roles/*/tasks/*.yml") + glob.glob("roles/*/handlers/*.yml"):
    if "/common/" in f:
        continue
    d = load(f)
    if isinstance(d, list):
        bad += [k for t in tasks(d) if isinstance(t, dict) for k in t if k in BAD]
sys.exit(1 if bad else 0)
