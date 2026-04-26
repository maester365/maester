#### Test-MtAdKdsRootKeysCount

#### Why This Test Matters
KDS root keys are used to generate keys required for Group Managed Service Accounts (gMSA) and related group-managed credential operations.

If KDS root keys are missing, misconfigured, or unexpectedly changed, service account provisioning can fail—potentially causing insecure workarounds or prolonged downtime.

Monitoring the *count* of KDS root keys helps identify:
- Missing keys that prevent proper gMSA key derivation
- Unexpected additional keys that could indicate misconfiguration or unauthorized changes

#### Security Recommendation
- Ensure KDS root keys are deployed according to your Microsoft recommended procedures.
- Validate the expected number of keys for your environment (e.g., per forest/role) and alert on deviations.
- Restrict administrative access to actions that can modify KDS root keys.

#### How the Test Works
The test enumerates KDS root keys present in AD (or the module’s KDS configuration view), then reports how many keys are currently configured.
