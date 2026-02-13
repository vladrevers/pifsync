#!/bin/bash
# Based on autopif4 by osm0sis @ xda-developers

set -euo pipefail

PREFERRED_DEVICE="tegu"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

die() { echo "Error: $*"; exit 1; }

echo "==> Crawling Android Developers for latest Pixel Beta device list ..."
wget -q -O "$TMP/versions.html" "https://developer.android.com/about/versions"
wget -q -O "$TMP/latest.html" "$(grep -o 'https://developer.android.com/about/versions/.*[0-9]"' "$TMP/versions.html" | sort -ru | cut -d\" -f1 | head -n1)"
wget -q -O "$TMP/fi.html" "https://developer.android.com$(grep -o 'href=".*download.*"' "$TMP/latest.html" | grep 'qpr' | cut -d\" -f2 | head -n1)"

MODEL_LIST="$(grep -A1 'tr id=' "$TMP/fi.html" | grep 'td' | sed 's;.*<td>\(.*\)</td>.*;\1;' || true)"
PRODUCT_LIST="$(grep 'tr id=' "$TMP/fi.html" | sed 's;.*<tr id="\(.*\)">.*;\1_beta;' || true)"

[ -z "$MODEL_LIST" ] && die "Failed to get device list"

echo "Available devices:"
paste <(echo "$MODEL_LIST") <(echo "$PRODUCT_LIST")

# Select preferred device or fall back to first
PRODUCT="" MODEL=""
i=1
while IFS= read -r prod; do
  dev="$(echo "$prod" | sed 's/_beta//')"
  if [ "$dev" = "$PREFERRED_DEVICE" ]; then
    MODEL="$(echo "$MODEL_LIST" | sed -n "${i}p")"
    PRODUCT="$prod"
    break
  fi
  i=$((i + 1))
done <<< "$PRODUCT_LIST"

if [ -z "$PRODUCT" ]; then
  echo "Warning: $PREFERRED_DEVICE not found, using first device"
  MODEL="$(echo "$MODEL_LIST" | head -n1)"
  PRODUCT="$(echo "$PRODUCT_LIST" | head -n1)"
fi

DEVICE="$(echo "$PRODUCT" | sed 's/_beta//')"
echo "==> Selected: $MODEL ($PRODUCT)"

echo "==> Crawling Android Flash Tool for latest Pixel Canary build info ..."
wget -q -O "$TMP/flash.html" "https://flash.android.com/"
API_KEY="$(grep -o '<body data-client-config=.*' "$TMP/flash.html" | cut -d\; -f2 | cut -d\& -f1)"
wget -q -O "$TMP/station.json" --header="Referer: https://flash.android.com" \
  "https://content-flashstation-pa.googleapis.com/v1/builds?product=$PRODUCT&key=$API_KEY"

tac "$TMP/station.json" | grep -m1 -A13 '"canary": true' > "$TMP/canary.json" || true

ID="$(grep 'releaseCandidateName' "$TMP/canary.json" | cut -d\" -f4 || true)"
INCREMENTAL="$(grep 'buildId' "$TMP/canary.json" | cut -d\" -f4 || true)"

[ -z "$ID" ] || [ -z "$INCREMENTAL" ] && die "Failed to extract build info from JSON"
echo "Build: $ID / $INCREMENTAL"

echo "==> Crawling Pixel Update Bulletins for security patch level ..."
CANARY_ID="$(grep '"id"' "$TMP/canary.json" | sed -e 's;.*canary-\(.*\)".*;\1;' -e 's;^\(.\{4\}\);\1-;' || true)"
[ -z "$CANARY_ID" ] && die "Failed to extract canary id"

wget -q -O "$TMP/secbull.html" "https://source.android.com/docs/security/bulletin/pixel" || true
SECURITY_PATCH="$(grep "<td>$CANARY_ID" "$TMP/secbull.html" | sed 's;.*<td>\(.*\)</td>;\1;' || true)"
if [ -z "$SECURITY_PATCH" ]; then
  echo "Warning: exact patch not found (or fetch failed), assuming ${CANARY_ID}-05"
  SECURITY_PATCH="${CANARY_ID}-05"
fi
echo "Security patch: $SECURITY_PATCH"

FINGERPRINT="google/$PRODUCT/$DEVICE:CANARY/$ID/$INCREMENTAL:user/release-keys"

echo "==> Creating pif_beta.json ..."
cat > pif_beta.json <<EOF
{
  "BRAND": "google",
  "DEVICE": "$DEVICE",
  "FINGERPRINT": "$FINGERPRINT",
  "ID": "$ID",
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "PRODUCT": "$PRODUCT",
  "DEVICE_INITIAL_SDK_INT": "32",
  "SECURITY_PATCH": "$SECURITY_PATCH"
}
EOF

cat pif_beta.json
echo "Done!"
