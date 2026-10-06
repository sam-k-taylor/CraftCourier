#!/usr/bin/env bash
# Builds a CurseForge-ready zip containing only the addon code.
# Usage: ./package.sh [version]   (defaults to the ## Version in the TOC)
set -euo pipefail

cd "$(dirname "$0")"

ADDON="CraftCourier"
TOC_VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' "$ADDON.toc" | tr -d '\r')"
VERSION="${1:-$TOC_VERSION}"
RELEASE_DIR=".release"
STAGE="$RELEASE_DIR/$ADDON"
ZIP="$RELEASE_DIR/$ADDON-$VERSION.zip"

rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE"

cp ./*.lua "$STAGE/"
cp -r UI Media "$STAGE/"
[ -f LICENSE ] && cp LICENSE "$STAGE/"
sed -e "s/^## Version:.*/## Version: $VERSION/" -e "s/@project-version@/$VERSION/g" "$ADDON.toc" > "$STAGE/$ADDON.toc"

(cd "$RELEASE_DIR" && zip -rq "$(basename "$ZIP")" "$ADDON")
rm -rf "$STAGE"

echo "Created $ZIP"
