#!/bin/bash

aadTenant="5f9e748d-300b-48f1-85f5-3aa96d6260cb"
appId="11c309c9-a0c3-47d7-a6e6-b66f8dc69ee6"
storageAccountName="isvreleases"
containerName="backendrelease"

gh_access_token="$( curl \
     --silent \
     --request POST \
     --url "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api%3A%2F%2FAzureADTokenExchange" \
     --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
     --header "Accept: application/json; api-version=2.0" \
     --header "Content-Type: application/json" \
     --data '{}' \
     | jq -r ".value" )"

echo "Github Credential"
IFS='.' read -ra JWT1 <<< "$gh_access_token"
echo "${JWT1[1]}" | base64 -d | jq

#######################################

resource="https://storage.azure.com/.default"
azure_access_token="$( curl \
    --silent \
    --request POST \
    --data-urlencode "response_type=token" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_id=${appId}" \
    --data-urlencode "client_assertion=${gh_access_token}" \
    --data-urlencode "scope=${resource}" \
    "https://login.microsoftonline.com/${aadTenant}/oauth2/v2.0/token" \
    | jq -r ".access_token" )"

echo "Azure Credential"
IFS='.' read -ra JWT2 <<< "$azure_access_token"
echo "${JWT2[1]}" | base64 -d | jq

filename="src.zip"

ls -als src

zip -r "${filename}" src/

storage_url="https://${storageAccountName}.blob.core.windows.net/${containerName}/$( basename "${filename}" )"

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

echo "Drop in ${storage_url}"

# cmd.exe /C "start $( echo "https://jwt.ms/#access_token=${azure_access_token}" )"
