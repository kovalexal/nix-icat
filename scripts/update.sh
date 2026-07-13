# Проверяет фид автообновлятора NVIDIA ICAT и обновляет pkgs/version.json.
# Фид (latest.yml) — тот же, куда смотрит electron-updater внутри самого ICAT,
# поэтому версия и sha512 в нём авторитетны by design.

FEED_URL="https://icat-public-releases.s3.amazonaws.com/latest.yml"
VERSION_FILE="pkgs/version.json"

if [ ! -f "$VERSION_FILE" ]; then
  echo "error: $VERSION_FILE not found — run from the repository root" >&2
  exit 1
fi

feed=$(curl -sf --max-time 30 "$FEED_URL")

# latest.yml — плоский YAML, разбираем без yq
new_version=$(echo "$feed" | grep '^version:' | awk '{print $2}' | tr -d '\r')
new_sha512=$(echo "$feed" | grep '^sha512:' | awk '{print $2}' | tr -d '\r')

if [ -z "$new_version" ] || [ -z "$new_sha512" ]; then
  echo "error: failed to parse feed:" >&2
  echo "$feed" >&2
  exit 1
fi

current_version=$(jq -r .version "$VERSION_FILE")

if [ "$new_version" = "$current_version" ]; then
  echo "ICAT $current_version is up to date"
  exit 0
fi

echo "ICAT $current_version -> $new_version"
jq -n --arg v "$new_version" --arg h "sha512-$new_sha512" \
  '{version: $v, sha512: $h}' > "$VERSION_FILE"
echo "updated $VERSION_FILE"
