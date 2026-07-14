#!/bin/bash
set -euo pipefail

source_app="/Applications/WeChat.app"
destination="/Applications/WeChat2.app"
bundle_id="com.tencent.xinWeChat2"
display_name="WeChat2"
launch_after_install=false

usage() {
  cat <<'EOF'
Usage: install-dual-wechat.sh [options]

Options:
  --source PATH         Source WeChat.app (default: /Applications/WeChat.app)
  --destination PATH    Destination .app (default: /Applications/WeChat2.app)
  --bundle-id ID        New main bundle identifier (default: com.tencent.xinWeChat2)
  --display-name NAME   New application display name (default: WeChat2)
  --launch              Launch the copied application after verification
  -h, --help            Show this help

The script refuses to overwrite an existing destination.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --source)
      (($# >= 2)) || fail "--source requires a path"
      source_app="$2"
      shift 2
      ;;
    --destination)
      (($# >= 2)) || fail "--destination requires a path"
      destination="$2"
      shift 2
      ;;
    --bundle-id)
      (($# >= 2)) || fail "--bundle-id requires a value"
      bundle_id="$2"
      shift 2
      ;;
    --display-name)
      (($# >= 2)) || fail "--display-name requires a value"
      display_name="$2"
      shift 2
      ;;
    --launch)
      launch_after_install=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "this script only supports macOS"
[[ -d "$source_app" ]] || fail "source application not found: $source_app"
[[ -f "$source_app/Contents/Info.plist" ]] || fail "source Info.plist not found"
[[ "$source_app" == *.app ]] || fail "source must be an .app bundle"
[[ "$destination" == *.app ]] || fail "destination must end in .app"
[[ "$source_app" != "$destination" ]] || fail "source and destination must differ"
[[ ! -e "$destination" ]] || fail "destination already exists: $destination"
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]] || fail "bundle ID contains unsupported characters"
[[ -n "$display_name" && "$display_name" != */* ]] || fail "display name must be non-empty and cannot contain /"

for tool in ditto codesign xattr find open; do
  command -v "$tool" >/dev/null || fail "required tool not found: $tool"
done
[[ -x /usr/libexec/PlistBuddy ]] || fail "PlistBuddy is unavailable"

original_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")"
[[ -n "$original_bundle_id" ]] || fail "source bundle ID is empty"
[[ "$original_bundle_id" != "$bundle_id" ]] || fail "new bundle ID must differ from the source bundle ID"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/dual-wechat.XXXXXX")"
build_app="$work_dir/WeChatCopy.app"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

printf 'Copying %s to a temporary workspace...\n' "$source_app"
ditto --noextattr --noacl "$source_app" "$build_app"

set_plist_string() {
  local key="$1"
  local value="$2"
  local plist="$build_app/Contents/Info.plist"
  if ! /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist"; then
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
  fi
}

set_plist_string CFBundleIdentifier "$bundle_id"
set_plist_string CFBundleDisplayName "$display_name"
set_plist_string CFBundleName "$display_name"

find "$build_app" -name _CodeSignature -type d -exec rm -rf {} +
xattr -rc "$build_app"

printf 'Applying an ad-hoc signature...\n'
codesign --force --deep --sign - "$build_app"
codesign --verify --deep --strict "$build_app"

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$build_app/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$bundle_id" ]] || fail "temporary copy has an unexpected bundle ID"

destination_parent="$(dirname "$destination")"
if [[ ! -d "$destination_parent" ]]; then
  if mkdir -p "$destination_parent" 2>/dev/null; then
    :
  else
    sudo mkdir -p "$destination_parent"
  fi
fi

printf 'Deploying to %s...\n' "$destination"
if [[ -w "$destination_parent" ]]; then
  ditto --noextattr --noacl "$build_app" "$destination"
else
  sudo ditto --noextattr --noacl "$build_app" "$destination"
fi

codesign --verify --deep --strict "$destination"
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$destination/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$bundle_id" ]] || fail "deployed copy has an unexpected bundle ID"

printf 'Installed successfully.\n'
printf '  Application: %s\n' "$destination"
printf '  Bundle ID:   %s\n' "$actual_bundle_id"
printf '  Signature:   ad-hoc\n'

if [[ "$launch_after_install" == true ]]; then
  open -n "$destination"
  printf 'Launch requested. Verify the running process with:\n'
  printf "  pgrep -fl -x '%s/Contents/MacOS/WeChat'\n" "$destination"
else
  printf 'Launch with: open -n %q\n' "$destination"
fi
