OU modification age inventory.

The default review threshold is five calendar years since last modification, configurable with MaximumAgeYears. Modification age is not evidence of use, deactivation or account activity.

An old OU modification timestamp is a prompt to inspect its purpose, delegation and policy links, not proof that the OU is unused or abandoned. A frequently used OU may have unchanged attributes for years.

#### Control Type

**Detective**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Check OU contents, ACLs, GPO links and the responsible owner before deciding whether cleanup is warranted. Document useful but rarely modified OUs rather than deleting them based on age alone.

#### How the Test Works

Compares visible OU last-modification timestamps with the configurable `MaximumAgeYears` calendar-year review threshold and reports matching OUs. It does not measure access, child activity or last use.

#### Related Tests

- **AD-OU-04 — OUs with no selected visible direct children inventory** — `Test-MtAdOuEmptyCount` — Inventories OUs without selected visible children.
- **AD-GRP-03 — Groups should be modified within the configured age** — `Test-MtAdGroupStaleCount` — Reviews group modification age separately.

#### Related links

* [Microsoft Learn: Reviewing OU Design Concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/reviewing-ou-design-concepts)

<!--- Results --->
%TestResult%
