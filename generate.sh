#!/bin/bash
# Based on autojson solution by daboynb

# Get APK URL from the argument and ensure it is provided
apk_url="$1"
if [[ -z "${apk_url}" ]]; then
  echo "Error: APK URL parameter is missing."
  exit 1
fi

get_value() {
    echo "$aapt_output" | grep -A2 "name=\"$1\"" | grep "value=" | sed 's/.*value="\([^"]*\)".*/\1/' | head -n1
}

extract_fingerprint_part() {
    fingerprint="$(get_value FINGERPRINT)"
    part_value=$(echo "${fingerprint}" | awk -F'[:/]' -v i="$1" '{print $i}')
    echo "${part_value:-null}"
}

# Create the json file
create_json() {
    cat <<EOF >"${service_file}"
{
  "BRAND": "$(get_value BRAND)",
  "DEVICE": "$(get_value DEVICE)",
  "FINGERPRINT": "$(get_value FINGERPRINT)",
  "ID": "$(extract_fingerprint_part 5)",
  "MANUFACTURER": "$(get_value MANUFACTURER)",
  "MODEL": "$(get_value MODEL)",
  "PRODUCT": "$(get_value PRODUCT)",
  "DEVICE_INITIAL_SDK_INT": "25",
  "SECURITY_PATCH": "$(get_value SECURITY_PATCH)"
}
EOF
}

# Temporary working directory
tmp_dir="$(mktemp -d)"
apk_file="${tmp_dir}/inject.apk"
service_file="pif.json"

trap 'rm -rf "${tmp_dir}"' EXIT

# Try to download the APK file $max_attempts times with a 10-second delay between attempts
max_attempts=3
for i in $(seq 1 "$max_attempts"); do
  curl --silent --show-error --location --output "${apk_file}" "${apk_url}" && break || [[ $i -lt $max_attempts ]] && sleep 10
done
if [[ ! -s "${apk_file}" ]]; then
  echo "Failed to download APK after ${max_attempts} attempts."
  exit 1
fi

# Use aapt to dump the XML tree
aapt_output=$(aapt dump xmltree "${apk_file}" "res/xml/inject_fields.xml")

# Create JSON file
create_json

# Remove strings with "null"
sed -i '/"null"/d' "${service_file}"

# Output the JSON file
cat "${service_file}"
