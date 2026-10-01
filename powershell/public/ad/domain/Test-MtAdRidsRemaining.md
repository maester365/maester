#### Test-MtAdRidsRemaining

#### Why This Test Matters

RIDs (Relative Identifiers) are essential for creating unique Security Identifiers (SIDs) for every user, group, and computer in Active Directory. Each domain has a finite pool of approximately 1 billion RIDs:

 * **SID Exhaustion**: Running out of RIDs would prevent creation of any new security principals
 * **Business Impact**: New users, groups, or computers could not be created
 * **Recovery Complexity**: RID pool exhaustion requires complex forest recovery procedures

#### Security Recommendation

Monitor RID consumption regularly:

 * **Normal Usage**: Most domains use only a small fraction of available RIDs over their lifetime
 * **High Consumption**: Rapid RID consumption may indicate:
  * Excessive computer account creation/deletion cycles
  * Automated provisioning scripts creating many accounts
  * Security issues like computer account flooding attacks
 * **Threshold Alerting**: Set alerts when RID usage exceeds 50% (very conservative) or 75%

If RID consumption is unexpectedly high:
1. Investigate the source of high account creation
2. Review computer join policies and scripts
3. Consider implementing stricter controls on account creation

#### How the Test Works

This test retrieves the RID available pool from Active Directory and calculates the remaining RIDs. The RID pool is a 64-bit value where the high 32 bits represent the total pool and the low 32 bits represent used RIDs.

#### Related Tests

- `Test-MtAdDomainControllerCount` - Counts domain controllers (RID masters)
- `Test-MtAdMachineAccountQuota` - Checks machine account creation limits
