Inventories Group Policy objects with deny access entries. Deny ACEs override allow entries, but can also be intentional. Policies with unreadable security descriptors are listed as not evaluated.

#### Why This Test Matters

Deny entries can prevent intended principals from accessing or applying policy. Review their scope and purpose alongside allow entries and inheritance rather than treating every deny as a configuration failure.

#### Control Type

**Detective**

#### Security Recommendation

Review deny ACEs in the context of the policy's security filtering and inheritance; remove only those that interfere with intended access.

#### How the Test Works

The check counts collected GPO reports with `HasDenyAce` true and shows affected policies. Unreadable permission sets are not counted as clean.

#### Related Tests

- **AD-DACL-05 — Deny ACEs and affected identities should be investigated** — `Test-MtAdDaclDenyAceCount` — Reviews deny ACEs in the wider directory.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPOs under **Delegation** > **Advanced**.
2. Confirm each deny entry is required and does not prevent intended policy application; remove unintended entries after reviewing inheritance and scope.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
