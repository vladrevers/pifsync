#!/bin/bash
# Based on autopif2 solution by osm0sis

echo "Loading latest beta info..."
wget -q -O PIXEL_VERSIONS_HTML https://developer.android.com/about/versions
wget -q -O PIXEL_LATEST_HTML $(grep -m1 'developer.android.com/about/versions/' PIXEL_VERSIONS_HTML | cut -d\" -f2)
wget -q -O PIXEL_OTA_HTML https://developer.android.com$(grep -om1 'href=".*download-ota"' PIXEL_LATEST_HTML | cut -d\" -f2)

BETA_REL_DATE="$(date -d "$(grep -m1 -A1 'Release date' PIXEL_OTA_HTML | tail -n1 | sed 's;.*<td>\(.*\)</td>.*;\1;')" '+%Y-%m-%d')"
echo "Release date: $BETA_REL_DATE"

MODEL_LIST="$(grep -A1 'tr id=' PIXEL_OTA_HTML | grep 'td' | sed 's;.*<td>\(.*\)</td>;\1;')"
PRODUCT_LIST="$(grep -o 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\/ -f2)"
OTA_LIST="$(grep 'ota/.*_beta' PIXEL_OTA_HTML | cut -d\" -f2)"

SEED=$(date -d "$BETA_REL_DATE" '+%s')
RANDOM=$SEED - 11

list_count="$(echo "$MODEL_LIST" | wc -l)"
list_rand="$((RANDOM % $list_count + 1))"
IFS=$'\n'
set -- $MODEL_LIST
MODEL="$(eval echo \${$list_rand})"
set -- $PRODUCT_LIST
PRODUCT="$(eval echo \${$list_rand})"
set -- $OTA_LIST
OTA="$(eval echo \${$list_rand})"
DEVICE="$(echo "$PRODUCT" | sed 's/_beta//')"

echo "Selected device: $MODEL ($PRODUCT)"

(ulimit -f 3; wget -q -O PIXEL_ZIP_METADATA $OTA) 2>/dev/null
FINGERPRINT="$(grep -am1 'post-build=' PIXEL_ZIP_METADATA | cut -d= -f2)"
SECURITY_PATCH="$(grep -am1 'security-patch-level=' PIXEL_ZIP_METADATA | cut -d= -f2)"

if [ -z "$FINGERPRINT" -o -z "$SECURITY_PATCH" ]; then
    echo "Error: failed to get device metadata"
    exit 1
fi

echo "Creating pif_beta.json..."
cat > pif_beta.json <<EOF
{
  "BRAND": "google",
  "DEVICE": "$DEVICE",
  "FINGERPRINT": "$FINGERPRINT",
  "ID": "$(echo "${FINGERPRINT}" | awk -F'[:/]' -v i="5" '{print $i}')",
  "MANUFACTURER": "Google",
  "MODEL": "$MODEL",
  "PRODUCT": "$PRODUCT",
  "DEVICE_INITIAL_SDK_INT": "32",
  "SECURITY_PATCH": "$SECURITY_PATCH"
}
EOF

rm -f PIXEL_*_HTML PIXEL_ZIP_METADATA

echo "Done! pif_beta.json created"
