SPNs using short host names may warrant review against the service's intended Kerberos naming and DNS design. A host name without a dot is not necessarily invalid. Depending on the workload, short names can cause:

- **Authentication failures**: Kerberos may fail to find the correct service principal
- **DNS resolution issues**: Short names may not resolve correctly in all contexts
- **Cross-domain problems**: Non-FQDNs may not work across domain trusts
- **Configuration drift**: Indicates inconsistent SPN registration practices

#### Control Type

**Operational**

#### Security Recommendation

Review SPNs with non-FQDN hosts:
- Determine if the SPN is still needed
- Update SPNs to use FQDN format (serviceclass/host.fqdn:port)
- Establish standards for SPN registration in your organization
- Use FQDNs consistently for all service principal names

#### How the Test Works

This test parses computer SPNs and checks whether the host portion contains a dot as a simple FQDN-format proxy. A flagged name is for investigation, not proof of a broken service.

#### Related Tests

- **AD-SPN-11 — User SPN non-FQDN hosts should be investigated** — `Test-MtAdUserSpnNonFqdnHosts` — Reviews user-account SPN hosts.
- **AD-SPN-01 — Computer SPN service class count should be retrievable** — `Test-MtAdComputerSpnServiceClassCount` — Inventories service classes, not host validity.

<!--- Results --->
%TestResult%
