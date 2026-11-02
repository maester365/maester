---
# A partial that guides import; also served as a page (noindex) for links to it.
title: Create a client secret
---

### Create a client secret

:::caution
Client secret authentication is not recommended for long-term automation, and we recommend using workload identity federation when possible. Client secrets expire, require manual rotation and manual updates in your pipeline/repository variables.
:::

- Select **Certificates & secrets** > **Client secrets** > **New client secret**
- Enter a description for the secret (e.g. `Maester DevOps Secret`)
- Select **Add**
- Copy the value of the secret, we will use this value in the Azure Pipeline
