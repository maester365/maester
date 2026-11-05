Privileged user accounts (excluding those explicitly authorised to access online services) are prevented from accessing the internet, email and web services (ISM-1175, Essential Eight Maturity Level One). This also supports ISM-0445: privileged human users are assigned a dedicated privileged user account to be used solely for duties requiring privileged access.

When the same account reads email, browses the web and administers the tenant, every phishing message and every malicious link reaches an administrator. A separate, unlicensed account for privileged duties keeps the role away from the inbox. ASD's assessment guide tests the email part of this control by listing the privileged accounts that have an email address.

This check lists the users with an active or eligible assignment to a directory role that Microsoft Entra marks as privileged, directly or through a role-assignable group, and fails for each one that has an enabled Exchange Online service plan that provides a mailbox (Plan 1, Plan 2, Kiosk or Essentials; the `MailboxServicePlanId` parameter). The Exchange Foundation plan that comes with Entra ID, Intune and Defender licences creates no mailbox and does not count. Emergency access accounts named in the Maester configuration (`EmergencyAccessAccounts`) are left out. This is a check of service plans, not proof that a mailbox exists or that the account is dedicated to privileged duties. It does not detect all mailboxes or verify access to other email, the internet or web services; assess those separately.

[MT.1028](https://maester.dev/docs/tests/MT.1028) looks for mailboxes on permanent Control Plane assignments only. ASD's test covers every privileged account, eligible ones included, so this check reads them itself.

#### Remediation action

1. For each administrator listed below, create a cloud-only account for privileged work, for example `adm-firstname.lastname@yourtenant.onmicrosoft.com`, and do not assign it a licence that includes Exchange Online.
2. In **Microsoft Entra admin center**, open **[Roles & administrators](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles)** (or Privileged Identity Management) and move the role from the everyday account to the new one.
3. Where an administrator must receive mail for a role, forward it to the everyday account rather than keeping a mailbox on the privileged one.

#### Related links

* [Essential Eight maturity model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Essential Eight assessment process guide](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-assessment-process-guide)
* [ISM Guidelines for system access: Privileged access to systems](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-access)
* [Securing privileged access: separate user accounts for administrators](https://learn.microsoft.com/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)

<!--- Results --->
%TestResult%
