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

## How to run this

- Parametrize the values in `setup.sh` and run it.

## Token details

| Token issuer | Claim | Value |
| ---- | ---- | ---- |
| GitHub | Issuer   | `iss="https://token.actions.githubusercontent.com"`   |
| GitHub | Audience | `aud="api://AzureADTokenExchange"`   |
| GitHub | Subject  | `sub="repo:chgeuer/azure-workload-identity-github:ref:refs/heads/main"`   |
| Azure | Issuer   | `iss="https://sts.windows.net/mytenant.onmicrosoft.com/"` |
| Azure | Audience | `aud="https://storage.azure.com"`   |
| Azure | Subject  | `sub="079fd90b-a298-480a-b951-257d0974f77e"`   |

The Azure credential is issued by my AAD tenant, has a subject (`"sub": "079fd90b-a298-480a-b951-257d0974f77e"`) equivalent to the service principal's Object ID:

![screenshot-azure-ad-enterprise-app](img/screenshot-azure-ad-enterprise-app.png)

## Azure Portal Screenshots

![sceenshot-azure-ad-federated-credential-overview](img/sceenshot-azure-ad-federated-credential-overview.png)

![sceenshot-azure-ad-federated-credential-details](img/sceenshot-azure-ad-federated-credential-details.png)

![sceenshot-storage-account-role-assignments](img/sceenshot-storage-account-role-assignments-16552367525951.png)