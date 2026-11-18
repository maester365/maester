No enabled user account has gone 35 days or more without signing in. (DISA Microsoft Intune MDM Service Desktop STIG, V-267309, CAT II).

Intune administrators and users sign in with Microsoft Entra ID, so DISA's Intune rule for inactive accounts is checked in Entra ID. A dormant account's stolen password is unlikely to be noticed.

The Entra ID STIG has the same rule and audit script, so this test runs [DISA.V-270204](https://maester.dev/docs/tests/DISA.V-270204) with 35 days.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **ID Governance** > **[Access reviews](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/fromNav/Identity)** and create a recurring review of inactive users with **Days inactive** set to **35**.
2. Let the review disable accounts that nobody vouches for, or run a scheduled automation that disables the accounts this test lists.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267309](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267309)
* [How to manage inactive user accounts](https://learn.microsoft.com/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)

<!--- Results --->
%TestResult%
