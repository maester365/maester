KDS root keys are used to generate keys required for Group Managed Service Accounts (gMSA) and related group-managed credential operations.

If KDS root keys are missing, misconfigured, or unexpectedly changed, service account provisioning can fail—potentially causing insecure workarounds or prolonged downtime.

Monitoring the *count* of KDS root keys helps identify:
- Missing keys that prevent proper gMSA key derivation
- Unexpected additional keys that could indicate misconfiguration or unauthorized changes

#### Control Type

**Operational**

#### Security Recommendation
- Ensure exactly one KDS root key exists per forest. Multiple keys can cause gMSA authentication failures.
- Validate the expected number of keys for your environment and alert on deviations.
- Restrict administrative access to actions that can modify KDS root keys.

#### How the Test Works
The test enumerates KDS root keys present in Active Directory and evaluates the count:
- **0 keys**: gMSAs are not in use; the test is skipped.
- **1 key**: The recommended configuration; the test passes.
- **More than 1 key**: Can cause gMSA authentication failures; the test fails.

#### References

- [Microsoft: gMSA authentication failures with multiple KDS root keys](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys)

<!--- Results --->
%TestResult%
