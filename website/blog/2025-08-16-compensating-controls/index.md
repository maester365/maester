---
title: Introduction to Compensating Controls 🎛️
description: Review controls, the need for compensating controls, and how the concepts apply to Maester
slug: compensating-controls
authors: mike
tags: [blog]
hide_table_of_contents: false
date: 2025-08-16
---

If you have ever seen one of my presentations on or we have ever discussed technology security or operations, you have likely heard me say something like: _At a certain maturity level everything is just exception management_. Keep reading to get more details on one of the most common exception management techniques, **compensatory** or **compensating controls**.

<!-- truncate -->

## What is a control?

The ComplianceForge team provides a nice definition:

"Controls are safeguards or countermeasures implemented to manage risks and protect assets. Cybersecurity controls can be technical, administrative, or physical and are designed to reduce vulnerabilities, prevent threats and ensure confidentiality, integrity and availability of information." [(ComplianceForge, 2025)](https://complianceforge.com/what-are-controls/)

In the simplest of terms your organization has said, "We care about X". The control documents what you are doing to protect "X".

Keeping in mind too, that your control usually is a reference to a general situation or outcome you are hoping to manage the risk of. Through that reference you will typically aim to have a mapping to a procedure. The procedure should specify what steps are taken to align with a control for a given system or process.

Controls will also typically map to the upstream compliance requirements through policies, standards, or other documentation.

A very simple example of how this fits together:

* Policy - "Employees *must* protect organization data"
* Control - "Computers *should* not remain unlocked when not in use for longer than 5 minutes"
* Procedure - "Configure the Windows lock screen timeout setting to 5 minutes of inactivity"

> 💡 Callout
>
> Above you can see keywords *should* and *must*, these have specific implications as to optional or mandatory respectively as well. See [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) for more detail of one example of defining these terms.

This example is a simple example, but the nuance and complexity becomes challenging to manage at scale, your organization may even have individuals dedicated in a partial or full time capacity to managing this.

For our example we can map our control against a well known control framework or benchmarck, the Center for Internet Security (CIS) Critical Security Controls (CSC) Version 8.1. For CIS CSC safeguard 4.3 they specify a 15 minute maximum inactivity period for general computing devices. There are many different control frameworks out there that reference similar control concepts, and some frameworks may even have contradicting controls.

[<img width="825" height="323" alt="image" src="https://gist.github.com/user-attachments/assets/bed14a14-ebbe-44e4-86c1-870db49b0381" />](https://www.linkedin.com/posts/nathanmcnulty_while-im-on-the-topic-of-cis-benchmarks-activity-7357543171045642240-wrNm/)

> 💡 Callout
>
> Governance terminology (e.g., frameworks, policies, standards, and more) gets used in many contexts with many different meanings. An example being the United States National Institute of Standards and Technology (NIST), which publishes standards and more. The NIST Special Publication (SP) 1800 series is a common example of **guidelines**. Often these NIST SPs may be referenced as standards though. Standards bodies exist for many different topics in many different ways, such as the OpenID Foundation (OIDF) creating identity standards that are secure, interoperable and privacy-preserving, or ASTM International offers resources for standards development and use worldwide. This illustrates a nuance as well for internal versus external standards. Where external standards are typically consensus driven by an industry working group aroud common specifications for implementations, and internal standards define specific requirements your organization has for implementations.

### But still... Why would you implement that control?

There are a many reasons your organization may want to implement a control like our example, but there are two general categories:

* Proactive risk mitigation
  * It is well known that cybersecurity has direct risk and impact to business operations. Understanding, identifying, and prioritizing these risks is beneficial for any organization. Some risks may be worth taking mitigating measures, such as implementing controls, proactively and others may not be a high enough priority.
* Regulatory compliance
  * Your organization may have specific regulatory or compliance obligations as part of your business operations as well. A common example of a regulatory obligation is Health Insurance Portability and Accountability Act (HIPAA) for healthcare covered entities and their business associates. Using our example control, [45 CFR 164.312(a)(2)(iii)](https://www.ecfr.gov/current/title-45/part-164/subpart-C#p-164.312(a)(2)(iii)) identifies a specific addresable requirement.

## Why do we need to compensate?

Continuing to use the screen lock out example. You may find yourself in situations where:

* There is no technical capability on a system to enforce a screen lockout to the specific maximum inactivity time or possibly at all.
  * An example may be a proprietary system that does not offer the technical capability.
* There is a business process that does not allow for a screen lockout within the specific maximum inactivity time or possibly at all.
  * An example may be a kiosk or shared workstation.
* There may be tangential services you offer that do not fall within scope of the requirements.
  * An example may be a personal use device provided to clients during waiting periods.

Each of these situations could justify a need for an exception to your policy. These could be examples of compensating controls.

* You may decide to implement a physical safeguard and prevent physical access to a proprietary system that does not allow for a screen lockout.
* You may decide to exclude the shared workstations from policy, but require applications in use on those systems to enforce an inactivity requirement.
* You may decide to exclude all personal use devices from policy and prevent access to organization resources.

## How does this apply to Maester?

The Maester project provides a way for testing that a control's procedures are currently in place. Often times though your organization may have different requirements, exceptions, or preference in the controls you implement. Maester offers testing for multiple control procedures from community guidance (i.e., MT or EIDSCA), Cybersecurity & Infrastructure Security Agency (CISA), CIS, and more. Though there is still some decisions on your part [which tests you want to use](https://maester.dev/docs/commands/Invoke-Maester#-excludetag) or if [you should use your own](https://maester.dev/docs/writing-tests/).

The Maester project is providing you better visibility into the possible controls you may need to implement, but you still need to decide what is the best for your end user experience, acceptable risk tolerance, and business obligations.

### Examples of this topic in the wild

* https://github.com/maester365/maester/discussions/1068
* https://github.com/maester365/maester/discussions/429
* https://github.com/maester365/maester/discussions/1093
* https://github.com/maester365/maester/issues/686
* https://github.com/maester365/maester/issues/1052
* https://github.com/maester365/maester/issues/364
* https://github.com/maester365/maester/issues/282
* https://github.com/maester365/maester/issues/194
* https://github.com/maester365/maester/discussions/1049
