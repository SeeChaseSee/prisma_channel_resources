#!/bin/bash
# Author Kyle Butler
# REQUIREMENTS:
#   jq needs to be installed: 
#   debian/ubuntu: sudo apt install jq
#   rhel/fedora: sudo yum install jq
#   macos: sudo brew install jq


# Access key should be created in the Prisma Cloud Enterprise Edition Console under: Settings > Accesskeys


# INSTRUCTIONS:
# install requirement jq

source ./secrets/secrets
source ./func/func.sh

# adjust as needed default is to look back 3 months
TIMEUNIT="month" # could be day, month, year
TIMEAMOUNT="3" # integer value

####### No edits needed below this line

pce-var-check

AUTH_PAYLOAD=$(cat <<EOF
{"username": "$PC_ACCESSKEY", "password": "$PC_SECRETKEY"}
EOF
)


PC_JWT_RESPONSE=$(curl --request POST \
                       --url "$PC_APIURL/login" \
                       --header 'Accept: application/json; charset=UTF-8' \
                       --header 'Content-Type: application/json; charset=UTF-8' \
                       --data "${AUTH_PAYLOAD}")

quick_check "/login"


PC_JWT=$(printf %s "$PC_JWT_RESPONSE" | jq -r '.token' )

REPORT_DATE=$(date  +%m_%d_%y)

RESPONSE_DATA=$(curl --request GET \
                     --url "$PC_APIURL/v2/inventory?timeType=relative&timeAmount=$TIMEAMOUNT&timeUnit=$TIMEUNIT&groupBy=resource.type&scan.status=all" \
                     --header "x-redlock-auth: $PC_JWT")
quick_check "/v2/inventory?timeType=relative&timeAmount=$TIMEAMOUNT&timeUnit=$TIMEUNIT&groupBy=resource.type&scan.status=all"

RESPONSE_JSON=$(printf '%s' "$RESPONSE_DATA" | jq '[.groupedAggregates[]] | group_by(.cloudTypeName)[]| {(.[0].cloudTypeName): [.[] | {resourceTypeName: .resourceTypeName, highSeverityIssues: .highSeverityFailedResources, mediumSeverityIssues: .mediumSeverityFailedResources, lowSeverityIssues: .lowSeverityFailedResources, passedResources: .passedResources, failedResources: .failedResources, totalResources: .totalResources}]}')


REPORT_LOCATION="./reports/pcee_asset_inventory_with_alerts_$REPORT_DATE.csv"

printf '%s\n' "aws" >> "$REPORT_LOCATION"
printf '%s' "$RESPONSE_JSON" | jq -r '.aws | select(. != null) | map({resourceTypeName, highSeverityIssues, mediumSeverityIssues, lowSeverityIssues, passedResources, failedResources, totalResources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "azure" >> "$REPORT_LOCATION"
printf '%s' "$RESPONSE_JSON" | jq -r '.azure | select(. != null) | map({resourceTypeName, highSeverityIssues, mediumSeverityIssues, lowSeverityIssues, passedResources, failedResources, totalResources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "gcp" >> "$REPORT_LOCATION"
printf '%s' "$RESPONSE_JSON" | jq -r '.gcp | select(. != null) | map({resourceTypeName, highSeverityIssues, mediumSeverityIssues, lowSeverityIssues, passedResources, failedResources, totalResources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n\n' "All done! Your report is saved in the ./reports directory as pcee_asset_inventory_with_alerts_$REPORT_DATE.csv"


exit
