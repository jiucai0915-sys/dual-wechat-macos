#!/bin/bash
set -euo pipefail

app_path="${1:-/Applications/WeChat2.app}"
expected_bundle_id="${2:-com.tencent.xinWeChat2}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "this script only supports macOS"
[[ -d "$app_path" ]] || fail "application not found: $app_path"
[[ -f "$app_path/Contents/Info.plist" ]] || fail "Info.plist not found"

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$expected_bundle_id" ]] || fail "expected bundle ID $expected_bundle_id, got $actual_bundle_id"

codesign --verify --deep --strict "$app_path" || fail "strict signature verification failed"
signature_details="$(codesign -dv --verbose=2 "$app_path" 2>&1)"
grep -q '^Signature=adhoc$' <<<"$signature_details" || fail "signature is not ad-hoc"

printf 'PASS: bundle ID = %s\n' "$actual_bundle_id"
printf 'PASS: deep, strict signature verification\n'
printf 'PASS: ad-hoc signature\n'

executable="$app_path/Contents/MacOS/WeChat"
running_pids="$(pgrep -f -x "$executable" || true)"
if [[ -n "$running_pids" ]]; then
  printf 'PASS: running PID(s) = %s\n' "$(tr '\n' ' ' <<<"$running_pids" | sed 's/[[:space:]]*$//')"
  first_pid="$(head -n 1 <<<"$running_pids")"
  if command -v lsof >/dev/null; then
    storage_roots="$(lsof -p "$first_pid" -Fn 2>/dev/null | sed -n 's/^n//p' | awk -v home="$HOME" 'index($0, home "/Library/Containers/")==1 || index($0, home "/Library/HTTPStorages/")==1' | sed "s#^$HOME/Library/##" | cut -d/ -f1-2 | sort -u || true)"
    if [[ -n "$storage_roots" ]]; then
      printf 'Observed storage roots:\n%s\n' "$storage_roots"
    else
      printf 'NOTE: no independent storage root observed yet; finish the first launch and retry.\n'
    fi
  fi
else
  printf 'NOTE: application is not running. Start it with: open -n %q\n' "$app_path"
fi

for root in Containers HTTPStorages; do
  path="$HOME/Library/$root/$actual_bundle_id"
  if [[ -d "$path" ]]; then
    printf 'PASS: data path exists: %s\n' "$path"
  fi
done
