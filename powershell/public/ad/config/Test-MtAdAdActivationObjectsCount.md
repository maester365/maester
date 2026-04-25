# Test-MtAdAdActivationObjectsCount

## Why This Test Matters
AD-based activation objects are used by Windows for volume activation and related discovery workflows. If these objects are created, deleted, or altered without authorization, it can indicate licensing/tampering activity and may also reflect broader Active Directory compromise or unauthorized configuration changes.

## Security Recommendation
- Treat activation-object changes as security-relevant change-management events.
- Restrict who can create/modify activation objects (least privilege) and remove unnecessary write permissions.
- Establish a known-good baseline for the number of activation objects per environment/forest and alert on deviations.
- Review recent directory change/audit events to identify the initiating account and purpose.

## How the Test Works
- Enumerates activation-related objects stored in Active Directory.
- Counts the objects discovered in the activation container(s).
- Compares the count to an environment baseline and flags unexpected increases/decreases.

## Related Tests
- [Test-MtAdWellKnownSecurityPrincipalsCount](./Test-MtAdWellKnownSecurityPrincipalsCount.md): Detects unexpected identity/config changes that may accompany tampering.
- [Test-MtAdRegisteredDhcpServersCount](./Test-MtAdRegisteredDhcpServersCount.md): Detects unauthorized network services registered in AD.
