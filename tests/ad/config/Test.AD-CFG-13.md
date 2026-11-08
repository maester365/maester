Inventories certificate template objects and cross-references the names published by Enterprise CAs.

The table lists each template CN, display name and publishing CA, plus unknown published names that do not resolve to an inventoried template object. Publication alone does not prove an enrollment permission or a vulnerability.

#### Control Type

**Operational**

#### Security Recommendation

Review published templates with PKI owners and inspect enrollment permissions, constraints and issuance settings separately. An unusual count or publication is not proof of a vulnerable template.

#### How the Test Works

The test inventories template objects and cross-references template CNs with names published by Enterprise CAs, including unresolved published names; it does not assess effective enrollment rights.

#### Related Tests

- **AD-CFG-12 — Enterprise CA inventory** — `Test-MtAdEnterpriseCaCount` — Inventories publishing CAs.

#### Remediation action

Review unknown names and unexpected publication with the PKI owner. Compare the template's enrollment permissions and issuance settings to your organization's policy before changing a publication.

#### Related links

* [Certificate template concepts](https://learn.microsoft.com/windows-server/identity/ad-cs/certificate-template-concepts)

<!--- Results --->
%TestResult%
