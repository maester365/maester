#### Test-MtAdNtAuthCertificatesCount

#### Why This Test Matters
NTAuth certificates determine which Certification Authorities (CAs) are trusted to issue certificates for domain authentication scenarios (commonly smart card / certificate-based logon).

An increase in NTAuth certificates can mean additional CAs are now trusted—expanding the trust boundary and potentially enabling an attacker to obtain a certificate from an unintended CA.

Monitoring NTAuth certificate *count* helps detect:
- Unauthorized or accidental additions of NTAuth trust anchors
- Drift away from your approved CA list

#### Security Recommendation
- Treat the NTAuth store as security-critical: only add CAs that are explicitly approved.
- Review NTAuth changes immediately; require change ticket + CA validation before trusting new certificates.
- Remove any NTAuth certificates that are no longer required or are not in the approved CA list.

#### How the Test Works
The test queries the AD NTAuth certificate container, counts the number of configured NTAuth certificates, and outputs the result so you can track drift and investigate deviations.
