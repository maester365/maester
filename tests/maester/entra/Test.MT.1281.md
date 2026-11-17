Should not have expired or expiring credentials for linked applications

Applications linked to an Entra External ID user flow authenticate using a
client secret or certificate (`passwordCredentials` / `keyCredentials` on the
app registration). An expired credential causes sign-in failures for every
user going through the user flow, and the failure is often invisible until
users start reporting it. This test flags any linked application that has an
expired credential, or one expiring within `ExpiryWarningDays` (default 30)
days.

Unlike `MT.1199` (which checks every app registration in the tenant), this
test is scoped specifically to applications that are actually linked to an
Entra External ID user flow, so a finding here means an active, user-facing
sign-in surface is at risk.

#### Remediation action

1. In the [Entra admin center](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/CustomAuthenticationExtensionsMenuBlade/~/UserFlows), open **App registrations**.
2. Select the affected application listed in the results below.
3. Go to **Certificates & secrets** and create a new client secret or certificate well before the existing one expires.
4. Remove the old credential once the new one is confirmed working.

<!--- Results --->
%TestResult%
