#!/bin/bash

encodedAudience="api%3A%2F%2FAzureADTokenExchange"

# If you want your audience handled properly, this call must be a GET.
gh_access_token="$( curl \
     --silent \
     --url "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${encodedAudience}" \
     --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
     | jq -r ".value" )"

echo "Github Credential"
jq -R 'split(".") | .[0],.[1] | @base64d | fromjson' <<< "${gh_access_token}"

#######################################

azure_access_token="$( curl \
    --silent \
    --request POST \
    --data-urlencode "response_type=token" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
    --data-urlencode "client_assertion=${gh_access_token}" \
    --data-urlencode "scope=https://storage.azure.com/.default" \
    "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
    | jq -r ".access_token" )"

echo "Azure Credential"
jq -R 'split(".") | .[0],.[1] | @base64d | fromjson' <<< "${azure_access_token}"

#######################################

storage_url="https://${account_name}.blob.core.windows.net/${container_name}/$( basename "${filename}" )"

curl \
    --request PUT \
    --header "x-ms-version: 2019-12-12" \
    --header "x-ms-blob-type: BlockBlob"\
    --header "x-ms-blob-content-disposition: attachment; filename=\"$( basename "${filename}" )\"" \
    --header "Content-Type: application/binary" \
    --header "Authorization: Bearer ${azure_access_token}" \
    --header "Content-MD5: $( md5sum "${filename}" | awk '{ print $1 }' | xxd -r -p | base64 )" \
    --upload-file "${filename}" \
    --url "${storage_url}"

echo "cURL uploaded the file to ${storage_url}"
