#!/bin/sh
set -eu
T=$(cat /root/.secrets/github-jynx-ios); R=https://api.github.com/repos/salw2e/jynx-ios
RUN=$(curl -sf -H "Authorization: Bearer $T" "$R/actions/runs?status=success&branch=main&per_page=1" | python3 -c 'import json,sys; r=json.load(sys.stdin)["workflow_runs"][0]; print(r["id"], r["run_number"], r["head_sha"][:7])')
set -- $RUN
URL=$(curl -sf -H "Authorization: Bearer $T" "$R/actions/runs/$1/artifacts" | python3 -c 'import json,sys; print([a for a in json.load(sys.stdin)["artifacts"] if a["name"]=="Jynx-ipa"][0]["archive_download_url"])')
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
curl -sfL -H "Authorization: Bearer $T" -o "$TMP/a.zip" "$URL"
python3 -c "import zipfile,sys; zipfile.ZipFile('$TMP/a.zip').extract('Jynx.ipa', '$TMP')"
python3 -c "import zipfile; z=zipfile.ZipFile('$TMP/Jynx.ipa'); assert any(n.startswith('Payload/Jynx.app/') for n in z.namelist())"
mkdir -p /var/www/jynx-download
install -m 644 "$TMP/Jynx.ipa" /var/www/jynx-download/Jynx.ipa.new && mv /var/www/jynx-download/Jynx.ipa.new /var/www/jynx-download/Jynx.ipa
echo "published build #$2 ($3), $(stat -c %s /var/www/jynx-download/Jynx.ipa) bytes"
