Authentication Policies and Authentication Policy Silos provide additional controls for restricting where accounts can authenticate and for isolating high-value identities. A simple container count does not show whether policies are enforced or whether the expression attributes needed for evaluation were actually returned.

##### Control Type

**Detective**

##### Security Recommendation

- Use Authentication Policies and Silos where they provide a documented security boundary for high-value accounts and services.
- Review enforced and non-enforced Silos separately; non-enforced Silos do not apply their intended restrictions.
- Treat optional expression attributes that were not returned as unknown. Do not infer that they are unset or that collection was incomplete without additional evidence.
- Validate assignments and business compatibility before enforcing new policies.

##### How the Test Works

The test performs read-only LDAP searches under `CN=AuthN Policy Configuration,CN=Services` in the configuration naming context. It reports:

- Authentication Policy count and enforcement state
- Authentication Policy Silo count and enforcement state
- Whether requested authentication-expression attributes were returned
- A valid empty state when no policy or silo objects exist

The test distinguishes no policy objects from optional attributes that were not returned. If no policies exist, expression evaluation is **not applicable**. If policies exist but requested properties were not returned, their configuration state is **unknown**; absence alone does not prove that the attributes are unset or that collection was incomplete.

##### Related links

- [Microsoft Learn: Authentication Policies and Authentication Policy Silos](https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/authentication-policies-and-authentication-policy-silos)

%TestResult%