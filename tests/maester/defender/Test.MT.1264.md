Microsoft Secure Score improvement actions should be completed.

Microsoft Secure Score measures a tenant's security posture as points earned across a list of recommended improvement actions, such as requiring multifactor authentication for administrators or turning on Safe Links. Maester reads the tenant's latest Secure Score and creates one result per improvement action the tenant is scored on (MT.1264.&lt;control name&gt;). Improvement actions that are not part of the tenant's score are not reported.

These results are not native Maester checks. The improvement actions, their points and the status details come from Microsoft Secure Score. A change made in the tenant usually takes 24 to 48 hours to show in Secure Score, and some Microsoft Teams and Microsoft Entra improvement actions refresh less often.

An improvement action passes when it has all of its points and fails when it has fewer, showing the points earned. The severity of each result comes from the action's maximum points: 8 or more is High, 4 to 7 is Medium, and below 4 is Low. Improvement actions that an administrator has set to **Risk accepted**, **Resolved through third party** or **Resolved through alternate mitigation** in the Microsoft Defender portal, or that carry the older **Reviewed** state, are skipped, with the status, who set it and their note, so decisions already made in the portal are respected. Improvement actions set to **Planned** are still checked, since the work is not done yet.

Some improvement actions, such as multifactor authentication for administrators, are also Entra recommendations reported by MT.1024. Maester matches them by name against the tenant's Entra recommendations, and those results note the overlap.

The check needs the Microsoft Graph permission `SecurityEvents.Read.All`, which Maester does not request by default. Without it the check is skipped. Connect with `Connect-Maester -IncludePreview`, or grant the permission to the app registration that runs Maester.

#### Remediation action

Open each failed improvement action in the [Microsoft Secure Score](https://security.microsoft.com/securescore) page of the Microsoft Defender portal and follow its implementation steps. If an improvement action does not apply to your tenant, or is already covered by another product, set its status to **Risk accepted**, **Resolved through third party** or **Resolved through alternate mitigation** in the Defender portal; Maester then skips it on the next run. Improvement actions in the Device category can't be given a status there; Microsoft directs you to the matching Defender Vulnerability Management recommendation instead.

#### Related links

- [Microsoft Secure Score](https://learn.microsoft.com/defender-xdr/microsoft-secure-score)
- [Assess your security posture with Microsoft Secure Score](https://learn.microsoft.com/defender-xdr/microsoft-secure-score-improvement-actions)
- [Microsoft Secure Score - Microsoft Defender portal](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%
