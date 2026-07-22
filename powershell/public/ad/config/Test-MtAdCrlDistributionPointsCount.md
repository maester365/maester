#### Test-MtAdCrlDistributionPointsCount

#### Why This Test Matters
Certificate Revocation Lists (CRLs) are published at specific locations called *CRL distribution points*. These endpoints enable relying parties (including AD-integrated components) to check whether certificates have been revoked.

If CRL distribution points are missing, misconfigured, or reduced unexpectedly, revocation checking can fail. That can allow previously revoked certificates to remain effectively trusted longer than intended.

Monitoring the *count* of CRL distribution points helps detect:
- Missing distribution points after CA configuration changes
- Unexpected additions (potentially pointing to untrusted or incorrect publishing locations)

#### Security Recommendation
- Ensure CRL distribution points are configured to reliable, access-controlled endpoints.
- Validate that all intended distribution points are present and reachable from relying-party networks.
- Alert on changes to the number of distribution points—treat deviations as configuration drift.

#### How the Test Works
The test inspects AD configuration for CRL distribution point entries, counts them, and reports the current number. This provides a lightweight indicator that your revocation publication settings align with expected CA configuration.
