Microsoft Entra external collaboration settings allow invitations only to an approved list of domains.

If any user can invite guests from any domain, data can be shared with, and accounts created for, organisations that you have never vetted. An allow list turns external collaboration into a decision your organisation makes, and a compromised account cannot be used to add arbitrary outside accounts.

A deny list is not accepted because it covers only the domains that you already know about.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **External Identities** > [**External collaboration settings**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings/menuId/Settings).
3. Under **Collaboration restrictions**, select **Allow invitations only to the specified domains (most restrictive)**.
4. Add the partner domains to the list.
5. Select **Save**.

#### Related links

* [Microsoft Entra admin center - External collaboration settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CompanyRelationshipsMenuBlade/~/Settings/menuId/Settings)
* [Allow or block invitations to B2B users from specific organizations](https://learn.microsoft.com/entra/external-id/allow-deny-list)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.6.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
