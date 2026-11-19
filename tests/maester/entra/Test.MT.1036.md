Checks for gaps in Conditional Access policies, by looking for excluded objects which are not specifically included
in another Conditional Access policy. Instead of looking at the historical sign-ins to find gaps, we try to spot possibly
overlooked exclusions which do not have a fallback.

The check compares excluded and included users, groups, roles, applications, service principals, agent identities,
agent users, locations and platforms across all enabled policies. An object counts as having a fallback only when an
enabled policy includes it by its ID (or, for platforms and special values such as `GuestsOrExternalUsers`, by the same
value): an include of `All` does not count.

#### Remediation action

Review the configuration described above.

<!--- Results --->
%TestResult%
