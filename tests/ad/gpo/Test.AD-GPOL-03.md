Inventories direct Group Policy link coverage across collected OUs, the domain root, and sites, reporting linked and unlinked targets. The test always returns **Investigate**: a target without a direct link may receive policy through inheritance, so this count is not proof of an effective-policy gap.

The inventory recognizes GPO GUID references in `gPLink` values, including disabled and dangling links. It does not evaluate link state, resolve every reference to an existing GPO, or calculate resultant policy. Review inheritance and policy processing separately.

#### Remediation action

Review each target without a direct link against the intended design, including inherited policy, blocked inheritance, link state, and policy scope. Add a direct link only when required by that design; investigate missing or incomplete target collection.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
