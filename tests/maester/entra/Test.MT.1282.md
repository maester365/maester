Should not have guest invitations pending acceptance beyond the configured threshold

When a guest is invited to a tenant, their account is created immediately
but remains in `externalUserState = PendingAcceptance` until the invited
user actually redeems the invitation by signing in. If a guest never
redeems their invitation, the account still exists in the directory -
usually with no real access yet - but adds clutter and can be used later if
the invitation link is somehow compromised before expiring.

This test lists every guest user (`userType eq 'Guest'`) whose invitation
has been in `PendingAcceptance` state for longer than `PendingDays` (default
30 days).

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/UsersManagementMenuBlade/~/AllUsers), open **Users**.
2. Locate each guest listed in the results below.
3. Either resend the invitation if access is still needed, or remove the guest account if it is no longer required.

<!--- Results --->
%TestResult%
