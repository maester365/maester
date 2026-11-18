No enabled user account in Microsoft Entra ID has gone 35 days or more without signing in (DISA Microsoft Entra ID STIG, V-270204, CAT II).

Accounts that nobody uses are a gift to an attacker: a stolen or guessed password for a dormant account is unlikely to be noticed, because its owner never sees the sign-in prompts, alerts or mailbox changes. DISA asks that accounts are disabled after 35 days of inactivity.

The check reads every enabled user, members and guests, as the STIG's audit procedure does, and lists those whose last interactive sign-in is older than 35 days (`MaximumInactiveDays`), or who never signed in and were created more than 35 days ago. Microsoft Entra ID does not disable inactive accounts by itself, so the fix is a recurring process. [ASD.ISM-1648](https://maester.dev/docs/tests/ASD.ISM-1648) checks the same for privileged users with a 45-day limit.

Accounts that must stay enabled without signing in, such as emergency access accounts, need the exception documented with your authorizing official; leave them enabled and expect them in this list.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **ID Governance** > **[Access reviews](https://entra.microsoft.com/#view/Microsoft_AAD_ERM/DashboardBlade/~/Controls/fromNav/Identity)** and create a review of inactive users (**Inactive users (on tenant level) only**, with **Days inactive** set to **35**).
2. Set the review to recur, and set **If reviewers don't respond** to **Remove access** or use the auto-apply option so that accounts nobody vouches for are disabled.
3. Alternatively, run a scheduled automation that disables the accounts this test lists.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270204](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270204)
* [How to manage inactive user accounts](https://learn.microsoft.com/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)
* [Create an access review of groups and applications](https://learn.microsoft.com/entra/id-governance/create-access-review)

<!--- Results --->
%TestResult%
