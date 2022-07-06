#!/bin/bash


# If you want your audience handled properly, this call must be a GET.
# https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#updating-your-actions-for-oidc
# https://docs.github.com/en/enterprise-server@3.5/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers#requesting-the-jwt-using-environment-variables

encodedAudience="api%3A%2F%2FAzureADTokenExchange"
gh_access_token="$( curl \
     --silent \
     --url "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${encodedAudience}" \
     --header "Authorization: Bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
     | jq -r ".value" )"

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

gh_claims="$( jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "${gh_access_token}" )"

aad_claims="$( jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "${azure_access_token}" )"

echo "# Tokens"  >> $GITHUB_STEP_SUMMARY
echo "## Github Token" >> $GITHUB_STEP_SUMMARY
echo "| Token Issuer | Claim    |    Value                                    |" >> $GITHUB_STEP_SUMMARY
echo "| ------------ | -------- | ------------------------------------------- |" >> $GITHUB_STEP_SUMMARY
echo "| GitHub       | Issuer   | \`iss=$( echo "${gh_claims}"  | jq .iss )\` |" >> $GITHUB_STEP_SUMMARY
echo "| GitHub       | Audience | \`aud=$( echo "${gh_claims}"  | jq .aud )\` |" >> $GITHUB_STEP_SUMMARY
echo "| GitHub       | Subject  | \`sub=$( echo "${gh_claims}"  | jq .sub )\` |" >> $GITHUB_STEP_SUMMARY
echo "| Azure        | Issuer   | \`iss=$( echo "${aad_claims}" | jq .iss )\` |" >> $GITHUB_STEP_SUMMARY
echo "| Azure        | Audience | \`aud=$( echo "${aad_claims}" | jq .aud )\` |" >> $GITHUB_STEP_SUMMARY
echo "| Azure        | Subject  | \`sub=$( echo "${aad_claims}" | jq .sub )\` |" >> $GITHUB_STEP_SUMMARY


echo "# Tokens 2

## Github Token

| Token Issuer | Claim    |    Value                                    |
| ------------ | -------- | ------------------------------------------- |
| GitHub       | Issuer   | \`iss=$( echo "${gh_claims}"  | jq .iss )\` |
| GitHub       | Audience | \`aud=$( echo "${gh_claims}"  | jq .aud )\` |
| GitHub       | Subject  | \`sub=$( echo "${gh_claims}"  | jq .sub )\` |
| Azure        | Issuer   | \`iss=$( echo "${aad_claims}" | jq .iss )\` |
| Azure        | Audience | \`aud=$( echo "${aad_claims}" | jq .aud )\` |
| Azure        | Subject  | \`sub=$( echo "${aad_claims}" | jq .sub )\` |
" >> "${GITHUB_STEP_SUMMARY}"


# echo "GitHub Token Issuer:   iss=$( echo "${gh_claims}" | jq .iss )"
# echo "GitHub Token Audience: aud=$( echo "${gh_claims}" | jq .aud )"
# echo "GitHub Token Subject:  sub=$( echo "${gh_claims}" | jq .sub )"
# echo "Azure Token Issuer:    iss=$( echo "${aad_claims}" | jq .iss )"
# echo "Azure Token Audience:  aud=$( echo "${aad_claims}" | jq .aud )"
# echo "Azure Token Subject:   sub=$( echo "${aad_claims}" | jq .sub )"

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
