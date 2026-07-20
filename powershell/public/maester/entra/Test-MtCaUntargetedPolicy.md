Checks if any Conditional Access policy is not targeted to any resource.

It's possible to create and even enable a Conditional Access policy without selecting any target resources - cloud apps, user actions, or authentication context. The policy is accepted and appears in the portal like any other policy, but it applies to nothing and enforces nothing.

An untargeted policy gives a false sense of security: it looks like active protection, but has no effect. This commonly happens when a policy is created as a draft and never finished, or when an admin forgets to select a target before saving.

#### Remediation action:

1. Open the impacted policy in [Conditional Access policies](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies).
2. Under **Target resources**, configure at least one of: cloud apps, user actions, or authentication context.
3. If the policy is no longer needed, delete it instead of leaving it untargeted.

#### Related links

* [Conditional Access: Cloud apps, actions, and authentication context - Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-cloud-apps)

<!--- Results --->
%TestResult%
