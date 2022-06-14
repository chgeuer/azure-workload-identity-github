# Demo of [Azure AD Workload Identity Federation with GitHub](https://github.com/chgeuer/azure-workload-identity-github)

> Upload a file from a GitHub action into a storage account without having a credential in GitHub.

## Goal

- Have a GitHub Action upload files into an Azure Blob Storage Account
  - Do it without having sensitive information in GitHub, by using [Azure Workload Identity Federation](https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust-github?tabs=azure-portal)
  - Show how to do it using proper GitHub Actions
  - Show how to do it using blain bash and curl

## High-level steps

- Create an app in Azure Active Directory
  - Create a federated credential for that app
- Authorize the app to be Blob Storage Data Contributor on the storage account (or the container)
- Bring the AAD tenant ID and the app's client_id into GitHub (stored as 'secrets', even though they are not secrets)

## Setup

### Azure AD

#### Ensure you're in the right AAD

```shell
az account show
```

#### Create a new app

```shell
appDisplayName="chgeuer-repo-demo"

appJson="$( az ad app create \
  --display-name "${appDisplayName}" )"

applicationObjectId="$( az ad app list \
  --display-name "${appDisplayName}" | jq -r '.[0].id' )"

az ad sp create --id "${applicationObjectId}"

spJson="$( az ad sp list --display-name "${appDisplayName}" | jq -r '.[0]' )"
spClientId="$( echo "${spJson}" | jq -r '.appId' )"
spObjectId="$( echo "${spJson}" | jq -r '.id' )"

echo "Service Principal ClientID ${spClientId} object ID ${spObjectId}"
```

#### Set the federated credential

```shell
#!/bin/bash

githubUser="chgeuer"
githubRepo="azure-workload-identity-github"

audience="https://github.com/${githubUser}"
# audience="api://AzureADTokenExchange"

 json="$( echo "{}"                                                                   \
   | jq --arg x "federatedCred-${githubUser}-${githubRepo}" '.name=$x'                \
   | jq --arg x "Github repo ${githubUser}/${githubRepo}"   '.description=$x'         \
   | jq --arg x "https://token.actions.githubusercontent.com"  '.issuer=$x'           \
   | jq --arg x "repo:${githubUser}/${githubRepo}:ref:refs/heads/main"  '.subject=$x' \
   | jq                                   '.audiences=[]'                             \
   | jq --arg x "${audience}"             '.audiences[.audiences | length] |= .+ $x'  \
)"

echo "${json}" | jq .

# https://docs.microsoft.com/en-us/graph/api/application-post-federatedidentitycredentials?view=graph-rest-beta&tabs=http#request
az rest \
   --method POST \
   --uri "https://graph.microsoft.com/beta/applications/${applicationObjectId}/federatedIdentityCredentials/" \
   --body "${json}"

az rest \
   --method GET \
   --uri "https://graph.microsoft.com/beta/applications/${applicationObjectId}/federatedIdentityCredentials/"
```

#### Set the Github secrets

```shell
#!/bin/bash

AZURE_TENANT_ID="$( az account show | jq -r '.tenantId' )"
echo "Set ${githubUser}/${githubRepo} secret AZURE_TENANT_ID to ${AZURE_TENANT_ID}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_TENANT_ID --body "${AZURE_TENANT_ID}"

echo "Set ${githubUser}/${githubRepo} secret AZURE_CLIENT_ID to ${spId}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_CLIENT_ID --body "${spId}"
```

#### Grant permissions on the storage account container

```shell
#!/bin/bash

account_name="isvreleases"
container_name="backendrelease"

subscriptionId="$( az account show | jq -r '.id' )"
resourceGroup="$( az storage account show --name "${storageAccountName}" | jq -r '.resourceGroup' )"
scope="/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup}/providers/Microsoft.Storage/storageAccounts/${account_name}/blobServices/default/containers/${container_name}"
role="Storage Blob Data Contributor" 

echo "Authorizing ${spObjectId} to be a '${role}' on ${scope}"

az role assignment create \
    --role "${role}" \
    --scope "${scope}" \
    --assignee-principal-type "ServicePrincipal" \
    --assignee-object-id "${spObjectId}"
```
