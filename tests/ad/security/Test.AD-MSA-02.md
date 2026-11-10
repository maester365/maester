The `msDS-GroupMSAMembership` authorization descriptor controls which principals can retrieve a group Managed Service Account password. Broad trustees can extend retrieval eligibility beyond the intended service hosts. This includes well-known broad identities, BUILTIN\Users, Domain Users, and Domain Computers when an applicable password-retrieval Allow ACE is present.

This test reads authorization metadata only. It does not request, decode, export, store, or use `msDS-ManagedPassword`.

#### Remediation action
Replace broad trustees with purpose-specific computer or security groups. Validate service dependencies before changing retrieval authorization.

<!--- Results --->
%TestResult%