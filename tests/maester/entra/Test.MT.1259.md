Checks if Conditional Access baseline scopes enforcement is enabled, either tenant-wide or through a custom placeholder application.

Baseline scopes are the OpenID Connect scopes (`openid`, `profile`, `email`, `offline_access`) and the basic directory scopes (`User.Read`, `User.Read.All`, `User.ReadBasic.All`, `People.Read`, `People.Read.All`, `GroupMember.Read.All`, `Member.Read.Hidden`). Historically, a sign-in that requested only these scopes was not evaluated by an **All resources** Conditional Access policy as soon as that policy had a single resource exclusion. An attacker with a stolen password could use a public client such as Azure CLI, which requests only `User.Read`, to sign in and access directory data without meeting the MFA or device requirements that the policy applies to every other resource.

With the improved enforcement model, these sign-ins are evaluated as directory access against **Windows Azure Active Directory** and are subject to your Conditional Access policies even when the policy has exclusions. Microsoft is rolling the model out to all tenants and recommends enabling it explicitly.

The tenant's selection is stored in the [Baseline scopes settings](https://aka.ms/BaselineScopesSettingsUX):

* **Enable enforcement** evaluates baseline scopes against Windows Azure Active Directory. The check passes.
* **Customize behavior** evaluates baseline scopes against a custom placeholder application. Enforcement applies everywhere, except in policies that exclude the placeholder application. The check asks for investigation:
  * If enabled policies that target All resources exclude the placeholder application, it lists them. Review whether each still needs the legacy behavior and its resource exclusions.
  * If no such policy excludes the placeholder application, the customization has no effect. Review whether Customize behavior is needed at all, or whether **Enable enforcement** can be used as the stronger default.
* **Disable enforcement** keeps the legacy behavior for every policy. The check fails and lists the enabled policies that target All resources and have a resource exclusion, because these are the policies that don't evaluate baseline scope sign-ins.
* No selection: this is the expected state once Microsoft's staged rollout has reached the tenant, because enforcement then becomes the default and the Baseline scopes settings show no selection. Whether the rollout has reached the tenant cannot be confirmed, so the check asks for investigation and recommends making the choice explicit.

Whatever the selection, the check fails when an enabled Conditional Access policy excludes **Windows Azure Active Directory** (`00000002-0000-0000-c000-000000000000`), although it includes it, either through **All resources** or directly. It can look like a quick fix, because sign-in logs show this resource as the audience of a blocked baseline scope sign-in. But Windows Azure Active Directory is a real resource, the directory API itself, while a placeholder application only receives the baseline scope requests that Microsoft reroutes to it. With certain public client IDs that are allowed to request this resource, an attacker with valid credentials can obtain a directory token and access users, groups, devices, applications and role memberships without meeting the policy's requirements. This is the gap the enforcement change was built to close, and a wider one than the legacy behavior that a placeholder application retains.

An enabled policy that excludes Windows Azure Active Directory but does not include it, for example one that targets only Office 365, is listed for investigation. The exclusion has no effect today, but it opens the gap as soon as the policy's scope is widened to All resources.

#### Remediation action

1. Review the Conditional Access policies that target **All resources** and have at least one resource exclusion. For each excluded application, check whether the exclusion is still needed and remove it if not.
2. For an excluded application that stops working after the enforcement change, the preferred fix is that the application requests only OpenID Connect scopes (`openid`, `profile`, `email`, `offline_access`). The application exclusion is then enough again. Ask the owner or vendor of the application for this change. This does not help public clients such as desktop applications, which are evaluated even when they request only OpenID Connect scopes.
3. Sign in to the Microsoft Entra admin center as at least a Conditional Access Administrator and open the [Baseline scopes settings](https://aka.ms/BaselineScopesSettingsUX). This direct link is required to view the settings. Note the current selection before you change it.
4. If none of your policies needs the legacy behavior, select **Enable enforcement**, then **Save**, and confirm. This is the recommended setting.
5. If specific policies must retain the legacy behavior until the application is changed, select **Customize behavior** instead:
   1. Register a single-tenant placeholder application. Microsoft requires no further configuration. As recommended hardening, remove all of its API permissions, including the default `User.Read` delegated permission, because the placeholder never calls an API.
   2. In each affected policy, add the placeholder application to the target resource exclusions **in addition to** the applications that are already excluded there. Keep the existing exclusions: the application that stopped working is excluded to grant it access, and the placeholder application is excluded so that its baseline scope sign-ins are no longer evaluated against that policy. Removing either exclusion breaks the scenario.
   3. In the Baseline scopes settings, select **Customize behavior**, select the placeholder application and **Save**.
   4. Treat this as a temporary exception: document the placeholder application, the policies that exclude it, the applications it covers, an owner and the request to the vendor, and review it regularly.
6. Do not exclude **Windows Azure Active Directory** from a Conditional Access policy instead of using a placeholder application. If a policy already excludes it, replace that exclusion with a placeholder application as described in step 5. If the policy does not include Windows Azure Active Directory at all, remove the exclusion.

#### Related links

* [Improved enforcement for All resources policies with resource exclusions - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/concept-enforcement-resource-exclusions)
* [New Conditional Access behavior when an All resources policy has a resource exclusion - Microsoft Learn](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-cloud-apps#new-conditional-access-behavior-when-an-all-resources-policy-has-a-resource-exclusion)
* [Baseline scopes settings - Microsoft Entra admin center](https://aka.ms/BaselineScopesSettingsUX)
* [Bypassing Conditional Access policies that have a resource exclusion - Dirk-jan Mollema](https://dirkjanm.io/bypassing-conditional-access-with-resource-exclusion/)

<!--- Results --->
%TestResult%
