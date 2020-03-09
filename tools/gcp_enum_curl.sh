#!/bin/bash

###############################################################################
# GCP enumeration script
#
# This script is meant to run from a Linux Google Compute Instance. All
# commands are passive, and will generate miscellaneous text files in the
# `out-gcp-enum` folder in the current working directory.
#
# This script utilizes only curl and does not require cloud and/or gstuil
#
# Just run the script. Provide a "-d" argument to debug stderr.
#
# This script is based out of an enum script provided by GitLab Red Team
# however this is completly rewritten to use only curl calls and also
# increase enumeration resources
#
# Ismael Goncalves
#
#
#
###############################################################################

OUTDIR="out-gcp-enum-$(date -u +'%Y-%m-%d-%H-%M-%S')"
META="http://metadata.google.internal"
DEBUG="$1"

# We want a unique output dir, to avoid overwriting anything
if [[ ! -d "$OUTDIR" ]]; then
    mkdir "$OUTDIR"
    echo "[*] Created folder '$OUTDIR' for output"
else
    echo "[!] Output folder exists, something went wrong! Exiting."
    exit 1
fi

# This function will help standardize running a command, appending to a log
# file, and reporting on whether or not it completed successfully
function run_cmd () {
    # Syntaxt will be: run_cmd "[COMMAND]" "[LOGFILE]"
    command="$1"
    outfile="$OUTDIR"/"$2"

    # If script is run with '-d' as the first argument, stderr will be shown.
    # Otherwise, we just assume stderr is a permission thing and give a generic
    # failure message.
    if [[ "$DEBUG" == "-d" ]]; then
        /bin/bash -c "$command" >> "$outfile"
    else
        /bin/bash -c "$command" >> "$outfile" 2>/dev/null
    fi
}

# From here on the syntax is:
#  run_cmd "[COMMAND]" "[LOGFILE]"

echo "[*] Scraping metadata server"
url="$META/computeMetadata/v1/?recursive=true&alt=text"
run_cmd "curl '$url' -H 'Metadata-Flavor: Google'" "metadata.txt"

echo "[*] Exporting access token for API access (check expiration after)"

# store token result in a variable so we can use in the subsequent requests
TOKEN=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token -H "Metadata-Flavor: Google"|cut -d "\"" -f4)

# save the token in a file in case one want to do manual requests afterwards
run_cmd "curl -s http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token?alt=text -H 'Metadata-Flavor: Google'" "access-token.txt"

echo "[*] Obtaining project info"
# store project_id result in a variable so we can use in the subsequent requests
PROJECT=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H 'Metadata-Flavor: Google')

echo $PROJECT

echo "[*] Exporting organizations information"
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN'  https://cloudresourcemanager.googleapis.com/v1beta1/organizations" "organizations.json"

echo "[*] Exporting projects information"
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN'  https://cloudresourcemanager.googleapis.com/v1beta1/projects" "projects.json"
echo "[*] Exporting compute instances information"
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN' 'https://www.googleapis.com/compute/v1/projects/$PROJECT/aggregated/instances'" "compute_instances.json"

echo "[*] Exporting buckets information"
# TODO interate over buckets
# Download a bucket object using the following request
# curl -H 'Authorization: Bearer $TOKEN' https://www.googleapis.com/storage/v1/b/[bucket-name]/o/[object-name]?alt=media
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN' 'https://storage.googleapis.com/storage/v1/b?project=$PROJECT'" "buckets_list.json"

echo "[*] Exporting firewall information"
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN' https://compute.googleapis.com/compute/v1/projects/$PROJECT/global/firewalls" "firewall.json"

echo "[*] Exporting subnet information"
# TODO interate over subnets
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN' https://compute.googleapis.com/compute/v1/projects/$PROJECT/global/networks" "subnets.json"

echo "[*] Exporting service accounts"
# TODO iterate over service accounts to obtain keys
# https://iam.googleapis.com/projects/{PROJECT_ID}/serviceAccounts/{ACCOUNT}
run_cmd "curl -s -H 'Authorization: Bearer $TOKEN' https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts" "service_accounts.json"

echo "[+] All done, good luck!"
