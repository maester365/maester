Should have at least one user flow configured

A tenant with no Entra External ID user flows configured has no self-service
sign-up/sign-in experience set up for external users, meaning CIAM-related
checks in this tenant have nothing to evaluate and external users have no
way to sign up or sign in. This test fails when zero user flows exist.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CustomAuthenticationExtensionsMenuBlade/~/UserFlows), open **External Identities > User flows**.
2. Create a user flow for self-service sign-up and sign-in.

#### Related links

- [Create a sign-up and sign-in user flow](https://learn.microsoft.com/entra/external-id/customers/how-to-user-flow-sign-up-sign-in-customers)

<!--- Results --->
%TestResult%
