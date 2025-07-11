#!/bin/bash
rss_url="https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app"
last_link_file="last_use_apk_url.txt"
apk_url_file="new_apk_url.txt"

# Try to fetch RSS feed (and extract link) $max_attempts times with a 10-second delay between attempts
max_attempts=3
for i in $(seq 1 "$max_attempts"); do
  lastLink=$(curl --silent --show-error "${rss_url}" | grep -oP '<link>\K[^<]+' | head -2 | tail -1) && break || [[ $i -lt $max_attempts ]] && sleep 10
done
if [[ -z "${lastLink}" ]]; then
  echo "Failed to fetch RSS feed after ${max_attempts} attempts."
  exit 1
fi

# Check if pif.json exists or if the APK link has changed
if [[ ! -f "pif.json" ]]; then
  echo "pif.json not found. Continuing the process."
  echo "${lastLink}" > "${apk_url_file}"
  echo "new_apk=true" >> $GITHUB_OUTPUT
  exit 0
elif [[ -f "${last_link_file}" && "$(cat ${last_link_file})" == "${lastLink}" ]]; then
  echo "No new APK and pif.json exists. Exiting."
  echo "new_apk=false" >> $GITHUB_OUTPUT
  exit 0
else
  echo "PrevLink: $(cat ${last_link_file})"
  exho "LastLink: ${lastLink}"
  echo "${lastLink}" > "${apk_url_file}"
  echo "New APK detected. Continuing."
  echo "new_apk=true" >> $GITHUB_OUTPUT
  exit 0
fi
