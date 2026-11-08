OU names are unique across the hierarchy.

Repeated OU names in different locations are allowed by Active Directory. This is an optional organization-wide naming hygiene baseline, not a duplicate distinguished name error.

Ambiguous short names can complicate scripts, audits and manual GPO or delegation changes when administrators ignore the OU's full distinguished name. Legitimate hierarchies may intentionally reuse names.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects against the organization baseline, document intentional exceptions and correct unintended configuration with the directory and network owners.

Where ambiguity causes operational risk, adopt descriptive naming conventions and target OUs by distinguished name in automation. Avoid renaming valid OUs solely because their leaf names repeat.

#### How the Test Works

Groups visible OU objects by name and reports repeated names across the hierarchy. It does not treat separate OUs with the same leaf name as a directory uniqueness violation.

#### Related Tests

- **AD-OU-02 — Root-level OU inventory** — `Test-MtAdOuAtDomainRootCount` — Inventories root-level OUs.
- **AD-OU-04 — OUs with no selected visible direct children inventory** — `Test-MtAdOuEmptyCount` — Inventories OUs without selected visible children.

#### Related links

* [Microsoft Learn: Reviewing OU Design Concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/reviewing-ou-design-concepts)

<!--- Results --->
%TestResult%
