Inventories disabled GPO links, including the GPO and linked container for each disabled link. A disabled link can be intentional, but can also leave security settings unapplied. The count is of links, not distinct GPOs.

#### Control Type

**Operational**

#### Security Recommendation

Review disabled links for temporary troubleshooting, drift or intentionally retired policy; document exceptions and verify coverage before re-enabling a link.

#### How the Test Works

The check parses collected `gPLink` values, reports disabled link entries and their containers, and counts links rather than unique GPOs. Link status alone does not prove effective policy application.

#### Related Tests

- **AD-GPOL-02 — Disabled GPO link count should be retrievable** — `Test-MtCheckADGPOL02` — Inventories disabled links.
- **AD-GPOL-04 — Enforced GPO link count should be retrievable** — `Test-MtAdGpoEnforcedCount` — Inventories enforced links separately.

#### Remediation action

1. In **Group Policy Management**, navigate to the listed organizational unit, domain or site and inspect its linked GPOs.
2. Re-enable links that should apply, remove obsolete links, and document intentional exceptions. Confirm the effect of inherited policies before changing links.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
