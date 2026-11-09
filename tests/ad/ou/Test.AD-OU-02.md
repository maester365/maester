Root-level OU inventory. The domain's OU hierarchy shapes administrative delegation and GPO targeting. A high root-level count can prompt design review, but no fixed number or nesting depth is universally correct.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Document the purpose of root-level OUs and review whether their hierarchy supports current delegation and policy design. Do not reorganize OUs merely to meet an arbitrary count.

#### How the Test Works

Finds OUs directly below the connected domain's root DN and lists their distinguished names. It is an inventory, not an enforcement check for a particular OU layout.

#### Related Tests

- **AD-OU-01 — OU names are unique across the hierarchy** — `Test-MtAdOuOverlappingNameCount` — Reviews overlapping OU names.
- **AD-OU-04 — OUs with no selected visible direct children inventory** — `Test-MtAdOuEmptyCount` — Inventories OUs without selected visible children.

#### Related links

* [Microsoft Learn: Reviewing OU Design Concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/reviewing-ou-design-concepts)

<!--- Results --->
%TestResult%
