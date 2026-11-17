Broad identities with rights that apply to `dnsNode` children can authorize a large population to create or modify records in an AD-integrated DNS zone. Authorization is a candidate condition only and does not prove successful record creation, name resolution, traffic redirection, adversary-in-the-middle credential capture, relay, privilege escalation, or domain compromise.

#### Remediation action
Review each reported ACE with the DNS and Active Directory owners. Replace broad assignments with a purpose-specific security group and the narrowest required rights only after validating application dependencies.

<!--- Results --->
%TestResult%