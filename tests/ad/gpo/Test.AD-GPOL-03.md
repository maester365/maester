Inventories direct GPO link coverage across collected OUs, the domain root, and sites. It counts linked and unlinked targets and lists targets without a direct link. The test always returns **Investigate**: a target without a direct link may receive policy through inheritance, so this count does not establish an effective-policy gap.

The inventory recognizes GPO GUID references in `gPLink`, including disabled and dangling links. It does not evaluate link state, resolve every reference to an existing GPO, or calculate resultant policy. Missing target collection is an error.

#### Remediation action

Review each target without a direct link against the intended design, including inherited policy, blocked inheritance, link state, and policy scope. Add a direct link only when that design requires it; investigate missing or incomplete target collection.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
