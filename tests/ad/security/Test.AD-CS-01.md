Reviews published AD CS templates for configuration prerequisites associated with unguarded authentication-certificate enrollment.

The check correlates Enterprise CA publication, authentication-capable EKUs (including an observed empty EKU), requester-supplied subject information, manager approval and the required authorized-signature count. A known issuance gate disproves this modeled path. It does not establish that all certificate enrollment is safe.

| Disposition | Meaning |
| --- | --- |
| PrerequisitesNotSatisfied | At least one modeled prerequisite is disproven by known evidence, including required approval or authorized signatures. |
| PotentiallyEligible | The modeled prerequisites are present and a security descriptor is available for authorization review. Effective enrollment permissions remain unassessed. |
| Inconclusive | A published template cannot be resolved uniquely or necessary EKU, flag, signature-count or security-descriptor evidence is missing or malformed. |

Missing properties and unknown numeric values are not converted to false or zero. An explicitly observed empty EKU means unrestricted usage; an uncollected EKU remains unknown. Missing published-template references remain visible instead of disappearing from the result. Completed empty publication inventories are NotApplicable; failed/incomplete inventories require investigation.

This Preview check uses Medium severity because it identifies a configuration prerequisite that still depends on effective authorization and CA behavior. It reports candidates for investigation rather than claiming an exploitable attack path. Requiring approval or additional signatures changes enrollment workflows, so user impact and implementation cost are Medium. Certificate templates use the existing CertificateAuthority resource type defined by the Maester taxonomy.

#### Remediation action

1. Open Certificate Templates (`certtmpl.msc`) and Certification Authority (`certsrv.msc`) for the listed templates and publishing CAs. Remove publication references to unused or unresolved templates.
2. Review the template's Subject Name and Application Policies. Restrict requester-supplied identities and certificate purposes to the required workflow.
3. Under Issuance Requirements, require CA certificate manager approval or appropriate authorized signatures where the workflow permits. Test enrollment with the intended requesting and signing identities before applying changes broadly.
4. Review Enroll/Autoenroll permissions, nested-group membership, enrollment-agent restrictions and CA policy separately. A collected security descriptor alone does not establish who can enroll.
5. For inconclusive evidence, check directory read permissions and collection completeness, then start a fresh run. Do not treat missing flags, signature counts or templates as an unguarded path being disproven.

The check does not enroll certificates, generate/export private keys, perform PKINIT, inspect every issuance extension or policy module, or claim confirmed exploitation. Other ESC paths and actual issued-certificate properties need separate controls.

#### Related links

- [AD CS overview](https://learn.microsoft.com/windows-server/identity/ad-cs/active-directory-certificate-services-overview)
- [MS-WCCE authorized signatures](https://learn.microsoft.com/openspecs/windows_protocols/ms-wcce/35e6361f-8d69-4fbe-a586-5f1c8395ffcd)
- [RFC 5280 extended key usage](https://www.rfc-editor.org/rfc/rfc5280.html#section-4.2.1.12)

<!--- Results --->
%TestResult%
