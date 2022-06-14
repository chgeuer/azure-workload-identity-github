# `chgeuer/azure-workload-identity-github` - a litte experiment to try out Azure AD Workload Identity Federatin with Github

> Upload a file from a Github action into a storage account without having a credential in Github.

## Setup

### Azure AD

#### Ensure you're in the right AAD

```shell
az account show
```

#### Create a new app

```shell
appDisplayName="someApp"
objectId="$( az ad app create --display-name "${appDisplayName}" | jq -r .id)"
#objectId="$( az ad app list   --display-name "${appDisplayName}" | jq -r '.[0].id' )"
```

#### Set the federated credential

```shell
#!/bin/bash

githubUser="chgeuer"
githubRepo="azure-workload-identity-github"

# audience="https://github.com/${githubUser}"
audience="api://AzureADTokenExchange"

json="$( echo "{}" \
  | jq --arg x "federatedCred-${githubUser}-${githubRepo}"            '.name=$x'   \
  | jq --arg x "Github repo ${githubUser}/${githubRepo}"              '.description=$x'  \
  | jq --arg x "https://token.actions.githubusercontent.com"          '.issuer=$x'  \
  | jq --arg x "repo:${githubUser}/${githubRepo}:ref:refs/heads/main" '.subject=$x'  \
  | jq                                                                '.audiences=[]' \
  | jq --arg x "${audience}"                                          '.audiences[.audiences | length] |= .+ $x' \
)"

echo "${json}" | jq .

# https://docs.microsoft.com/en-us/graph/api/application-post-federatedidentitycredentials?view=graph-rest-beta&tabs=http#request
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/${objectId}/federatedIdentityCredentials/" --body "${json}"

az rest --method GET --uri "https://graph.microsoft.com/beta/applications/${objectId}/federatedIdentityCredentials/"
```

#### Set the Github secrets

```shell
#!/bin/bash

tenantId="$( az account show | jq -r '.tenantId' )"
echo "Set ${githubUser}/${githubRepo} secret AZURE_TENANT_ID to ${tenantId}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_TENANT_ID --body "${tenantId}"

appId="$( az ad app show --id "${objectId}" | jq -r '.appId' )"
echo "Set ${githubUser}/${githubRepo} secret AZURE_CLIENT_ID to ${objectId}"
gh secret set --repo "${githubUser}/${githubRepo}" AZURE_CLIENT_ID --body "${objectId}"
```
