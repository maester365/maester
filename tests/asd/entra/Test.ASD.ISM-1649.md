Just-in-time administration is used for the administration of systems and their resources (ISM-1649, Essential Eight Maturity Level Three; supports ISM-1508).

A permanently assigned administrator role is a standing target: whoever holds the account holds the tenant, around the clock. With Privileged Identity Management, administrators are eligible for a role and activate it for a few hours when they need it, with MFA, justification and an audit trail. This check reads the active assignments of every directory role that Microsoft Entra marks as privileged and fails on each one that is permanent, that is, has no end date and was not made by an activation. Emergency access accounts named in the Maester configuration (`EmergencyAccessAccounts`) are left out.

#### Remediation action

1. In **Microsoft Entra admin center**, go to **Identity governance** > **[Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/CommonMenuBlade/~/quickStart)** > **Microsoft Entra roles** > **Assignments**.
2. For each permanent **Active** assignment listed below, choose **Remove**, then add the user again under **Eligible assignments**.
3. In **Settings** for each role, require **Microsoft Entra ID multifactor authentication** or a phishing-resistant authentication context on activation, set a maximum activation duration and require justification.
4. Keep your emergency access accounts permanently assigned, and list them in `maester-config.json` so Maester leaves them out.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Assign Microsoft Entra roles in Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-add-role-to-user)
* [Manage emergency access accounts in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)

<!--- Results --->
%TestResult%
