Global Secure Access traffic forwarding profiles (Microsoft 365, Internet, and Private Access) can be scoped to specific users and groups. Microsoft does **not** support nested group membership for this assignment - a user must be a **direct** member of the assigned group to receive the profile (and therefore the Global Secure Access client routing). A nested assignment group silently leaves part of the intended population without the profile.

#### Remediation action:

1. Identify the flagged traffic forwarding profile assignment group(s).
2. Either flatten the group to direct user membership, or assign the nested group(s) to the profile directly.
3. Re-test to confirm that no profile assignment group contains a nested group.

#### Related links

* [Assign users and groups to traffic forwarding profiles](https://learn.microsoft.com/entra/global-secure-access/how-to-manage-users-groups-assignment)
* [Global Secure Access traffic forwarding profiles](https://learn.microsoft.com/entra/global-secure-access/concept-traffic-forwarding)

<!--- Results --->
%TestResult%
