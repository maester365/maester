Inventories disabled GPO link entries using the shared disabled-link check. It reports total, enabled, and disabled link counts and lists disabled links when present. A disabled link may be intentional; this inventory does not decide whether the linked policy should apply. Missing link or GPO collection, or an unknown link state, is an error.

This test retains its default **Info/Passed** outcome when collection succeeds, including when disabled links are found. `AD-GPOREP-12` uses the same inventory but marks it **Investigate**. Neither result makes a risk judgement about an individual disabled link.

#### Remediation action

1. In **Group Policy Management**, locate each listed domain, OU, or site and review its disabled links with the policy owner.
2. Re-enable links that should apply, remove obsolete links, and document intentional exceptions. Confirm inherited policy and intended scope before changing a link.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
