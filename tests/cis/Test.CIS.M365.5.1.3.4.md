Regular users cannot create Microsoft 365 groups, so group creation is limited to approved users.

Each Microsoft 365 group can come with a Teams team, a SharePoint site and a mailbox. Uncontrolled creation leads to sites with unclear owners, unmanaged guest access and data that is hard to find in an investigation.

The directory setting object Group.Unified must exist and have group creation turned off. If you turn it off, define who can create groups, for example a security group of approved creators, or route requests through an approval process.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Groups** > [**General**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General).
3. Set **Users can create Microsoft 365 groups in Azure portals, API or PowerShell** to **No**.
4. Select **Save**.
5. Optionally allow a specific group to create groups with the PowerShell steps in the Microsoft Learn article below.

#### Related links

* [Microsoft Entra admin center - Group general settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General)
* [Manage who can create Microsoft 365 Groups](https://learn.microsoft.com/microsoft-365/solutions/manage-creation-of-groups)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.3.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
