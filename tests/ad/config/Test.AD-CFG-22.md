KDS root keys are used to generate keys required for Group Managed Service Accounts (gMSA) and related group-managed credential operations.

If KDS root keys are missing, misconfigured, or unexpectedly changed, service account provisioning can fail—potentially causing insecure workarounds or prolonged downtime.

Monitoring the *count* of KDS root keys helps identify:
- Missing keys that prevent proper gMSA key derivation
- Exactly two keys, which can cause gMSA authentication failures in some scenarios

#### Control Type

**Operational**

#### Security Recommendation
- At least one KDS root key is required to provision gMSAs. Exactly two keys can cause gMSA authentication failures in some sorting scenarios; multiple keys are not inherently invalid.
- If exactly two keys exist, Microsoft's recommended workaround is to create a third key. Do not remove existing keys.
- Validate the expected number of keys for your environment and alert on deviations.
- Restrict administrative access to actions that can modify KDS root keys.

#### How the Test Works
The test enumerates KDS root keys present in Active Directory and evaluates the count:
- **0 keys**: gMSA provisioning is unavailable; the test fails. This does not prove whether gMSAs are in use.
- **1 key**: The test passes.
- **2 keys**: Can cause gMSA authentication failures in some scenarios; the test returns Investigate.
- **3+ keys**: The test passes; Microsoft's workaround for the two-key sorting issue is to add a third key.

#### References

- [Microsoft: gMSA authentication failures with multiple KDS root keys](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys)

<!--- Results --->
%TestResult%
