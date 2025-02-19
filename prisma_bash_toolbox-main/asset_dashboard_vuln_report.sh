#!/bin/bash
#------------------------------------------------------------------------------------------------------------------#
# Written By Kyle Butler
#
# REQUIREMENTS: 
# Requires jq to be installed: 'sudo apt-get install jq'
#
# SET-UP:
# Create Access Key and Secret Key in the Prisma Cloud Console
# Access keys and Secret keys are created in the Prisma Cloud Console under: Settings > Access Keys
# Find the Prisma Cloud Enterprise Edition API URL specific to your deployment: https://prisma.pan.dev/api/cloud/api-url
#
# SECURITY RECOMMENDATIONS:

source ./secrets/secrets
source ./func/func.sh


# adjust the below variables TIMEUNIT and TIMEAMOUNT as necessary. By default will pull the last 1 month of data
TIMEUNIT="month"
TIMEAMOUNT="1"



#### NO EDITS BELOW


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






OVERALL_SUMMARY=$(curl --request GET \
                       --url "$PC_APIURL/v2/inventory?timeType=relative&timeAmount=$TIMEAMOUNT&timeUnit=$TIMEUNIT" \
                       --header "x-redlock-auth: $PC_JWT" | jq -r '[{summary: "all_accounts",total_number_of_resources: .summary.totalResources, resources_passing: .summary.passedResources, resources_failing: .summary.failedResources, high_severity_issues: .summary.highSeverityFailedResources, medium_severity_issues: .summary.mediumSeverityFailedResources, low_severity_issues: .summary.lowSeverityFailedResources}]')

quick_check "/v2/inventory"

COMPLIANCE_SUMMARY=$(curl --request GET \
                          --header "x-redlock-auth: $PC_JWT" \
                          --url "$PC_APIURL/compliance/posture?timeType=relative&timeAmount=1&timeUnit=month" | jq '[.complianceDetails[] | {framework_name: .name, number_of_policy_checks: .assignedPolicies, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]')

quick_check "/compliance/posture"

SERVICE_SUMMARY=$(curl --request GET \
                       --url "$PC_APIURL/v2/inventory?timeType=relative&timeAmount=1&timeUnit=month&groupBy=cloud.service&scan.status=all" \
                       --header "x-redlock-auth: $PC_JWT" | jq '[.groupedAggregates[]]' | jq 'group_by(.cloudTypeName)[] | {(.[0].cloudTypeName): [.[] | {service_name: .serviceName, high_severity_issues: .highSeverityFailedResources, medium_severity_issues: .mediumSeverityFailedResources, low_severity_issues: .lowSeverityFailedResources, total_number_of_resources: .totalResources}]}')

quick_check "/v2/inventory"

REPORT_DATE=$(date  +%m_%d_%y)
REPORT_LOCATION="./reports/pcee_cspm_kpi_report_$REPORT_DATE.csv"

printf '%s\n' "summary" > "$REPORT_LOCATION"
printf '%s' "$OVERALL_SUMMARY" | jq -r 'map({summary,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,resources_passing,resources_failing}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "compliance summary" >> "$REPORT_LOCATION"
printf '%s' "$COMPLIANCE_SUMMARY" | jq -r 'map({framework_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources,number_of_policy_checks}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "aws" >> "$REPORT_LOCATION"
printf '%s' "$SERVICE_SUMMARY" | jq -r '.aws | select(. != null) | map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "azure" >> "$REPORT_LOCATION"
printf '%s' "$SERVICE_SUMMARY" | jq -r '.azure | select(. != null) | map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "gcp" >> "$REPORT_LOCATION"
printf '%s' "$SERVICE_SUMMARY" | jq -r '.gcp | select(. != null)| map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "oci" >> "$REPORT_LOCATION"
printf '%s' "$SERVICE_SUMMARY" | jq -r '.oci | select(. != null) | map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n%s\n' "alibaba_cloud" >> "$REPORT_LOCATION"
printf '%s' "$SERVICE_SUMMARY" | jq -r '.alibaba_cloud | select(. != null) | map({service_name,high_severity_issues,medium_severity_issues,low_severity_issues,total_number_of_resources}) | (first | keys_unsorted) as $keys | map([to_entries[] | .value]) as $rows | $keys,$rows[] | @csv' >> "$REPORT_LOCATION"

printf '\n\n%s\n\n' "All done! Your report is in the ./reports directory saved as: pcee_cspm_kpi_report_$REPORT_DATE.csv"

exit

