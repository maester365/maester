Microsoft Entra recommendations help you improve the security posture of your tenant. Maester checks every recommendation that Entra reports for the tenant and creates one result per recommendation (MT.1024.&lt;recommendation&gt;). The severity of each result is the recommendation's priority.

These results are not native Maester checks. The recommendation, its priority, its status and its list of impacted users or apps all come from Entra, so Maester cannot change which accounts a recommendation counts. If a recommendation lists accounts you do not expect, such as disabled, shared or room accounts, that is a question for Microsoft, raised through the feedback option on the recommendation in the Entra admin center.

A recommendation passes when Entra reports it as completed. Recommendations that an administrator has marked as **Dismissed** are skipped. For the sign-in risk and user risk recommendations, a recommendation whose only impacted resources are the configured emergency access (break-glass) accounts passes.

#### Remediation action

Open the recommendation in the Microsoft Entra admin center and follow its action steps. If a recommendation does not apply to your tenant, mark it as **Dismissed** in the Entra admin center; Maester then skips it on the next run.

#### Related links

- [Microsoft Entra recommendations](https://learn.microsoft.com/entra/identity/monitoring-health/overview-recommendations)
- [Recommendations - Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationsListView.ReactView)

<!--- Results --->
%TestResult%
