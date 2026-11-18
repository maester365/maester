Ordinary users under CN containers rather than managed OUs may miss intended OU-linked policies and delegated administration. Escaped commas in distinguished names are handled as part of the RDN.

#### Control Type

**Detective**

#### Security Recommendation

Place ordinary users in OUs appropriate to their intended user-policy scope and delegated administration; validate resulting GPO application and permissions before moves.

#### How the Test Works

The test identifies ordinary users beneath CN containers using parsed distinguished-name components (including escaped commas). OU location alone does not prove effective GPO application; links target sites, domains and OUs, with groups usable as security filters.

#### Related Tests

- **AD-GRP-02 — Groups in container objects count should be retrievable** — `Test-MtAdGroupInContainerCount` — Inventories group placement without treating groups as GPO targets.

#### Related links

- [Microsoft: Group Policy scope](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-scope)

#### Remediation action
1. Check OU policy and delegation requirements before moving affected users using [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).

<!--- Results --->
%TestResult%
