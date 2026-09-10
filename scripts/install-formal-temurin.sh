#!/usr/bin/env bash
set -euo pipefail

readonly TEMURIN_VERSION='21.0.12.1'
readonly TEMURIN_BUILD='1'
readonly TEMURIN_RELEASE_TAG='jdk-21.0.12.1+1'
readonly TEMURIN_ARCHIVE='OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz'
readonly TEMURIN_ARCHIVE_ROOT='jdk-21.0.12.1+1'
readonly TEMURIN_BYTES='207473347'
readonly TEMURIN_SHA256='ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94'
readonly TEMURIN_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/${TEMURIN_ARCHIVE}"

usage() {
  printf 'usage: %s ABSOLUTE_INSTALL_DIRECTORY\n' "${0##*/}" >&2
}

fail() {
  printf 'install-formal-temurin: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

install_root=$1
[[ "$install_root" == /* ]] || {
  usage
  printf 'install-formal-temurin: destination must be absolute\n' >&2
  exit 64
}
[[ "$install_root" != / ]] || fail 'refusing to use the filesystem root'

[[ "$(uname -s)" == Linux ]] || fail 'the locked runtime requires Linux'
[[ "$(uname -m)" == x86_64 ]] || fail 'the locked runtime requires x86_64'

for command in awk curl sha256sum stat tar; do
  command -v "$command" >/dev/null 2>&1 \
    || fail "required command is unavailable: $command"
done

install_parent=$(dirname -- "$install_root")
install_name=$(basename -- "$install_root")
[[ -n "$install_name" && "$install_name" != . && "$install_name" != .. ]] \
  || fail 'invalid destination name'
mkdir -p -- "$install_parent"
install_parent=$(cd -- "$install_parent" && pwd -P)
install_root="$install_parent/$install_name"
[[ ! -e "$install_root" && ! -L "$install_root" ]] \
  || fail "destination already exists: $install_root"

work_dir=$(mktemp -d)
stage_dir=$(mktemp -d "$install_parent/.temurin-stage.XXXXXX")
cleanup() {
  rm -rf -- "$work_dir"
  if [[ -n "${stage_dir:-}" ]]; then
    rm -rf -- "$stage_dir"
  fi
}
trap cleanup EXIT

archive_path="$work_dir/$TEMURIN_ARCHIVE"
members_path="$work_dir/archive-members.txt"
java_properties="$work_dir/java-properties.txt"

curl --proto '=https' --tlsv1.2 --fail --location --show-error --silent \
  --retry 5 --retry-delay 2 --retry-all-errors \
  --connect-timeout 20 --max-time 600 \
  --output "$archive_path" "$TEMURIN_URL"

printf '%s  %s\n' "$TEMURIN_SHA256" "$archive_path" \
  | sha256sum --check --strict
actual_bytes=$(stat --format='%s' "$archive_path")
[[ "$actual_bytes" == "$TEMURIN_BYTES" ]] \
  || fail "archive size mismatch: expected $TEMURIN_BYTES, received $actual_bytes"

tar --list --gzip --file "$archive_path" > "$members_path"
awk -v root="$TEMURIN_ARCHIVE_ROOT" '
  $0 ~ /(^|\/)\.\.(\/|$)/ {
    print "unsafe parent path in archive: " $0 > "/dev/stderr"
    bad = 1
    next
  }
  $0 == root || $0 == root "/" || index($0, root "/") == 1 { next }
  {
    print "unexpected archive root: " $0 > "/dev/stderr"
    bad = 1
  }
  END { exit bad }
' "$members_path" || fail 'archive member validation failed'

tar --extract --gzip --file "$archive_path" \
  --directory "$stage_dir" --strip-components=1 \
  --no-same-owner --no-same-permissions
[[ -x "$stage_dir/bin/java" ]] || fail 'extracted Java executable is missing'
[[ -f "$stage_dir/release" ]] || fail 'extracted Java release manifest is missing'

"$stage_dir/bin/java" -XshowSettings:properties -version \
  > "$java_properties" 2>&1
cat "$java_properties"

property_value() {
  local key=$1
  awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      prefix = key " = "
      if (index(line, prefix) == 1) {
        print substr(line, length(prefix) + 1)
        exit
      }
    }
  ' "$java_properties"
}

java_vendor=$(property_value java.vendor)
java_version=$(property_value java.version)
java_runtime_version=$(property_value java.runtime.version)
os_arch=$(property_value os.arch)
os_name=$(property_value os.name)

[[ "$java_vendor" == 'Eclipse Adoptium' ]] \
  || fail "unexpected Java vendor: $java_vendor"
[[ "$java_version" == "$TEMURIN_VERSION" ]] \
  || fail "unexpected Java version: $java_version"
[[ "$java_runtime_version" == "$TEMURIN_VERSION+$TEMURIN_BUILD"* ]] \
  || fail "unexpected Java runtime version: $java_runtime_version"
[[ "$os_arch" == amd64 ]] || fail "unexpected Java architecture: $os_arch"
[[ "$os_name" == Linux ]] || fail "unexpected Java operating system: $os_name"

mv -- "$stage_dir" "$install_root"
stage_dir=''

printf 'temurin_release_tag=%s\n' "$TEMURIN_RELEASE_TAG"
printf 'temurin_archive=%s\n' "$TEMURIN_ARCHIVE"
printf 'temurin_archive_bytes=%s\n' "$TEMURIN_BYTES"
printf 'temurin_archive_sha256=%s\n' "$TEMURIN_SHA256"
printf 'java_home=%s\n' "$install_root"
