Only administrators and users with the Guest Inviter role can invite guests to the tenant, or no one can.

A guest account is a way into your directory and, by default, can read basic information about users and groups. If every member or even every guest can invite more guests, accounts appear without review and access spreads without an owner.

Limiting invitations to administrators and the Guest Inviter role keeps creation of external accounts with people who understand the risk. Grant the Guest Inviter role to the teams that manage partner access, or use entitlement management for self-service requests with approval.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **External Identities** > [**External collaboration settings**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings/menuId/Settings).
3. Under **Guest invite settings**, select **Only users assigned to specific admin roles can invite guest users** (or **No one in the organization can invite guest users including admins**).
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - External collaboration settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings/menuId/Settings)
* [Configure external collaboration settings](https://learn.microsoft.com/entra/external-id/external-collaboration-settings-configure)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.6.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
