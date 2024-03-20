#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

JQ_FILTER='map({
    "key": .tag_name,
    "value": .assets
        | map(select(
            (.name | startswith("sd-")) and
            ((.name | endswith(".tar.gz")) or (.name | endswith(".zip"))) and
            (.name | contains("i686") | not) and
            (
                ( (.name | contains("windows")) and (.name | contains("gnu") | not) ) or
                ( (.name | contains("windows") | not) and ( (.name | contains("gnu")) or (.name | contains("musl")) ) and (.name | contains("gnueabihf") | not) ) or
                ( .name | contains("darwin") )
            )
        ))
        | map({
            key: .name |
                ltrimstr("sd-v") |
                rtrimstr(".tar.gz") |
                rtrimstr(".zip") |
                sub("-pc"; "") |
                sub("-apple"; "") |
                sub("-unknown"; "") |
                sub("x86_64"; "amd64") |
                sub("aarch64"; "arm64") |
                gsub("\\d+.\\d+.\\d+-"; "") |
                rtrimstr("-msvc") |
                rtrimstr("-gnu") |
                rtrimstr("-musl") |
                split("-") |
                reverse |
                join("_"),
            value: {
                filename: .name,
                sha256: "sha256-",
            }
        })
        | from_entries
}) | from_entries
'

INFO="$(curl --silent -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/chmln/sd/releases?per_page=1 | jq "$JQ_FILTER")"

for VERSION in $(jq -r 'keys | join("\n")' <<<$INFO); do
  for PLATFORM in $(jq -r ".[\"$VERSION\"] | keys | join(\"\n\")" <<<$INFO); do
    FILENAME=$(jq -r ".[\"$VERSION\"][\"$PLATFORM\"].filename" <<<$INFO)
    SHA256=$(curl -fLs "https://github.com/chmln/sd/releases/download/$VERSION/$FILENAME" | sha256sum | xxd -r -p | base64)
    INFO=$(jq ".[\"$VERSION\"][\"$PLATFORM\"].sha256 = \"sha256-$SHA256\"" <<<$INFO)
  done
done

echo -n "SD_VERSIONS = "
echo $INFO | jq -M

echo ""
echo "Copy the version info into lib/private/sd_toolchain.bzl"
