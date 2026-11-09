A Microsoft Entra diagnostic setting sends the sign-in, audit and risk logs to a Log Analytics workspace or another log store. (DISA Microsoft Entra ID STIG, V-270227, CAT II).

Sign-in and audit logs kept only in Microsoft Entra ID are retained for 30 days at most and are not correlated with other sources. Sending them to a SIEM keeps them and lets the security team alert on them.

This test runs the same check as [CISA.MS.AAD.4.1](https://maester.dev/docs/tests/CISA.MS.AAD.4.1) with DISA's list of categories (`RequiredLogCategory`): SignInLogs, AuditLogs, ServicePrincipalSignInLogs, ManagedIdentitySignInLogs, UserRiskEvents, RiskyUsers, RiskyServicePrincipals and ServicePrincipalRiskEvents. CISA asks for four more. The STIG also asks you to confirm in Microsoft Sentinel, or your SIEM, that logs arrived within the last hour; check that by hand.

#### Remediation action

1. In the [Microsoft Entra admin center](https://entra.microsoft.com), go to **Entra ID** > **Monitoring & health** > **[Diagnostic settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DiagnosticSettingsMenuBlade/~/General)**.
2. Select **Add diagnostic setting**, or **Edit setting** on an existing one.
3. Select the eight log categories listed above and send them to a Log Analytics workspace (or another destination your SIEM reads).
4. Select **Save**.

#### Related links

* [DISA Microsoft Entra ID STIG: V-270227](https://cyber.trackr.live/stig/Entra_ID/1/2/V-270227)
* [Configure Microsoft Entra diagnostic settings for activity logs](https://learn.microsoft.com/entra/identity/monitoring-health/howto-configure-diagnostic-settings)

<!--- Results --->
%TestResult%
