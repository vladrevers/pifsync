#!/bin/bash

# RSS Feed URL
url="https://sourceforge.net/projects/xiaomi-eu-multilang-miui-roms/rss?path=/xiaomi.eu/Xiaomi.eu-app"
last_link_file="last_use_apk_url.txt"
apk_url_file="new_apk_url.txt"

# Fetch RSS feed and extract the last link
lastLink=$(curl --silent --show-error "${url}" | grep -oP '<link>\K[^<]+' | head -2 | tail -1)

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
  echo "${lastLink}" > "${apk_url_file}"
  echo "New APK detected. Continuing."
  echo "new_apk=true" >> $GITHUB_OUTPUT
  exit 0
fi
