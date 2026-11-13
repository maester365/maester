Evaluates whether an enterprise CA publishes certificate templates whose collected configuration matches prerequisites commonly associated with certificate-based identity abuse.

#### Control Type

**Operational**

#### Security Recommendation

- Review every published template that supports client authentication and lets the requester supply subject information.
- Require manager approval or authorized signatures where business workflows permit.
- Restrict Enroll and Autoenroll rights to explicitly approved principals.
- Remove unused templates from each enterprise CA.
- Treat a candidate as a configuration lead, not proof of successful enrollment or authentication.

#### How the Test Works

The test correlates enterprise CA `certificateTemplates` publication with each template's EKUs, enrollment flags, certificate-name flags, and security-descriptor availability. A template is reported for investigation when it is published, authentication-capable, allows enrollee-supplied subject information, does not require manager approval, and has authorization evidence available or unresolved.

The test deliberately distinguishes observed prerequisites from exploitability. It does not enroll a certificate, generate or export a private key, perform PKINIT, or claim that an attack path was executed.

#### Result Interpretation

- **PrerequisitesNotSatisfied**: at least one modeled condition is disproven.
- **PotentiallyEligible**: dangerous template and publication conditions exist, with ACL evidence available for follow-up.
- **Inconclusive**: required authorization evidence is unavailable.

<!--- Results --->
%TestResult%