Privileged access to systems and their resources is disabled after 45 days of inactivity (ISM-1648, Essential Eight Maturity Level Two).

An administrator account nobody uses is an account nobody watches. Its password ages, its owner may have moved on, and a sign-in on it is unlikely to be questioned. This check lists the users with an active or eligible assignment to a directory role that Microsoft Entra marks as privileged and reads the last sign-in of each. An enabled account fails when its most recent interactive or non-interactive sign-in is older than 45 days (the `InactiveDays` parameter), or when it has never signed in and was created before that. Emergency access accounts named in the Maester configuration (`EmergencyAccessAccounts`) are left out, because they are meant to stay unused.

#### Remediation action

1. In **Microsoft Entra admin center**, open **[Users](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers)** and check each account listed below with its owner.
2. Remove the privileged role in **Roles & administrators**, or disable the account under **Edit properties** > **Account enabled**.
3. Turn on the **Stale sign-ins** alert in **Privileged Identity Management** > **Alerts** > **Settings**, and configure an access review of the privileged roles so inactive access is removed before this check fails again.

#### Related links

* [Essential Eight Maturity Model](https://www.cyber.gov.au/business-government/asds-cyber-security-frameworks/essential-eight/essential-eight-maturity-model)
* [Security alerts for Microsoft Entra roles in PIM](https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-configure-security-alerts)
* [How to manage inactive user accounts](https://learn.microsoft.com/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)

<!--- Results --->
%TestResult%
