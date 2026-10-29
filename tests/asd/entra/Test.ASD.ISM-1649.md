Just-in-time administration is used for the administration of systems and their resources (ISM-1649, Essential Eight Maturity Level Three).

A standing administrator role is a target around the clock: whoever holds the account holds the tenant. With Privileged Identity Management, administrators are eligible for a role and activate it for a few hours when they need it, with MFA, a justification and an audit trail.

ASD's assessment guide describes just-in-time administration as granting privileged users access "immediately before that access is required and for only as long as it is required", and the ASD Blueprint for Secure Cloud makes every Microsoft Entra role an eligible assignment, with permanent active assignments only for break glass accounts. This test runs the same check as [CIS.M365.5.3.1](https://maester.dev/docs/tests/CIS.M365.5.3.1): every active assignment of a user or group to a role that Microsoft Entra marks as privileged must have been made by an activation. A time-bound active assignment fails as well, because it is standing access for its whole duration. A service principal passes when its assignment has an end date. Permanent Global Administrator assignments are allowed only for the emergency access accounts named in the Maester configuration (`EmergencyAccessAccounts`), up to two. See [Emergency access accounts](https://maester.dev/docs/configuration/emergency-access-accounts).

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **ID Governance** > **[Privileged Identity Management](https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/CommonMenuBlade/~/quickStart)** > **Microsoft Entra roles** > **Assignments**.
2. For each **Active** assignment listed below, choose **Remove**, then add the user or group again under **Eligible assignments**.
3. In **Settings** for each role, require multifactor authentication on activation, set a maximum activation duration and require a justification.
4. Keep your emergency access accounts permanently assigned, and list them in `maester-config.json` so Maester leaves them out.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Essential Eight assessment process guide](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-assessment-process-guide)
* [ASD Blueprint for Secure Cloud: Roles](https://blueprint.asd.gov.au/design/platform/identity/roles/)
* [Assign Microsoft Entra roles in Privileged Identity Management](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-add-role-to-user)

<!--- Results --->
%TestResult%
