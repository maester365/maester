KDS root keys are used to generate keys required for Group Managed Service Accounts (gMSA) and related group-managed credential operations.

If KDS root keys are missing, misconfigured, or unexpectedly changed, service account provisioning can fail—potentially causing insecure workarounds or prolonged downtime.

Monitoring the *count* of KDS root keys helps identify:
- Missing keys that prevent proper gMSA key derivation
- Exactly two keys, which can cause gMSA authentication failures in some scenarios

#### Control Type

**Operational**

#### Security Recommendation

Confirm complete inventory access independently before interpreting an empty or two-key result. Protect key administration and use Microsoft's third-key workaround only for two keys known to exist; do not delete existing keys.

#### Related Tests

- **AD-MSA-01 — Managed service account count should be investigated** — `Test-MtAdManagedServiceAccountCount` — Inventories managed accounts, including gMSAs whose password infrastructure depends on KDS root keys.

#### Remediation action
- Verify that the assessment identity can list the Master Root Keys container and read every key's metadata. Default key ACLs restrict visibility to privileged identities; a successful LDAP search with zero results does not establish absence.
- `KeyInventoryReadAccessConfirmed` defaults to `false`. Set it to `true` in this check's `TestSettings[].Parameters` only after independently auditing complete read/list access for the identity and target used by this run. This is operator confirmation, not an automated permission probe. Never assume completeness solely from a group name or a successful connection.
- At least one KDS root key is required to provision gMSAs. Exactly two confirmed keys can cause gMSA authentication failures in some sorting scenarios; multiple keys are not inherently invalid.
- Only after confirming that exactly two keys actually exist should an administrator consider Microsoft's documented third-key workaround. Do not create another key based on a partial visible inventory. Do not remove existing keys.
- Validate the expected number of keys for your environment and alert on deviations.
- Restrict administrative access to actions that can modify KDS root keys.

#### How the Test Works
The test enumerates KDS root keys present in Active Directory and evaluates the count:
- **0 visible keys, access unconfirmed**: Investigate. Keys may be hidden; no missing-key or provisioning-unavailable claim is made.
- **0 keys, complete access operator-confirmed**: Failed. This does not prove whether gMSAs are in use.
- **1 key**: The test passes.
- **2 visible keys**: Investigate. With unconfirmed access, verify the complete count before taking action; with confirmed access, evaluate the documented two-key issue.
- **3+ keys**: The test passes; Microsoft's workaround for the two-key sorting issue is to add a third key.

#### References

- [Microsoft: gMSA authentication failures with multiple KDS root keys](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys)
- [Microsoft: KDS root-key class and default security descriptor](https://learn.microsoft.com/windows/win32/adschema/c-mskds-provrootkey)

<!--- Results --->
%TestResult%
