Microsoft-managed Conditional Access policies should be reviewed and set to On or Off, not left in report-only mode.

Microsoft creates Microsoft-managed Conditional Access policies in your tenant to roll out protections such as MFA for administrators, blocking legacy authentication and risk remediation for high-risk users. Each policy starts in report-only mode. If no administrator sets it to On or Off, Microsoft turns it on automatically no less than 30 days after it was created, sometimes sooner. Microsoft sends a Message center post and an email about two weeks before.

A policy that is turned on without review can block or prompt users you did not plan for. For example, a user who must remediate a high risk but never registered for MFA cannot complete remediation and is blocked until an administrator helps. Deciding yourself lets you check the policy's impact first, exclude your emergency access accounts and tell your users what to expect.

This check finds Microsoft-managed policies by the `Microsoft-managed:` name prefix. Administrators cannot rename a Microsoft-managed policy, so the prefix is reliable for the policies Microsoft creates. A custom policy that used the same prefix would also be listed. It lists each one still in report-only mode with the date it was created, the date from which Microsoft usually turns it on (30 days after it was created; Microsoft can act sooner, so check the Message center post) and its grant controls. The emergency access exclusions of every policy are checked by MT.1005.

#### Remediation action

1. In **Entra ID**, navigate to **Conditional Access** > **[Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies)**.
2. Open each Microsoft-managed policy listed in the results.
3. Review its impact in the policy impact view, or on the **Report-only** tab of sign-in log entries, which shows the users the policy would have affected.
4. Exclude your emergency access accounts if they are not excluded already.
5. Set **Enable policy** to **On** to enforce it now, or to **Off** if you already have an equivalent policy or do not want it.
6. Click **Save**.

#### Related links

* [Microsoft-managed Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/managed-policies)
* [Analyze Conditional Access policy impact](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-report-only)
* [Manage emergency access accounts](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)

<!--- Results --->
%TestResult%
