#### Test-MtAdIntermediateCaCount

#### Why This Test Matters
Intermediate Certification Authorities (CAs) sit between root CAs and end-entity certificates. They influence which certificate chains can be built for authentication and other PKI-backed operations.

A sudden change in the number of intermediate CAs can indicate:
- Unauthorized issuance paths being introduced
- Configuration drift from expected PKI baselines
- Incomplete/incorrect CA role deployment after PKI changes

Monitoring the *count* helps you detect unexpected additions/removals quickly, before they result in trust failures or broadened trust.

#### Security Recommendation
- Maintain an approved list of intermediate CA thumbprints/subjects and treat deviations as security-relevant events.
- Investigate and remediate any intermediate CA entries that were not deployed through your change management process.
- Use this count as an early indicator before running deeper CA detail validation tests.

#### How the Test Works
The test queries AD configuration for intermediate CA entries and returns the number of intermediate CAs currently present. This provides a baseline for expected PKI hierarchy structure and change detection.

#### Related Tests
- [Test-MtAdIntermediateCaDetails](./Test-MtAdIntermediateCaDetails.md)
