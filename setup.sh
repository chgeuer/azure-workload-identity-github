#!/bin/bash

# Name of the Azure AD app
appDisplayName="chgeuer-repo-demo2"

# repository on github
githubUser="chgeuer"
githubRepo="azure-workload-identity-github"

# Azure storage account and blob container name
account_name="isvreleases"
container_name="backendrelease"

## Setup
### Azure AD
#### Ensure you're in the right AAD

az account show

#### Create a new app

az ad app create --display-name "${appDisplayName}"

applicationObjectId="$( az ad app list --display-name "${appDisplayName}" | jq -r '.[0].id' )"

az ad sp create --id "${applicationObjectId}"

spJson="$( az ad sp list --display-name "${appDisplayName}" | jq -r '.[0]' )"

spClientId="$( echo "${spJson}" | jq -r '.appId' )"

spObjectId="$( echo "${spJson}" | jq -r '.id' )"

echo "Service Principal ClientID ${spClientId} object ID ${spObjectId}"

#### Set the federated credential

# audience="https://github.com/${githubUser}"
audience="api://AzureADTokenExchange"

 json="$( echo "{}"                                                                   \
   | jq --arg x "federatedCred-${githubUser}-${githubRepo}"            '.name=$x'        \
   | jq --arg x "Github repo ${githubUser}/${githubRepo}"              '.description=$x' \
   | jq --arg x "https://token.actions.githubusercontent.com"          '.issuer=$x'      \
   | jq --arg x "repo:${githubUser}/${githubRepo}:ref:refs/heads/main" '.subject=$x'   \
   | jq                                   '.audiences=[]'                             \
   | jq --arg x "${audience}"             '.audiences[.audiences | length] |= .+ $x'  \
)"

# echo "${json}" | jq .

# https://docs.microsoft.com/en-us/graph/api/application-post-federatedidentitycredentials?view=graph-rest-beta&tabs=http#request

az rest \
   --method POST \
   --uri "https://graph.microsoft.com/beta/applications/${applicationObjectId}/federatedIdentityCredentials/" \
   --body "${json}"

# az rest \
#    --method GET \
#    --uri "https://graph.microsoft.com/beta/applications/${applicationObjectId}/federatedIdentityCredentials/"

######################################
#### Set the Github secrets
######################################

AZURE_TENANT_ID="$( az account show | jq -r '.tenantId' )"
echo "Set ${githubUser}/${githubRepo} secret AZURE_TENANT_ID to ${AZURE_TENANT_ID}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_TENANT_ID --body "${AZURE_TENANT_ID}"

echo "Set ${githubUser}/${githubRepo} secret AZURE_CLIENT_ID to ${spClientId}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_CLIENT_ID --body "${spClientId}"

######################################
#### Grant permissions on the storage account container
######################################

# account_name="isvreleases"
# container_name="backendrelease"

subscriptionId="$( az account show | jq -r '.id' )"
resourceGroup="$( az storage account show --name "${account_name}" | jq -r '.resourceGroup' )"
scope="/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Storage/storageAccounts/${account_name}/blobServices/default/containers/${container_name}"
role="Storage Blob Data Contributor"

echo "Authorizing ${spObjectId} to be a '${role}' on ${scope}"

az role assignment create \
    --role "${role}" \
    --scope "${scope}" \
    --assignee-principal-type "ServicePrincipal" \
    --assignee-object-id "${spObjectId}"
