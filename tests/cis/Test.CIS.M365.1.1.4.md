1.1.4 (L1) Ensure administrative accounts use licenses with a reduced application footprint

Active administrative accounts should be unlicensed or use licenses that do not provide access to user-facing applications. By default, this check accepts Microsoft Entra ID P1 (`AAD_PREMIUM`) and P2 (`AAD_PREMIUM_P2`). Other license SKU part numbers are reported unless they are added to the `AllowedLicenseSkuPartNumbers` parameter after confirming that they do not enable applications such as email, Teams, or SharePoint.

The check evaluates permanent assignments to roles whose names contain `Administrator` and the `Global Reader` role. Eligible assignments managed through Privileged Identity Management are not evaluated. The Microsoft Graph license details endpoint requires delegated authentication.

Reducing the application footprint on privileged identities limits their exposure to phishing and malicious content in collaboration services. If administrators need those applications for daily work, use separate non-privileged accounts.

#### Remediation action

1. In the [Microsoft 365 admin center](https://admin.microsoft.com), go to **Users** > **Active users**.
2. For each listed account, open **Licenses and apps** and remove licenses outside the approved identity-only list. If a license is assigned through a group, update the group's license assignment.
3. Keep only Microsoft Entra ID P1, P2, or another verified identity-only license on the administrative account. If the administrator needs email or collaboration apps, assign those licenses to a separate non-privileged account.
4. Configure eligible administrative roles through Privileged Identity Management and require approval for activation. Route tenant administrator alerts to a monitored security or operations mailbox.

#### Related links

* [Assign licenses to users in the Microsoft 365 admin center](https://learn.microsoft.com/microsoft-365/admin/manage/assign-licenses-to-users?view=o365-worldwide)
* [Microsoft Entra ID licenses](https://learn.microsoft.com/entra/fundamentals/what-is-entra#what-are-the-microsoft-entra-id-licenses)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%