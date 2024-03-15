---
sidebar_label: Azure DevOps
sidebar_position: 1
title: Azure DevOps
---

# <IIcon icon="vscode-icons:file-type-azurepipelines" height="48" /> Configure Maester in Azure DevOps

## Set up the Maester repository in Azure DevOps

### Setting up Maester in a new Azure DevOps project

- If this is your first time using Azure DevOps, follow the steps in the [Azure DevOps - Create an organization](https://learn.microsoft.com/azure/devops/organizations/accounts/create-organization) to create an organization.
- Create a new project for Maester in Azure DevOps by following the steps in the [Azure DevOps - Create a project](https://learn.microsoft.com/azure/devops/organizations/projects/create-project) guide.
- Select **Repos** from the left-hand menu
- Click the **Import** button in the **Import a repository** section
- Enter the URL of the Maester repository `https://github.com/maester365/maester-tests.git`
- Click **Import** to import the repository into your Azure DevOps project.

### Setting up Maester in an existing Azure DevOps repository

- If you would like to add Maester to an existing Azure DevOps repository you can clone `https://github.com/maester365/maester-tests.git` and copy the `tests` folder into your repository.

## Using a Service Principal and secret
