All users who utilize Entra ID P1 features should be licensed for Entra ID P1.

This test uses the Entra ID premium licence utilization insights in Microsoft Graph to compare the number of users covered by Conditional Access with the number of users entitled to an Entra ID P1 licence. The test fails when more users utilize P1 features than are licensed.

#### Remediation action

Assign Entra ID P1 licences to every user who is in scope of Conditional Access policies, or reduce the scope of those policies to licensed users.

To see licence counts and feature usage, open [License usage](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/LicensesMenuBlade/~/LicenseUtilization) in the Microsoft Entra admin center (**Billing** > **Licenses**).

#### Related links

* [Microsoft Entra license usage insights - Microsoft Learn](https://learn.microsoft.com/entra/fundamentals/concept-license-usage-insights)
* [Introducing Microsoft Entra license utilization insights - Microsoft Community Hub](https://techcommunity.microsoft.com/t5/microsoft-entra-blog/introducing-microsoft-entra-license-utilization-insights/ba-p/3796393)
* [Microsoft Entra licensing - Microsoft Learn](https://learn.microsoft.com/entra/fundamentals/licensing)

<!--- Results --->
%TestResult%
