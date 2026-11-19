Inventories disabled GPO link entries, including links that are both disabled and enforced. Counts are of link entries, not distinct GPOs; the result includes the linked policy and container for each disabled link. The **Investigate** result is informational and does not judge whether a disabled link is appropriate. The summary and metrics table show enabled and disabled link counts; details appear only when disabled links are found. If none are found, the summary says so. Missing link or GPO collection, or an unknown link state, is an error.

`AD-GPOL-02` uses the same inventory but retains its default **Info/Passed** outcome when collection succeeds. The different outcomes are intentional; neither test makes a risk judgement about an individual link.

#### Remediation action

1. In **Group Policy Management**, locate each listed OU, domain, or site and review its disabled links with the policy owner.
2. Re-enable links that should apply, remove obsolete links, and document intentional exceptions. Confirm inherited policy and intended scope before changing a link.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
