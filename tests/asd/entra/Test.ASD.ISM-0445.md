Privileged users are assigned a dedicated privileged user account to be used solely for duties requiring privileged access (ISM-0445, Essential Eight Maturity Level One), and privileged user accounts are prevented from accessing the internet, email and web services (ISM-1175).

When the same account reads email, browses the web and administers the tenant, every phishing message and every malicious link reaches an administrator. A separate, unlicensed account for privileged duties keeps the role away from the inbox. This check lists the users with an active or eligible assignment to a directory role that Microsoft Entra marks as privileged and fails for each one that has an enabled Exchange Online service plan that provides a mailbox (Plan 1, Plan 2, Kiosk or Essentials; the `MailboxServicePlanId` parameter). The Exchange Foundation plan that comes with Entra ID, Intune and Defender licences creates no mailbox and does not count. Emergency access accounts named in the Maester configuration (`EmergencyAccessAccounts`) are left out.

#### Remediation action

1. For each administrator listed below, create a cloud-only account for privileged work, for example `adm-firstname.lastname@yourtenant.onmicrosoft.com`, and do not assign it a licence that includes Exchange Online.
2. In **Microsoft Entra admin center**, open **[Roles & administrators](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RolesManagementMenuBlade/~/AllRoles)** (or Privileged Identity Management) and move the role from the everyday account to the new one.
3. Where an administrator must receive mail for a role, forward it to the everyday account rather than keeping a mailbox on the privileged one.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [ISM Guidelines for system access: Privileged access to systems](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/ism/cyber-security-guidelines/guidelines-system-access)
* [Securing privileged access: separate user accounts for administrators](https://learn.microsoft.com/entra/identity/role-based-access-control/security-planning#ensure-separate-user-accounts-and-mail-forwarding-for-global-administrator-accounts)

<!--- Results --->
%TestResult%
