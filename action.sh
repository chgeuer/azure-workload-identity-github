#!/bin/bash

# For some reason, I cannot properly fetch a token for the "api://AzureADTokenExchange" audience.
# I append the "&audience=api%3A%2F%2FAzureADTokenExchange" to the ACTIONS_ID_TOKEN_REQUEST_URL, 
# but no help. Audience (`aud` property in token) remains "https://github.com/chgeuer"
#
encodedAudience="api%3A%2F%2FAzureADTokenExchange"
encodedAudience="api://AzureADTokenExchange"
id_token_url="${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${encodedAudience}"
#
#
# According to the docs and the source, it should work just as-is:
# https://github.com/actions/toolkit/blob/main/packages/core/src/oidc-utils.ts#L70-L73
#
# if (audience) {
#   const encodedAudience = encodeURIComponent(audience)
#   id_token_url = `${id_token_url}&audience=${encodedAudience}`
# }
#
# id_token_url="${ACTIONS_ID_TOKEN_REQUEST_URL}"

# curl \
#      --verbose \
#      --include \
#      --request POST \
#      --url "${id_token_url}" \
#      --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
#      --header "Accept: application/json; api-version=2.0" \
#      --header "Content-Type: application/json" \
#      --data '{}'

echo "IDP: ${id_token_url}"
gh_access_token="$( curl \
     --silent \
     --request POST \
     --url "${id_token_url}" \
     --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
     --header "Accept: application/json; api-version=2.0" \
     --header "Content-Type: application/json" \
     --data '{}' \
     | jq -r ".value" )"

echo "Github Credential"
jq -R 'split(".") | .[0],.[1] | @base64d | fromjson' <<< "${gh_access_token}"

# echo "ACTIONS_ID_TOKEN_REQUEST_URL: $( echo "${ACTIONS_ID_TOKEN_REQUEST_URL}" | base64 --wrap=0  )"

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
