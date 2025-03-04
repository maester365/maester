Domain-based Message Authentication, Reporting & Conformance (DMARC) is a standard that helps prevent spoofing by verifying the senders identity. If an email fails DMARC validation, it often means that the sender is not who they claim to be, and the email could be fraudulent. The owner of the sending domain controls the DMARC policy for their domain, and provides recommendations to receivers on what action should be performed when DMARC fails. When the Honor DMARC Policy setting is set to False, the organisations policy is not considered. It is recommended to honor this policy. 

#### Remediation action
Configure anti-phish policy to honor sending domains DMARC configuration.

#### Related Links

* [Announcing New DMARC Policy Handling Defaults for Enhanced Email Security](https://techcommunity.microsoft.com/t5/exchange-team-blog/announcing-new-dmarc-policy-handling-defaults-for-enhanced-email/ba-p/3878883) 
* [Microsoft 365 Defender Portal - Anti-phishing](https://security.microsoft.com/antiphishing)
