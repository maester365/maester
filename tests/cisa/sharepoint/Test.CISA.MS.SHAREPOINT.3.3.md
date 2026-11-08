Reauthentication days for people who use a verification code SHALL be set to 30 days or less.

Rationale: Requiring periodic reauthentication via verification codes ensures that external users maintain valid access and reduces the risk of prolonged unauthorized access through stale sessions.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Under Advanced settings, check **Guests must sign in using the same account to which sharing invitations are sent**.
4. Check **People who use a verification code must reauthenticate after this many days** and set to **30** days or less.
5. Select Save.

#### Related links

* [CISA 3 Verification Code Reauth - MS.SHAREPOINT.3.3v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint33v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%
