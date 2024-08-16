#!/bin/bash
apk_url="$1"  # Get APK URL from the argument

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

# Download the APK file
curl --silent --show-error --location --output "${apk_file}" "${apk_url}"

# Use aapt to dump the XML tree
aapt_output=$(aapt dump xmltree "${apk_file}" "res/xml/inject_fields.xml")

# Create JSON file
create_json

# Remove strings with "null"
sed -i '/"null"/d' "${service_file}"

# Output the JSON file
cat "${service_file}"
