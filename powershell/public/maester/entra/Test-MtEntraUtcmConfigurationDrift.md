Checks for active configuration drifts reported by Microsoft Entra Unified Tenant Configuration Management (UTCM).

Microsoft Entra UTCM continuously monitors managed tenant configurations and raises a drift when a resource deviates from its expected baseline value. Active drifts indicate that a configuration change has occurred outside the managed policy and the tenant is no longer in the desired state. Remediating drifts promptly ensures the tenant remains compliant with your organisation's security baseline.

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a Global Administrator or Privileged Role Administrator.
2. Browse to **Settings** > **[Configuration management](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/ConfigurationManagement)**.
3. Review the list of active configuration drifts shown in the table below.
4. For each active drift, restore the resource to the expected value or update the UTCM policy baseline to reflect the intended configuration.

#### Related links

* [Entra admin center - Configuration management](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/ConfigurationManagement)
* [Microsoft Graph API - List configurationDrifts](https://learn.microsoft.com/en-us/graph/api/configurationmanagement-list-configurationdrifts?view=graph-rest-beta)
* [Unified Tenant Configuration Management overview](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/overview-unified-tenant-configuration-management)

<!--- Results --->
%TestResult%
