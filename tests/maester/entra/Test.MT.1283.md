Should not have users with an "unknown" display name

Some users in the directory can end up with a `displayName` of "Unknown",
typically because they were provisioned (e.g. via a External ID sign-up
flow or external identity provider) without a first name and last name being
captured. A display name of "Unknown" makes these accounts very difficult to
identify in audit logs, access reviews, sign-in reports, and admin
experiences.

This test lists every user whose display name is exactly "Unknown", along
with their email address (falling back to other emails or UPN), since the
email is typically the only reliable way to identify who the account belongs
to.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/UsersManagementMenuBlade/~/AllUsers), open **Users**.
2. Locate each user listed in the results below (search by email/UPN).
3. Update their **First name** / **Last name** (or ask the user to complete their profile) so the display name is meaningful. If the account is a test or abandoned account, consider removing it instead.

<!--- Results --->
%TestResult%
