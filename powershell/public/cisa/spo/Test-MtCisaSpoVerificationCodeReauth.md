Reauthentication days for people who use a verification code SHALL be set to 30 days or less.

Rationale: When external users access shared content using a verification code, limiting the reauthentication period to 30 days or less ensures that access is regularly revalidated. This reduces the risk of prolonged unauthorized access through expired or compromised verification codes.

This policy is only applicable if the external sharing slider on the admin page is set to Anyone or New and existing guests.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Check **People who use a verification code must reauthenticate after this many days** and set the value to **30** or less.
5. Select **Save**.

#### Related links

* [CISA 3 Anyone Links - MS.SHAREPOINT.3.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint33v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%