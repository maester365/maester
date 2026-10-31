1.3.9 (L2) Ensure an organization’s identity is confirmed with a “Verified” badge

CIS Benchmark: CIS GitHub Benchmark v1.2.0. Assessment Status: Manual.
Source: section 1.3.9, physical PDF pages 92–93; printed pages 91–92.

#### Rationale

A verified profile helps distinguish an organization from an attacker masquerading as it.

#### Assessment and scope

This check uses `POST /graphql` to read the connected organization's `id`, `login`, and `isVerified`. GitHub defines the Boolean as verification of the profile email and website; its badge guidance connects those verified profile domains to the organization's Verified badge. True passes and false fails only after enterprise applicability is established.

Set `GitHubEnterprise` explicitly. The check establishes a positive association by finding the same organization node ID in that enterprise's documented organizations connection, following cursors as needed. It does not claim a complete enterprise-wide organization assessment. A missing match, inaccessible association, missing enterprise context, nullable response parent, denied field, or unusable Boolean is indeterminate. An absent match is not proof that there is no enterprise relationship.

#### Permissions required

Use supported GraphQL user authentication with access to the organization and the enterprise association query. `ownerInfo` is not requested or required. Do not assume an enterprise-owner role or undocumented fine-grained/App field permission is necessary merely because this check verifies enterprise applicability; unavailable required fields remain indeterminate. The current Maester connection still requires active organization membership.

#### Impact

Verification changes the profile's trust signal without changing users' everyday access. Coordinate DNS verification with the domain owner; this can require another team and DNS propagation.

#### Remediation action

1. An organization owner should open the organization's **Settings** > **Verified & approved domains**; see [GitHub's domain guidance](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/verifying-or-approving-a-domain-for-your-organization). An enterprise owner can instead verify domains in the enterprise's **Settings** > **Verified & approved domains** so its organizations inherit them.
2. Add and verify the domains used by the organization's profile email and website, following GitHub's DNS verification instructions with the relevant domain administrators. Coordinate with an enterprise owner when using inherited domains.
3. Confirm that the organization's profile displays its **Verified** badge. If the profile email and website use different domains or variants, verify the required domains.
4. Repeat the read-only assessment. GitHub permits removing the DNS TXT record after the badge appears; this check does not require TXT persistence.

#### Known limitations

Domain approval alone, domain counts, website strings, company text, and DNS-record presence are not substituted for verified profile state. The result concerns the named organization, including an internal EMU organization where the field is available, not public visibility or every organization in an enterprise. GraphQL uses the deployment's API host and is not versioned by the REST version header. Request/parsing failures remain Error; unavailable assessment evidence remains indeterminate.

#### Related links

* [CIS GitHub Benchmark](https://www.cisecurity.org/benchmark/github)
* [Organization GraphQL fields](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/orgs#organization)
* [Enterprise organization association](https://docs.github.com/en/enterprise-cloud@latest/graphql/reference/enterprise-admin#enterprise)
* [Verified badge and domain requirements](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/verifying-or-approving-a-domain-for-your-organization)

<!--- Results --->
%TestResult%
