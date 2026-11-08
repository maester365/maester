Checks that every GPO has an allow entry for the Apply Group Policy right. A policy without application rights cannot deliver its intended settings through that right. This is a policy-health check, not a calculation of effective permissions for every user or computer.

This check requires Windows for security-descriptor parsing; the engine skips it on Linux and macOS. On Windows, it fails when an application entry is absent and errors when permissions are unreadable. Intentionally unused policies require review before granting access; archive or remove them if they are no longer needed.

#### Why This Test Matters

Apply Group Policy permission governs whether a recipient can apply the GPO. Missing application permission can prevent intended settings from reaching users or computers even when the GPO is linked.

#### Control Type

**Operational**

#### Security Recommendation

Confirm the intended policy recipients, and grant Apply Group Policy only where needed; document deliberately unused GPOs.

#### How the Test Works

The check examines GPO permissions for an allow ACE granting Apply Group Policy. It identifies absent entries without claiming to calculate every target's effective policy; unreadable permissions cause Error.

#### Related Tests

- **AD-GPOREP-03 — GPOs should permit Authenticated Users where required** — `Test-MtAdGpoNoAuthenticatedUsersCount` — Reviews authenticated-user permissions.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPO's **Scope** > **Security Filtering** and **Delegation** > **Advanced** settings.
2. Grant Apply Group Policy only to principals that should receive the policy. Document intentionally unused policies and investigate unreadable permissions.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
