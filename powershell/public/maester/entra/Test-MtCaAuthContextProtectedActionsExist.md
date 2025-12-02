# Protected Actions Authentication Contexts should have Conditional Access policies

Protected Actions allow organizations to require step-up authentication for sensitive operations by
assigning Authentication Contexts to those actions. However, if an Authentication Context is not
referenced in any Conditional Access policy, the protected action is not effectively protected.

This test verifies that all Authentication Contexts used by Protected Actions are properly referenced
in at least one Conditional Access policy.

## How to fix

If this test fails, you need to create or update Conditional Access policies to reference the Authentication Contexts used by your Protected Actions:

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Go to **Protection** > **Conditional Access** > **Policies**
3. Create a new policy or edit an existing one
4. Under **Target resources** > **Authentication context**, select the Authentication Context(s) that need to be protected
5. Configure the appropriate grant controls (e.g., require MFA, require compliant device)
6. Enable the policy and save

Alternatively, if the Protected Action no longer needs step-up authentication, you can remove the Authentication Context assignment from the Protected Action:

1. Navigate to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Go to **Identity** > **Roles & admins** > **Protected actions (Preview)**
3. Select the Protected Action
4. Remove or update the Authentication Context assignment

## Learn more

- [Protected actions in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/role-based-access-control/protected-actions-overview)
- [Conditional Access: Target resources](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps)
- [Authentication context in Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps#authentication-context)

## Related links

- [Entra admin center - Conditional Access Policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Overview/fromNav/)
- [Entra admin center - Authentication contexts](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/AuthenticationContext)
- [Entra admin center - Protected actions](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/ProtectedActions)

<!--- Results --->
%TestResult%
