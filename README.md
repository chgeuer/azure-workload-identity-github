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

## Azure Portal Screenshots

![sceenshot-azure-ad-federated-credential-overview](img/sceenshot-azure-ad-federated-credential-overview.png)

![sceenshot-azure-ad-federated-credential-details](img/sceenshot-azure-ad-federated-credential-details.png)

![sceenshot-storage-account-role-assignments](img/sceenshot-storage-account-role-assignments-16552367525951.png)

## Output from the pure bash GitHub action

#### GitHub Credential

The credential issued by the GitHub token issuer has the following properties which are important for Azure AD:

- Issuer `"iss": "https://token.actions.githubusercontent.com"`
- Subject: `"sub": "repo:chgeuer/azure-workload-identity-github:ref:refs/heads/main"`
- Audience: `"aud": "https://github.com/chgeuer"`

```text
{
  "typ": "JWT",
  "alg": "RS256",
  "x5t": "eBZ_cn3sXYAd0ch4THBKHIgOwOE",
  "kid": "78167F727DEC5D801DD1C8784C704A1C880EC0E1"
}
{
  "jti": "7bf1acbe-1f21-45cd-a7a9-e2448c1091ca",
  "sub": "repo:chgeuer/azure-workload-identity-github:ref:refs/heads/main",
  "aud": "https://github.com/chgeuer",
  "ref": "refs/heads/main",
  "sha": "7ad6b5b4691babd53c4a46a7dd731844423d5814",
  "repository": "chgeuer/azure-workload-identity-github",
  "repository_owner": "chgeuer",
  "repository_owner_id": "795162",
  "run_id": "2497687560",
  "run_number": "50",
  "run_attempt": "1",
  "repository_id": "503119826",
  "actor_id": "795162",
  "actor": "chgeuer",
  "workflow": "ZIP the source and upload",
  "head_ref": "",
  "base_ref": "",
  "event_name": "push",
  "ref_type": "branch",
  "job_workflow_ref": "chgeuer/azure-workload-identity-github/.github/workflows/zip-and-upload.yml@refs/heads/main",
  "iss": "https://token.actions.githubusercontent.com",
  "nbf": 1655234716,
  "exp": 1655235616,
  "iat": 1655235316
}
```

#### Azure Credential

The Azure credential is issued by my AAD tenant, has a subject (`"sub": "079fd90b-a298-480a-b951-257d0974f77e"`) equivalent to the service principal's Object ID:

![screenshot-azure-ad-enterprise-app](img/screenshot-azure-ad-enterprise-app.png)

```text
{
  "typ": "JWT",
  "alg": "RS256",
  "x5t": "jS1Xo1OWDj_52vbwGNgvQO2VzMc",
  "kid": "jS1Xo1OWDj_52vbwGNgvQO2VzMc"
}
{
  "aud": "https://storage.azure.com",
  "iss": "https://sts.windows.net/***/",
  "iat": 1655235016,
  "nbf": 1655235016,
  "exp": 1655238916,
  "aio": "E2ZgYIj79uqfw3k2Vxlh832LBXYoAwA=",
  "appid": "***",
  "appidacr": "2",
  "idp": "https://sts.windows.net/***/",
  "oid": "079fd90b-a298-480a-b951-257d0974f77e",
  "rh": "0.AREAjXSeXwsw8UiF9TqpbWJgy4GmBuTU86hCkLbCsClJevERAAA.",
  "sub": "079fd90b-a298-480a-b951-257d0974f77e",
  "tid": "***",
  "uti": "kSfa2jZd9kWPPJaBogoYAA",
  "ver": "1.0"
}
```

## Open issue - GitHub IDP doesn't understand my audience parameter

The audience handling of the GitHub IdP is tricky. When using the official `azure/login@v1` GitHub action, the action by default sets an audience of `"api://AzureADTokenExchange"`, which is exactly the same default value that Azure AD would expect for a Workload Identity Federation Scenario with GitHub.

So this would work:

```yaml
- name: 'Login via azure/login@v1'
  uses: azure/login@v1
  with:
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    allow-no-subscriptions: true
    environment: azurecloud
```

Looking at the source code of the action ([toolkit/oidc-utils.ts](https://github.com/actions/toolkit/blob/main/packages/core/src/oidc-utils.ts#L70-L73)), we see this: 

```typescript
static async getIDToken(audience?: string): Promise<string> {
  ...
  let id_token_url: string = OidcClient.getIDTokenUrl()
  if (audience) {
     const encodedAudience = encodeURIComponent(audience)
     id_token_url = `${id_token_url}&audience=${encodedAudience}`
  }
  ...
}
```

So the (working) `azure/login@v1` GitHub action just appends `&audience=api%3A%2F%2FAzureADTokenExchange` to the GitHub IDP URL (the `%3A%2F%2F` being the URL-encoded `://` from `"api://AzureADTokenExchange"`). 

But when [my bash script does this](https://github.com/chgeuer/azure-workload-identity-github/blob/main/action.sh#L7-L8):

```shell
encodedAudience="api%3A%2F%2FAzureADTokenExchange"
id_token_url="${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${encodedAudience}"
```

Unfortunately, the issued JWT token from GitHub still has an  `"aud": "https://github.com/chgeuer"`. So I decided to [do the same in the GitHub Action](https://github.com/chgeuer/azure-workload-identity-github/blob/main/.github/workflows/zip-and-upload.yml#L38-L45), by requiring the same `audience`:

```yaml
- name: 'Login via azure/login@v1'
  uses: azure/login@v1
  with:
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    allow-no-subscriptions: true
    environment: azurecloud
    audience: https://github.com/chgeuer
```

> Simply speaking, I want both the GitHub Action login with the `azure/login@v1` plugin, as well as my custom bash script, to use an audience of `"api://AzureADTokenExchange"`. With the GitHub action, this is easy, I just need to delete the `audience` flag in the YAML. However, I can't convince my bash scripto to convince the GitHub IdP go set that audience. 
