The organization's profile has a Verified badge.

Verification helps people distinguish the organization from an attacker impersonating it. The fix does not change users' everyday access, but verifying the profile domains can require another team and time for DNS changes to take effect.

CIS GitHub Benchmark v1.2.0 lists section 1.3.9 as a Manual assessment (physical PDF pages 92–93; printed pages 91–92). This test reads the connected organization's `id`, `login`, and `isVerified` through `POST /graphql`. GitHub defines `isVerified` as verification of the profile email and website.

Set `GitHubEnterprise` to the intended enterprise's slug. Before assessing verification, Maester finds the same organization node ID in that enterprise's organizations list, reading later pages when needed. With that association confirmed, Boolean `true` passes and Boolean `false` fails.

Missing enterprise context, an inaccessible or missing association, denied fields, or an unusable verification value produces **Skipped**, with a reason explaining what could not be checked. A missing match does not establish that the organization has no enterprise relationship. Invalid configuration, request failures, and JSON parsing failures produce **Error**.

The test covers the connected organization, including an internal EMU organization where GitHub returns the required fields. It does not scan every organization in the enterprise. Domain approval, domain counts, profile text, and the presence of a DNS record do not decide the result. GitHub allows the verification TXT record to be removed after the badge appears, so the test does not require that record to remain. GraphQL uses the connected API host and its own schema; the REST version header does not version it.

#### Permissions required

Use supported GraphQL user authentication with access to the organization and the selected enterprise's organization list. This test does not request `ownerInfo` or require enterprise-owner access merely to establish the association. Field-specific fine-grained or App permissions are not assumed. Maester's connection still requires active organization membership.

#### Remediation action

1. An organization owner should open **Settings** > **Verified & approved domains** for the organization. An enterprise owner can instead verify domains in the enterprise's settings so its organizations inherit them.
2. Work with the domain administrators to verify the domains used by the organization's profile email and website. Follow GitHub's DNS verification instructions and coordinate with an enterprise owner when using inherited domains.
3. Confirm that the profile displays its **Verified** badge. If the email and website use different domains or variants, verify each required domain.
4. Run the test again.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [Organization GraphQL fields](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/orgs#organization)
* [Enterprise organization association](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/enterprise-admin#enterprise)
* [Verified badge and domain requirements](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/verifying-or-approving-a-domain-for-your-organization)

<!--- Results --->
%TestResult%
