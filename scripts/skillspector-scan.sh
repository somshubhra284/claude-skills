#!/usr/bin/env bash
# Static SkillSpector scan of skills against their triaged baselines.
# Usage: scripts/skillspector-scan.sh [skill-dir ...]   (default: every baselined skill)
# Exit 1 if any skill has active (non-baselined) findings. After editing a skill, its
# baseline goes stale: triage new findings, then run `skillspector baseline` to regenerate.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
bin="${SKILLSPECTOR_DIR:-$root/SkillSpector}/.venv/bin/skillspector"
base="$root/.skillspector-baselines"
[ -x "$bin" ] || { echo "skillspector not found at $bin (clone NVIDIA/SkillSpector and install into .venv)" >&2; exit 2; }

if [ $# -eq 0 ]; then
  set -- $(for f in "$base"/*.yaml; do n=$(basename "$f" .yaml); echo "${n//__//}"; done)  # a__b -> a/b
fi

summary='
import sys, json
d = json.load(sys.stdin); r = d["risk_assessment"]
rec, score, n, sup = r["recommendation"], r["score"], len(d["issues"]), d["suppressed_count"]
print(sys.argv[1].ljust(55), rec.ljust(15), "score=%s active=%s suppressed=%s" % (score, n, sup))
sys.exit(1 if n else 0)'
fail=0
for s in "$@"; do
  s=${s%/}; b="$base/${s//\//__}.yaml"; args=(--no-llm --format json)
  [ -f "$b" ] && args+=(--baseline "$b")
  out=$("$bin" scan "$root/$s" "${args[@]}" 2>/dev/null || true)
  echo "$out" | python3 -I -c "$summary" "$s" || fail=1
done
exit $fail
