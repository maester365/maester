Microsoft Entra recommendations help you improve the security posture of your tenant. Maester checks every recommendation that Entra reports for the tenant and creates one result per recommendation (MT.1024.&lt;recommendation&gt;). The severity of each result is the recommendation's priority.

A recommendation passes when Entra reports it as completed. Recommendations that an administrator has marked as **Dismissed** are skipped. For the sign-in risk and user risk recommendations, a recommendation whose only impacted resources are the configured emergency access (break-glass) accounts passes.

#### Remediation action

Open the recommendation in the Microsoft Entra admin center and follow its action steps. If a recommendation does not apply to your tenant, mark it as **Dismissed**.

#### Related links

- [Microsoft Entra recommendations](https://learn.microsoft.com/entra/identity/monitoring-health/overview-recommendations)
- [Recommendations - Microsoft Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/RecommendationsListView.ReactView)

<!--- Results --->
%TestResult%
