Authentication Policies and Authentication Policy Silos provide additional controls for restricting where accounts can authenticate and for isolating high-value identities. This test reports policy and silo inventory and enforcement state.

###### Control Type

**Detective**

###### Security Recommendation

- Use Authentication Policies and Silos where they provide a documented security boundary for high-value accounts and services.
- Review enforced and non-enforced Silos separately; non-enforced Silos do not apply their intended restrictions.
- Treat omitted optional expression attributes cautiously. LDAP omission alone does not establish whether an attribute is unconfigured or withheld by access controls.
- Validate assignments and business compatibility before enforcing new policies.

###### How the Test Works

The test performs read-only LDAP searches under `CN=AuthN Policy Configuration,CN=Services` in the configuration naming context. It reports:

- Authentication Policy count and enforcement state
- Authentication Policy Silo count and enforcement state
- Non-enforced Silo names when present
- A valid empty state when no policy or silo objects exist

Collection failure is distinguished from a valid empty result. The test does not infer collection failure or configuration state from omission of an optional LDAP attribute.

###### Related links

- [Microsoft Learn: Authentication Policies and Authentication Policy Silos](https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/authentication-policies-and-authentication-policy-silos)

%TestResult%
