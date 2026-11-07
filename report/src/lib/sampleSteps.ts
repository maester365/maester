// Sample Steps and Goals for local development, the shape of section 7.2 of docs/proposals/defenders-path.md.
// The engine writes these in a real result; here they were made once from the step catalogue
// (powershell/assets/steps/) and the rows of testResults.ts, with made-up measures and earlier statuses.
// sampleSteps goes with the full sample, and sampleStepsOne with a run of MT.1001 alone (?sample=step).

export const sampleRowSteps: Record<string, string[]> = {"ASD.ISM-1872":["entra.phishing-resistant-all"],"ASD.ISM-1649":["entra.pim-eligible-roles"],"EIDSCA.AF01":["entra.passkeys-enabled"],"EIDSCA.AF02":["entra.passkeys-enabled"],"EIDSCA.AT01":["entra.temporary-access-pass"],"CISA.MS.EXO.3.1":["defender.dkim"],"CISA.MS.EXO.2.2":["defender.spf"],"CISA.MS.EXO.4.1":["defender.dmarc-published"],"CISA.MS.EXO.4.2":["defender.dmarc-reject"],"CISA.MS.AAD.7.9":["entra.pim-notifications"],"CISA.MS.AAD.7.8":["entra.pim-notifications"],"CISA.MS.AAD.7.6":["entra.pim-approval-global-admin"],"CISA.MS.AAD.7.7":["entra.pim-notifications"],"CISA.MS.AAD.3.1":["entra.phishing-resistant-all"],"CISA.MS.AAD.7.5":["entra.pim-eligible-roles"],"CISA.MS.AAD.3.7":["entra.ca-require-managed-device"],"CIS.M365.5.3.4":["entra.pim-approval-global-admin"],"CIS.M365.5.1.8.1":["entra.password-hash-sync"],"CIS.M365.5.3.1":["entra.pim-eligible-roles"],"CIS.M365.4.1":["intune.mark-unassigned-noncompliant"],"CIS.M365.5.2.2.9":["entra.ca-require-managed-device"],"CIS.M365.2.1.9":["defender.dkim"],"CIS.M365.2.1.8":["defender.spf"],"CIS.M365.2.1.10":["defender.dmarc-enforce"],"CIS.M365.5.2.2.5":["entra.phishing-resistant-admins"],"CIS.M365.5.2.2.7":["entra.ca-sign-in-risk"],"CIS.M365.5.2.2.16":["entra.ca-token-protection-windows"],"CIS.M365.5.2.2.14":["entra.trusted-named-locations"],"MT.1054":["intune.mark-unassigned-noncompliant"],"MT.1231":["intune.compliance-device-risk"],"MT.1031":["entra.pim-eligible-roles"],"MT.1020":["entra.ca-exclude-sync-accounts"],"MT.1034":["entra.emergency-access-excluded"],"MT.1182":["defender.dmarc-reject"],"MT.1005":["entra.emergency-access-excluded"],"MT.1012":["entra.ca-sign-in-risk"],"MT.1001":["entra.ca-require-compliant-device"],"MT.1015":["entra.ca-block-unknown-platforms"],"MT.1014":["entra.ca-require-managed-device-admins"],"MT.1260":["entra.remediate-risky-users"],"ORCA.108":["defender.dkim"],"ORCA.235":["defender.spf-hard-fail"],"ORCA.108.1":["defender.dkim"]}

export const sampleSteps = {
  "Steps": [
    {
      "Id": "entra.ca-exclude-sync-accounts",
      "Title": "Exclude directory sync accounts from Conditional Access",
      "Summary": "The accounts that Microsoft Entra Connect and Cloud Sync use keep syncing when new policies apply.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-all",
        "entra.ca-require-managed-device"
      ],
      "Rank": 1,
      "Tests": [
        {
          "Id": "MT.1020",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [
        "hybrid-identity"
      ],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
          "Note": "With Microsoft Entra Connect or Cloud Sync, exclude the Directory Synchronization Accounts role from policies that target all users.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.pim-notifications",
      "Title": "Send PIM notifications for privileged roles to a monitored mailbox",
      "Summary": "Assignments to and activations of highly privileged roles email a security mailbox as well as the default recipients.",
      "Product": "entra",
      "Goals": [
        "privileged-access"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 2,
      "Tests": [
        {
          "Id": "CISA.MS.AAD.7.9",
          "Result": "Failed"
        },
        {
          "Id": "CISA.MS.AAD.7.8",
          "Result": "Passed"
        },
        {
          "Id": "CISA.MS.AAD.7.7",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-change-default-settings",
          "Note": "Each role's PIM settings can copy assignment and activation emails to extra recipients, such as a mailbox the security team watches.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "intune.mark-unassigned-noncompliant",
      "Title": "Mark devices with no compliance policy as not compliant",
      "Summary": "A device that no compliance policy covers can't pass Conditional Access by default.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 3,
      "Tests": [
        {
          "Id": "CIS.M365.4.1",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1054",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-security/compliance/overview",
          "Note": "When Conditional Access uses compliance, review the tenant setting that decides how devices with no compliance policy are marked.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.emergency-access-excluded",
      "Title": "Exclude emergency access accounts from Conditional Access",
      "Summary": "Emergency access accounts can still sign in when a Conditional Access policy goes wrong.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa",
        "token-protection"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-all",
        "entra.phishing-resistant-admins",
        "entra.ca-require-managed-device",
        "entra.ca-require-managed-device-admins",
        "entra.ca-sign-in-risk",
        "entra.ca-block-unknown-platforms"
      ],
      "Rank": 4,
      "Tests": [
        {
          "Id": "MT.1034",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1005",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.emergency-access-accounts"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access",
          "Note": "Create the accounts, then exclude them, best through one group, from every enforced policy that can block or limit sign-in. Report-only policies need no exclusion.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.hybrid-join",
      "Title": "Domain-joined Windows PCs are hybrid joined to Microsoft Entra ID",
      "Summary": "Windows PCs joined to on-premises Active Directory also have a Microsoft Entra device identity that Conditional Access can use.",
      "Product": "entra",
      "Goals": [
        "managed-devices"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.ca-require-managed-device",
        "entra.ca-require-managed-device-admins"
      ],
      "Rank": 5,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [
        "hybrid-identity"
      ],
      "Rollout": [
        "Turn on hybrid join for a pilot group of varied devices first.",
        "Then turn it on for every computer that should be hybrid joined."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/devices/how-to-hybrid-join",
          "Note": "Hybrid join needs Microsoft Entra Connect syncing the computer objects with their device attributes, and the device setting that lets users register devices.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/devices/hybrid-join-plan",
          "Note": "Roll hybrid join out to a pilot group with targeted deployment before the whole organization.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No check yet. Graph lists the devices that are hybrid joined, but not the domain-joined PCs that are not."
    },
    {
      "Id": "intune.compliance-policies",
      "Title": "Assign a compliance policy for each platform in use",
      "Summary": "Intune can mark a device compliant only when a compliance policy covers its platform.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "defender-device-risk"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "intune.devices-compliant",
        "entra.ca-require-managed-device-admins"
      ],
      "Rank": 6,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-security/compliance/overview",
          "Note": "Compliance policies set the rules each platform's devices must meet, and Conditional Access acts on the compliance state they produce.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/intune/device-security/conditional-access-integration/device-based-policies",
          "Note": "Device-based Conditional Access starts with compliance policies, one per platform, because the policy can only act on the status they report.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24541 to ZTA.24547) once its results can name steps."
    },
    {
      "Id": "entra.certificate-based-auth",
      "Title": "Configure Microsoft Entra certificate-based authentication",
      "Summary": "Users can sign in with a smart card or certificate that Microsoft Entra ID accepts as multifactor.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-registered-all",
        "entra.phishing-resistant-registered-admins"
      ],
      "Rank": 7,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication",
          "Note": "Certificate-based authentication takes more setup than passkeys, so Learn suggests it only where it is needed.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths",
          "Note": "Only multifactor certificate-based authentication is part of the phishing-resistant strength.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester or Zero Trust Assessment check yet."
    },
    {
      "Id": "intune.macos-platform-sso",
      "Title": "Configure Platform SSO with the Secure Enclave key on macOS",
      "Summary": "Mac users sign in with a hardware-bound key that counts as a phishing-resistant method.",
      "Product": "intune",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-registered-all",
        "entra.phishing-resistant-registered-admins"
      ],
      "Rank": 8,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-configuration/settings-catalog/configure-platform-sso-macos",
          "Note": "Platform SSO is set with an Intune settings catalog policy, best assigned as users enroll their Macs. Secure Enclave is the recommended method.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24568) once its results can name steps."
    },
    {
      "Id": "defender.dkim",
      "Title": "Sign outbound mail with DKIM for every custom domain",
      "Summary": "Mail from your custom domains carries a DKIM signature that matches the From domain and survives forwarding.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "Unknown",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "defender.dmarc-reject",
        "defender.dmarc-enforce"
      ],
      "Rank": 9,
      "Tests": [
        {
          "Id": "CISA.MS.EXO.3.1",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        },
        {
          "Id": "CIS.M365.2.1.9",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        },
        {
          "Id": "ORCA.108",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        },
        {
          "Id": "ORCA.108.1",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Read the two CNAME values for the domain from the Defender portal or Get-DkimSigningConfig.",
        "Create both selector CNAME records at the DNS host and wait until Microsoft 365 detects them.",
        "Turn on DKIM signing for the domain and confirm that its status shows it is signing."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-dkim-configure",
          "Note": "Custom domains aren't signed until both selector CNAME records exist and signing is on. onmicrosoft.com is signed already, and parked domains need no DKIM.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "defender.spf",
      "Title": "Publish an SPF record for every domain that sends mail",
      "Summary": "Receiving servers can check that mail from your domains comes from Microsoft 365 or another sender you list.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "Unknown",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "defender.dmarc-reject",
        "defender.dmarc-enforce"
      ],
      "Rank": 10,
      "Tests": [
        {
          "Id": "CISA.MS.EXO.2.2",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        },
        {
          "Id": "CIS.M365.2.1.8",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "List every system that sends as the domain: Microsoft 365, on-premises servers and third-party services.",
        "Publish one SPF TXT record per sending domain and subdomain, and keep it under ten DNS lookups.",
        "Give domains that never send mail the record v=spf1 -all."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure",
          "Note": "Each custom domain and sending subdomain needs one SPF TXT record naming Microsoft 365 and any other senders. onmicrosoft.com is covered already.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.emergency-access-accounts",
      "Title": "Keep at least two emergency access accounts with permanent Global Administrator",
      "Summary": "Cloud-only break-glass accounts can always sign in and administer the tenant, even when every other admin role is eligible.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa",
        "privileged-access",
        "token-protection"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 11,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access",
          "Note": "Create two or more cloud-only accounts on the onmicrosoft.com domain, and in PIM give them Global Administrator as a permanent active assignment, not an eligible one.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-deployment-plan",
          "Note": "The plan leaves no permanent active privileged assignments except the emergency access accounts, which keep Global Administrator.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.21835) once its results can name steps."
    },
    {
      "Id": "entra.trusted-named-locations",
      "Title": "Mark known networks as trusted named locations",
      "Summary": "ID Protection treats sign-ins from the organization's own networks as less risky, which cuts false positives.",
      "Product": "entra",
      "Goals": [
        "risk-policies"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 12,
      "Tests": [
        {
          "Id": "CIS.M365.5.2.2.14",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies",
          "Note": "Some risk detections use trusted locations to cut false positives, so mark office and VPN ranges as trusted before sign-in risk prompts start.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "intune.automatic-enrollment",
      "Title": "Turn on automatic Intune enrollment for Windows",
      "Summary": "Windows devices enroll in Intune when users join or register them in Microsoft Entra ID.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 13,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-enrollment/windows/enable-automatic-mdm",
          "Note": "Automatic enrollment enrolls Windows devices in Intune as they join or register with Microsoft Entra ID.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24546) once its results can name steps."
    },
    {
      "Id": "entra.phishing-resistant-registered-all",
      "Title": "Users have a phishing-resistant method registered",
      "Summary": "Users can already sign in with a passkey, Windows Hello for Business, Platform SSO or a certificate on the devices they use.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-all"
      ],
      "Rank": 14,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [
        [
          "entra.passkeys-enabled",
          "intune.windows-hello",
          "entra.certificate-based-auth",
          "intune.macos-platform-sso"
        ]
      ],
      "RecommendedFirst": [
        "entra.temporary-access-pass"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication",
          "Note": "Users register a portable credential first and device-bound ones after. New users and users with no MFA method start with a Temporary Access Pass.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths",
          "Note": "A strength can be met only with methods the tenant has enabled and the user has registered. Any method in the phishing-resistant strength will do.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. A measure is planned, and the Zero Trust Assessment pack checks it (ZTA.21801) once its results can name steps."
    },
    {
      "Id": "intune.devices-compliant",
      "Title": "Devices that sign in are compliant",
      "Summary": "Most devices that sign in are enrolled in Intune and marked compliant, so requiring compliance blocks few users.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Unconfirmed",
      "BlockedBy": [],
      "Unconfirmed": [
        "intune.compliance-policies"
      ],
      "Unlocks": [
        "entra.ca-require-managed-device"
      ],
      "Rank": 15,
      "Tests": [],
      "Earlier": null,
      "Measure": {
        "Key": "devices-compliant",
        "Count": 412,
        "Total": 580,
        "Share": 71,
        "MinimumShare": 95,
        "Met": false,
        "ReadAt": "2026-11-02T09:52:10+11:00",
        "Caveat": "Devices that aren't registered or joined in Microsoft Entra ID can't be counted.",
        "ObjectCount": 168,
        "Objects": [
          {
            "Type": "Device",
            "Id": "device-0",
            "DisplayName": "DESKTOP-4KQ2M1"
          },
          {
            "Type": "Device",
            "Id": "device-1",
            "DisplayName": "LAPTOP-ADELE"
          },
          {
            "Type": "Device",
            "Id": "device-2",
            "DisplayName": "LAPTOP-ALEXW"
          },
          {
            "Type": "Device",
            "Id": "device-3",
            "DisplayName": "MAC-BOBLEAF"
          },
          {
            "Type": "Device",
            "Id": "device-4",
            "DisplayName": "iPhone (Diego)"
          },
          {
            "Type": "Device",
            "Id": "device-5",
            "DisplayName": "DESKTOP-FIN-07"
          },
          {
            "Type": "Device",
            "Id": "device-6",
            "DisplayName": "LAPTOP-GAEL"
          },
          {
            "Type": "Device",
            "Id": "device-7",
            "DisplayName": "Pixel 8 (Isaiah)"
          },
          {
            "Type": "Device",
            "Id": "device-8",
            "DisplayName": "DESKTOP-HR-02"
          },
          {
            "Type": "Device",
            "Id": "device-9",
            "DisplayName": "LAPTOP-LEEGU"
          },
          {
            "Type": "Device",
            "Id": "device-10",
            "DisplayName": "MAC-MEGAN"
          },
          {
            "Type": "Device",
            "Id": "device-11",
            "DisplayName": "DESKTOP-RECEPT"
          },
          {
            "Type": "Device",
            "Id": "device-12",
            "DisplayName": "SURFACE-NESTOR"
          },
          {
            "Type": "Device",
            "Id": "device-13",
            "DisplayName": "LAPTOP-PATTI"
          }
        ],
        "ReasonCode": null
      },
      "Requires": [
        "intune.compliance-policies"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "intune.automatic-enrollment"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant",
          "Note": "Only devices registered in Microsoft Entra ID and enrolled in Intune can be marked compliant, so unenrolled devices fail a compliant-device policy.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "intune.windows-hello",
      "Title": "Configure Windows Hello for Business on Windows devices",
      "Summary": "Users set up a Windows Hello for Business key on their PCs and sign in with a PIN or biometric.",
      "Product": "intune",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-registered-all",
        "entra.phishing-resistant-registered-admins"
      ],
      "Rank": 16,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.passkeys-enabled"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication",
          "Note": "Give users a portable passkey first. They can then use it to set up Windows Hello for Business on each PC.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/intune/solutions/passwordless",
          "Note": "Intune gets Windows devices ready for Windows Hello for Business by delivering its policy settings at enrollment and keeping them in place after.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24551) once its results can name steps."
    },
    {
      "Id": "defender.dmarc-enforce",
      "Title": "Enforce DMARC with reporting on every domain",
      "Summary": "Receivers quarantine or reject mail that fails DMARC for any of your domains, and send you aggregate and failure reports.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Unconfirmed",
      "BlockedBy": [],
      "Unconfirmed": [
        "defender.spf",
        "defender.dkim"
      ],
      "Unlocks": [],
      "Rank": 17,
      "Tests": [
        {
          "Id": "CIS.M365.2.1.10",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "defender.spf",
        "defender.dkim"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "defender.dmarc-published",
        "defender.spf-hard-fail"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Start with a low-volume domain or subdomain, and leave the parent domain for last.",
        "Move from p=none to p=quarantine, and raise pct in steps from 10 to 100 while you watch the reports.",
        "Keep the rua and ruf addresses in the record so that failures go on being reported."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure",
          "Note": "An enforcing policy acts on mail that fails both aligned SPF and DKIM. Set both up on every sending domain first, and run p=none with reports before you enforce.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/defender-office-365/mdo-deployment-guide",
          "Note": "The deployment guide sets up SPF, DKIM and DMARC in that order, and expects quarantine or reject with report addresses on each custom domain.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure",
          "Note": "With ~all, DMARC in effect ignores SPF failures on mail that has no DKIM signature. Ending SPF in -all lets the policy act on that mail.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "defender.dmarc-published",
      "Title": "Publish a DMARC record for every domain",
      "Summary": "Every domain, onmicrosoft.com included, has a DMARC record, so receivers check alignment and report who sends mail as you.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "Unknown",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 18,
      "Tests": [
        {
          "Id": "CISA.MS.EXO.4.1",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "defender.spf",
        "defender.dkim"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Publish v=DMARC1; p=none with a rua address that a dedicated mailbox or a reporting service reads.",
        "Add the record for the onmicrosoft.com domain in the Microsoft 365 admin center.",
        "Read the aggregate reports regularly to find senders that fail SPF or DKIM."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure",
          "Note": "Set up SPF and DKIM before DMARC, which passes only on aligned SPF or DKIM. A p=none record changes no delivery and starts the reports.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure",
          "Note": "The onmicrosoft.com domain needs a DMARC record of its own, added in the Microsoft 365 admin center.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.phishing-resistant-registered-admins",
      "Title": "Administrators have a phishing-resistant method registered",
      "Summary": "Every account that holds an admin role can already sign in with a passkey, Windows Hello for Business, Platform SSO or a certificate.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-admins"
      ],
      "Rank": 19,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [
        [
          "entra.passkeys-enabled",
          "intune.windows-hello",
          "entra.certificate-based-auth",
          "intune.macos-platform-sso"
        ]
      ],
      "RecommendedFirst": [
        "entra.temporary-access-pass"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strengths",
          "Note": "A strength can be met only with methods the tenant has enabled and the user has registered. Any method in the phishing-resistant strength will do.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-admin-phish-resistant-mfa",
          "Note": "Admins register a phishing-resistant method before the policy is on, using a Temporary Access Pass if they have no MFA method yet.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.21782) once its results can name steps."
    },
    {
      "Id": "defender.dmarc-reject",
      "Title": "Reject mail that fails DMARC on every domain",
      "Summary": "Receivers reject mail that claims to come from your domains but fails DMARC, parked domains and onmicrosoft.com included.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "Unknown",
      "Reason": null,
      "Readiness": "Unconfirmed",
      "BlockedBy": [],
      "Unconfirmed": [
        "defender.spf",
        "defender.dkim"
      ],
      "Unlocks": [],
      "Rank": 20,
      "Tests": [
        {
          "Id": "CISA.MS.EXO.4.2",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        },
        {
          "Id": "MT.1182",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "defender.spf",
        "defender.dkim"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "defender.dmarc-enforce"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "After a period at p=quarantine, move each domain to p=reject, raising pct in steps if needed.",
        "Do the subdomains in order of volume, then the parent domain.",
        "Set parked domains and an unused onmicrosoft.com domain to p=reject straight away."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-dmarc-configure",
          "Note": "The target is p=reject on every domain, reached after a period at quarantine. Parked domains and an onmicrosoft.com domain that sends nothing can go straight there.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "defender.spf-hard-fail",
      "Title": "End every SPF record with -all",
      "Summary": "Receivers are told to reject mail from servers that the SPF record doesn't list, so DMARC can act on spoofed mail with no signature.",
      "Product": "defender",
      "Goals": [
        "email-authentication"
      ],
      "Status": "Unknown",
      "Reason": null,
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 21,
      "Tests": [
        {
          "Id": "ORCA.235",
          "Result": "Skipped",
          "ReasonCode": "ServiceNotConnected"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "defender.spf",
        "defender.dmarc-published"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Keep ~all until the DMARC aggregate reports show no legitimate source failing SPF.",
        "Change the qualifier to -all one domain at a time, keeping one SPF record per domain."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-about",
          "Note": "Start with the senders you know and ~all, add the others as you find them, then move to -all, so mail from a sender you missed isn't bounced.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/defender-office-365/email-authentication-spf-configure",
          "Note": "DMARC reports show which servers send as the domain, so publish a DMARC record early and read its reports before -all rejects a source nobody listed.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-require-managed-device",
      "Title": "Require a compliant or hybrid joined device in Conditional Access",
      "Summary": "Sign-ins from devices that are neither compliant in Intune nor hybrid joined are blocked.",
      "Product": "entra",
      "Goals": [
        "managed-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "Unconfirmed": [
        "entra.hybrid-join"
      ],
      "Unlocks": [],
      "Rank": 22,
      "Tests": [
        {
          "Id": "CISA.MS.AAD.3.7",
          "Result": "Failed"
        },
        {
          "Id": "CIS.M365.5.2.2.9",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "RequiresOneOf": [
        [
          "intune.devices-compliant",
          "entra.hybrid-join"
        ]
      ],
      "RecommendedFirst": [
        "intune.mark-unassigned-noncompliant",
        "entra.ca-require-managed-device-admins"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy in report-only mode and review the sign-ins it would block.",
        "Turn it on for a pilot group.",
        "Turn it on for all users, keeping the emergency access and directory sync accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant",
          "Note": "Either signal will do. Compliance needs devices registered and enrolled in Intune; the hybrid option covers only domain-joined Windows PCs that are hybrid joined.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-alt-all-users-compliant-hybrid-or-mfa",
          "Note": "The all-users template excludes the emergency access accounts and, with Connect or Cloud Sync, the directory sync accounts, and starts in report-only.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
          "Note": "Organizations not ready to require managed devices for everyone can start with the policy for administrators.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-require-managed-device-admins",
      "Title": "Require a compliant or hybrid joined device for administrators",
      "Summary": "Accounts in admin roles can sign in only from a device that Intune marks compliant or that is hybrid joined.",
      "Product": "entra",
      "Goals": [
        "managed-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded"
      ],
      "Unconfirmed": [
        "intune.compliance-policies",
        "entra.hybrid-join"
      ],
      "Unlocks": [],
      "Rank": 23,
      "Tests": [
        {
          "Id": "MT.1014",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.emergency-access-excluded"
      ],
      "RequiresOneOf": [
        [
          "intune.compliance-policies",
          "entra.hybrid-join"
        ]
      ],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy for the admin roles in report-only mode and review the sign-ins it would block.",
        "Turn it on, keeping the emergency access accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-alt-admin-device-compliand-hybrid",
          "Note": "The hybrid joined option works only for devices that are already hybrid joined, and compliance needs Intune policies. Exclude emergency access accounts; start in report-only.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-sign-in-risk",
      "Title": "Require MFA for medium and high sign-in risk in Conditional Access",
      "Summary": "Sign-ins that ID Protection rates medium or high risk need a fresh MFA, which also clears the sign-in risk.",
      "Product": "entra",
      "Goals": [
        "risk-policies"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded"
      ],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 24,
      "Tests": [
        {
          "Id": "CIS.M365.5.2.2.7",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1012",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.mfa-registered",
        "entra.emergency-access-excluded"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.ca-exclude-sync-accounts",
        "entra.trusted-named-locations"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy in report-only mode and review the sign-ins it would affect.",
        "Turn it on for a pilot group.",
        "Turn it on for all users, keeping the emergency access accounts excluded.",
        "Keep it as its own policy, with no user risk condition."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-risk-based-sign-in",
          "Note": "A user can't register MFA during a risky sign-in, so an unregistered user is blocked instead of prompted. Exclude emergency access accounts and service accounts.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies",
          "Note": "Keep sign-in risk and user risk in separate policies. For medium and high sign-in risk, ask for MFA and reauthentication every time.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-protection/how-to-deploy-identity-protection",
          "Note": "Start sign-in risk policies with a subset of users before the whole organization.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.phishing-resistant-all",
      "Title": "Require phishing-resistant MFA for all users",
      "Summary": "Every user must sign in with a phishing-resistant method to reach any resource.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "Unconfirmed": [
        "entra.phishing-resistant-registered-all"
      ],
      "Unlocks": [],
      "Rank": 25,
      "Tests": [
        {
          "Id": "ASD.ISM-1872",
          "Result": "Failed"
        },
        {
          "Id": "CISA.MS.AAD.3.1",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.phishing-resistant-registered-all",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.phishing-resistant-admins"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the all-users policy in report-only mode early, before registration campaigns, to see which sign-ins it would block.",
        "Enforce it in waves, one policy per device platform, for groups of users who are ready.",
        "Once almost every user is in a ready group, turn the all-users policy on and remove the per-platform policies."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/concept-authentication-strength-how-it-works",
          "Note": "A user who hasn't registered a method the strength accepts can't reach the resource, so get users registered before you enforce it.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication",
          "Note": "Enforcement typically starts with admins and then reaches other users in waves by device platform, with the emergency access accounts excluded.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-mfa-strength",
          "Note": "With Connect or Cloud Sync, exclude the Directory Synchronization Accounts role from all-user authentication strength policies.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-block-unknown-platforms",
      "Title": "Block access from unknown or unsupported device platforms",
      "Summary": "Sign-ins from device platforms that Conditional Access doesn't recognize are blocked, so platform-based policies can't be sidestepped.",
      "Product": "entra",
      "Goals": [
        "token-protection"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded"
      ],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 26,
      "Tests": [
        {
          "Id": "MT.1015",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.emergency-access-excluded"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy in report-only mode and review the sign-ins it would block.",
        "Turn it on, keeping the emergency access accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-unknown-unsupported",
          "Note": "Platform conditions read the user agent, so use this block alongside other policies. Exclude the emergency access accounts.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.phishing-resistant-admins",
      "Title": "Require phishing-resistant MFA for administrator roles",
      "Summary": "Accounts in admin roles must sign in with a phishing-resistant method to reach any resource.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Blocked",
      "BlockedBy": [
        "entra.emergency-access-excluded"
      ],
      "Unconfirmed": [
        "entra.phishing-resistant-registered-admins"
      ],
      "Unlocks": [],
      "Rank": 27,
      "Tests": [
        {
          "Id": "CIS.M365.5.2.2.5",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": {
        "Status": "NotDone",
        "ExecutedAt": "2026-10-26T09:10:44+11:00",
        "File": "TestResults-2026-10-26-091044.json"
      },
      "Measure": null,
      "Requires": [
        "entra.phishing-resistant-registered-admins",
        "entra.emergency-access-excluded"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy for the admin roles in report-only mode and review the sign-ins it would block.",
        "Turn it on for admins on Windows and iOS first, then macOS and Android.",
        "Keep the emergency access accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-admin-phish-resistant-mfa",
          "Note": "Admins without a phishing-resistant method are locked out when the policy turns on, which can lock you out of the tenant. Exclude the emergency access accounts.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.mfa-registered",
      "Title": "Enabled member users are registered for MFA",
      "Summary": "Users already have an MFA method that policy allows, so policies that ask for MFA or self-remediation don't leave them stuck.",
      "Product": "entra",
      "Goals": [
        "risk-policies"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.ca-sign-in-risk"
      ],
      "Rank": 28,
      "Tests": [],
      "Earlier": null,
      "Measure": {
        "Key": "mfa-capable",
        "Count": 1187,
        "Total": 1213,
        "Share": 98,
        "MinimumShare": 95,
        "Met": true,
        "ReadAt": "2026-11-02T09:52:12+11:00",
        "Caveat": "Leaves out guests and the emergency access and directory sync accounts.",
        "ObjectCount": 26,
        "Objects": [
          {
            "Type": "User",
            "Id": "user-0",
            "DisplayName": "Bagul Atayewa"
          },
          {
            "Type": "User",
            "Id": "user-1",
            "DisplayName": "Damien Bowden"
          },
          {
            "Type": "User",
            "Id": "user-2",
            "DisplayName": "Joshua Fernando"
          },
          {
            "Type": "User",
            "Id": "user-3",
            "DisplayName": "Tyler Chan"
          }
        ],
        "ReasonCode": null
      },
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/id-protection/howto-identity-protection-configure-risk-policies",
          "Note": "Users need to register for MFA before a risk policy asks them to remediate. Those who haven't stay blocked until an admin steps in.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.passkeys-enabled",
      "Title": "Enable passkeys (FIDO2) in the Authentication methods policy",
      "Summary": "Users in scope can register a passkey on a security key, in Microsoft Authenticator or with a passkey provider.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.phishing-resistant-registered-all",
        "entra.phishing-resistant-registered-admins"
      ],
      "Rank": 29,
      "Tests": [
        {
          "Id": "EIDSCA.AF01",
          "Result": "Passed"
        },
        {
          "Id": "EIDSCA.AF02",
          "Result": "Passed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Enable it for a pilot group that includes admins, and watch registrations in the Authentication methods activity report.",
        "Give admins a passkey profile that allows only device-bound passkeys.",
        "Widen the targets group by group."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/how-to-authentication-passkeys-fido2",
          "Note": "Turn on Passkey (FIDO2) for the users who will register and allow self-service setup, or they can't add a passkey in Security info.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.temporary-access-pass",
      "Title": "Enable Temporary Access Pass",
      "Summary": "Admins can issue a time-limited pass, so a user with no MFA method can sign in and register a passwordless one.",
      "Product": "entra",
      "Goals": [
        "phishing-resistant-mfa"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 30,
      "Tests": [
        {
          "Id": "EIDSCA.AT01",
          "Result": "Passed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/authentication/howto-authentication-temporary-access-pass",
          "Note": "A pass works only for users in scope of the Temporary Access Pass method, so enable it and target the users who onboard or recover with it.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.pim-approval-global-admin",
      "Title": "Require approval to activate Global Administrator in PIM",
      "Summary": "Each Global Administrator activation waits for a named approver before it takes effect.",
      "Product": "entra",
      "Goals": [
        "privileged-access"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 31,
      "Tests": [
        {
          "Id": "CISA.MS.AAD.7.6",
          "Result": "Passed"
        },
        {
          "Id": "CIS.M365.5.3.4",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.emergency-access-accounts"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Name at least two approvers before you require approval."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-how-to-change-default-settings",
          "Note": "With approval on, no named approver and no active Global or Privileged Role Administrator, nobody can approve. Permanent emergency access accounts avoid that lock-out.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-deployment-plan",
          "Note": "The plan's example settings have another Global Administrator approve each Global Administrator activation.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.pim-eligible-roles",
      "Title": "Make privileged role assignments eligible in PIM",
      "Summary": "Administrators hold privileged roles as eligible assignments they activate when needed. Only the emergency access accounts stay permanently active.",
      "Product": "entra",
      "Goals": [
        "privileged-access"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 32,
      "Tests": [
        {
          "Id": "ASD.ISM-1649",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "CISA.MS.AAD.7.5",
          "Result": "Passed"
        },
        {
          "Id": "CIS.M365.5.3.1",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1031",
          "Result": "Passed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "entra.emergency-access-accounts"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.pim-approval-global-admin",
        "entra.pim-notifications"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Pilot with a small group of admins, and check that activation, approval and notifications work as planned.",
        "Make Global Administrator and Security Administrator assignments eligible first, then the other privileged roles.",
        "Remove service principals from privileged roles or give them time-bound active assignments, since they can't be eligible.",
        "If activation fails in production, make the affected assignments active again, then fix the settings."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-getting-started",
          "Note": "For Microsoft Entra roles, configure the role settings first, then give eligible assignments, then let users activate them just in time.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access",
          "Note": "If every Global and Privileged Role Administrator is eligible and activation needs an approver nobody can be, the tenant is locked out. Keep emergency accounts active.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-deployment-plan",
          "Note": "Pilot with test users, convert the most privileged roles first, and roll back by making assignments active again if activation fails.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-require-compliant-device",
      "Title": "Require a compliant device in Conditional Access",
      "Summary": "Sign-ins from devices that Intune does not mark compliant are blocked.",
      "Product": "entra",
      "Goals": [
        "compliant-devices"
      ],
      "Status": "Done",
      "Reason": null,
      "Readiness": null,
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 33,
      "Tests": [
        {
          "Id": "MT.1001",
          "Result": "Passed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "intune.compliance-policies",
        "intune.devices-compliant",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "intune.mark-unassigned-noncompliant"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy in report-only mode and review the sign-ins it would block.",
        "Turn it on for a pilot group.",
        "Turn it on for all users, keeping the emergency access accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
          "Note": "The policy doesn't work as intended without an Intune compliance policy. Create one first, have at least one compliant device, and start in report-only.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant",
          "Note": "A device can be marked compliant only once it is registered in Microsoft Entra ID and enrolled in Intune or a supported partner.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/intune/device-security/conditional-access-integration/device-based-policies",
          "Note": "Intune's guide sets up compliance policies before device-based Conditional Access, and tests the new policy with a small group first.",
          "Reviewed": "2026-11-05"
        }
      ]
    }
  ],
  "Goals": [
    {
      "Id": "compliant-devices",
      "Title": "Require compliant devices",
      "Summary": "Only devices that Intune manages and marks compliant can reach Microsoft 365.",
      "Step": "entra.ca-require-compliant-device",
      "Steps": [
        "intune.compliance-policies",
        "intune.automatic-enrollment",
        "intune.devices-compliant",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "intune.mark-unassigned-noncompliant",
        "entra.ca-require-compliant-device"
      ],
      "Done": 1,
      "Applicable": 8,
      "Status": "InProgress"
    },
    {
      "Id": "managed-devices",
      "Title": "Require managed devices",
      "Summary": "Only devices that Intune marks compliant or that are hybrid joined to Microsoft Entra ID can reach Microsoft 365.",
      "Step": "entra.ca-require-managed-device",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "intune.compliance-policies",
        "intune.automatic-enrollment",
        "intune.devices-compliant",
        "entra.hybrid-join",
        "intune.mark-unassigned-noncompliant",
        "entra.ca-require-managed-device-admins",
        "entra.ca-require-managed-device"
      ],
      "Done": 0,
      "Applicable": 10,
      "Status": "NotStarted"
    },
    {
      "Id": "risk-policies",
      "Title": "Use risk-based Conditional Access",
      "Summary": "Users and sign-ins that ID Protection rates risky must prove themselves with MFA or a secure password change before they get in.",
      "Step": "entra.ca-user-risk",
      "Steps": [
        "entra.mfa-registered",
        "entra.password-writeback",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.remediate-risky-users",
        "entra.password-hash-sync",
        "entra.ca-exclude-sync-accounts",
        "entra.trusted-named-locations",
        "entra.ca-sign-in-risk",
        "entra.ca-user-risk"
      ],
      "Done": 1,
      "Applicable": 6,
      "Status": "InProgress"
    },
    {
      "Id": "phishing-resistant-mfa",
      "Title": "Require phishing-resistant MFA",
      "Summary": "Every user signs in with a passkey, Windows Hello for Business or another method that a phishing site can't replay.",
      "Step": "entra.phishing-resistant-all",
      "Steps": [
        "entra.passkeys-enabled",
        "intune.windows-hello",
        "entra.certificate-based-auth",
        "intune.macos-platform-sso",
        "entra.temporary-access-pass",
        "entra.phishing-resistant-registered-all",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "entra.phishing-resistant-registered-admins",
        "entra.phishing-resistant-admins",
        "entra.phishing-resistant-all"
      ],
      "Done": 2,
      "Applicable": 12,
      "Status": "InProgress"
    },
    {
      "Id": "privileged-access",
      "Title": "Replace standing admin access with PIM",
      "Summary": "Administrators activate privileged roles when they need them, and only the emergency access accounts keep standing access.",
      "Step": "entra.pim-eligible-roles",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.pim-approval-global-admin",
        "entra.pim-notifications",
        "entra.pim-eligible-roles"
      ],
      "Done": 2,
      "Applicable": 4,
      "Status": "InProgress"
    },
    {
      "Id": "token-protection",
      "Title": "Protect sign-in tokens on Windows",
      "Summary": "Sign-in tokens for Exchange, SharePoint and Teams are bound to the Windows device they were issued to, so they can't be replayed elsewhere.",
      "Step": "entra.ca-token-protection-windows",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.windows-devices-registered",
        "entra.ca-block-unknown-platforms",
        "entra.ca-token-protection-windows"
      ],
      "Done": 0,
      "Applicable": 3,
      "Status": "NotStarted"
    },
    {
      "Id": "email-authentication",
      "Title": "Authenticate mail from your domains",
      "Summary": "Receivers can tell real mail from your domains from spoofed mail, and reject the spoofed mail.",
      "Step": "defender.dmarc-reject",
      "Steps": [
        "defender.spf",
        "defender.dkim",
        "defender.dmarc-published",
        "defender.spf-hard-fail",
        "defender.dmarc-enforce",
        "defender.dmarc-reject"
      ],
      "Done": 0,
      "Applicable": 6,
      "Status": "NotStarted"
    },
    {
      "Id": "defender-device-risk",
      "Title": "Use Defender device risk in compliance",
      "Summary": "Devices that Defender for Endpoint rates risky become noncompliant, so the compliant-device Conditional Access policy blocks them.",
      "Step": "intune.compliance-device-risk",
      "Steps": [
        "intune.defender-connector",
        "intune.defender-compliance-evaluation",
        "defender.endpoint-onboarding",
        "intune.compliance-policies",
        "intune.compliance-device-risk"
      ],
      "Done": 0,
      "Applicable": 1,
      "Status": "NotStarted"
    }
  ]
}

export const sampleStepsOne = {
  "Steps": [
    {
      "Id": "entra.ca-exclude-sync-accounts",
      "Title": "Exclude directory sync accounts from Conditional Access",
      "Summary": "The accounts that Microsoft Entra Connect and Cloud Sync use keep syncing when new policies apply.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.ca-require-compliant-device"
      ],
      "Rank": 1,
      "Tests": [
        {
          "Id": "MT.1020",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": {
        "Status": "NotDone",
        "ExecutedAt": "2026-11-02T09:14:02+11:00",
        "File": "TestResults-2026-11-02-091402.json"
      },
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [
        "hybrid-identity"
      ],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
          "Note": "With Microsoft Entra Connect or Cloud Sync, exclude the Directory Synchronization Accounts role from policies that target all users.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "intune.compliance-policies",
      "Title": "Assign a compliance policy for each platform in use",
      "Summary": "Intune can mark a device compliant only when a compliance policy covers its platform.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "defender-device-risk"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.ca-require-compliant-device",
        "intune.devices-compliant"
      ],
      "Rank": 2,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-security/compliance/overview",
          "Note": "Compliance policies set the rules each platform's devices must meet, and Conditional Access acts on the compliance state they produce.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/intune/device-security/conditional-access-integration/device-based-policies",
          "Note": "Device-based Conditional Access starts with compliance policies, one per platform, because the policy can only act on the status they report.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24541 to ZTA.24547) once its results can name steps."
    },
    {
      "Id": "entra.emergency-access-accounts",
      "Title": "Keep at least two emergency access accounts with permanent Global Administrator",
      "Summary": "Cloud-only break-glass accounts can always sign in and administer the tenant, even when every other admin role is eligible.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa",
        "privileged-access",
        "token-protection"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 3,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access",
          "Note": "Create two or more cloud-only accounts on the onmicrosoft.com domain, and in PIM give them Global Administrator as a permanent active assignment, not an eligible one.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/id-governance/privileged-identity-management/pim-deployment-plan",
          "Note": "The plan leaves no permanent active privileged assignments except the emergency access accounts, which keep Global Administrator.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.21835) once its results can name steps."
    },
    {
      "Id": "intune.automatic-enrollment",
      "Title": "Turn on automatic Intune enrollment for Windows",
      "Summary": "Windows devices enroll in Intune when users join or register them in Microsoft Entra ID.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotChecked",
      "Reason": "NoCheck",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 4,
      "Tests": [],
      "Earlier": null,
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-enrollment/windows/enable-automatic-mdm",
          "Note": "Automatic enrollment enrolls Windows devices in Intune as they join or register with Microsoft Entra ID.",
          "Reviewed": "2026-11-05"
        }
      ],
      "Unchecked": "No Maester check yet. The Zero Trust Assessment pack checks it (ZTA.24546) once its results can name steps."
    },
    {
      "Id": "intune.mark-unassigned-noncompliant",
      "Title": "Mark devices with no compliance policy as not compliant",
      "Summary": "A device that no compliance policy covers can't pass Conditional Access by default.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [],
      "Rank": 5,
      "Tests": [
        {
          "Id": "CIS.M365.4.1",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1054",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": {
        "Status": "Done",
        "ExecutedAt": "2026-10-19T08:40:31+11:00",
        "File": "TestResults-2026-10-19-084031.json"
      },
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/intune/device-security/compliance/overview",
          "Note": "When Conditional Access uses compliance, review the tenant setting that decides how devices with no compliance policy are marked.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.emergency-access-excluded",
      "Title": "Exclude emergency access accounts from Conditional Access",
      "Summary": "Emergency access accounts can still sign in when a Conditional Access policy goes wrong.",
      "Product": "entra",
      "Goals": [
        "compliant-devices",
        "managed-devices",
        "risk-policies",
        "phishing-resistant-mfa",
        "token-protection"
      ],
      "Status": "NotChecked",
      "Reason": "NotSelected",
      "Readiness": "Ready",
      "BlockedBy": [],
      "Unconfirmed": [],
      "Unlocks": [
        "entra.ca-require-compliant-device"
      ],
      "Rank": 6,
      "Tests": [
        {
          "Id": "MT.1034",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        },
        {
          "Id": "MT.1005",
          "Result": "NotRun",
          "ReasonCode": "NotInRun"
        }
      ],
      "Earlier": {
        "Status": "NotDone",
        "ExecutedAt": "2026-11-02T09:14:02+11:00",
        "File": "TestResults-2026-11-02-091402.json"
      },
      "Measure": null,
      "Requires": [],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "entra.emergency-access-accounts"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access",
          "Note": "Create the accounts, then exclude them, best through one group, from every enforced policy that can block or limit sign-in. Report-only policies need no exclusion.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "intune.devices-compliant",
      "Title": "Devices that sign in are compliant",
      "Summary": "Most devices that sign in are enrolled in Intune and marked compliant, so requiring compliance blocks few users.",
      "Product": "intune",
      "Goals": [
        "compliant-devices",
        "managed-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Unconfirmed",
      "BlockedBy": [],
      "Unconfirmed": [
        "intune.compliance-policies"
      ],
      "Unlocks": [
        "entra.ca-require-compliant-device"
      ],
      "Rank": 7,
      "Tests": [],
      "Earlier": null,
      "Measure": {
        "Key": "devices-compliant",
        "Count": 412,
        "Total": 580,
        "Share": 71,
        "MinimumShare": 95,
        "Met": false,
        "ReadAt": "2026-11-02T09:52:10+11:00",
        "Caveat": "Devices that aren't registered or joined in Microsoft Entra ID can't be counted.",
        "ObjectCount": 168,
        "Objects": [
          {
            "Type": "Device",
            "Id": "device-0",
            "DisplayName": "DESKTOP-4KQ2M1"
          },
          {
            "Type": "Device",
            "Id": "device-1",
            "DisplayName": "LAPTOP-ADELE"
          },
          {
            "Type": "Device",
            "Id": "device-2",
            "DisplayName": "LAPTOP-ALEXW"
          },
          {
            "Type": "Device",
            "Id": "device-3",
            "DisplayName": "MAC-BOBLEAF"
          },
          {
            "Type": "Device",
            "Id": "device-4",
            "DisplayName": "iPhone (Diego)"
          },
          {
            "Type": "Device",
            "Id": "device-5",
            "DisplayName": "DESKTOP-FIN-07"
          },
          {
            "Type": "Device",
            "Id": "device-6",
            "DisplayName": "LAPTOP-GAEL"
          },
          {
            "Type": "Device",
            "Id": "device-7",
            "DisplayName": "Pixel 8 (Isaiah)"
          },
          {
            "Type": "Device",
            "Id": "device-8",
            "DisplayName": "DESKTOP-HR-02"
          },
          {
            "Type": "Device",
            "Id": "device-9",
            "DisplayName": "LAPTOP-LEEGU"
          },
          {
            "Type": "Device",
            "Id": "device-10",
            "DisplayName": "MAC-MEGAN"
          },
          {
            "Type": "Device",
            "Id": "device-11",
            "DisplayName": "DESKTOP-RECEPT"
          },
          {
            "Type": "Device",
            "Id": "device-12",
            "DisplayName": "SURFACE-NESTOR"
          },
          {
            "Type": "Device",
            "Id": "device-13",
            "DisplayName": "LAPTOP-PATTI"
          }
        ],
        "ReasonCode": null
      },
      "Requires": [
        "intune.compliance-policies"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "intune.automatic-enrollment"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant",
          "Note": "Only devices registered in Microsoft Entra ID and enrolled in Intune can be marked compliant, so unenrolled devices fail a compliant-device policy.",
          "Reviewed": "2026-11-05"
        }
      ]
    },
    {
      "Id": "entra.ca-require-compliant-device",
      "Title": "Require a compliant device in Conditional Access",
      "Summary": "Sign-ins from devices that Intune does not mark compliant are blocked.",
      "Product": "entra",
      "Goals": [
        "compliant-devices"
      ],
      "Status": "NotDone",
      "Reason": null,
      "Readiness": "Blocked",
      "BlockedBy": [
        "intune.devices-compliant"
      ],
      "Unconfirmed": [
        "intune.compliance-policies",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "Unlocks": [],
      "Rank": 8,
      "Tests": [
        {
          "Id": "MT.1001",
          "Result": "Failed"
        }
      ],
      "Earlier": null,
      "Measure": null,
      "Requires": [
        "intune.compliance-policies",
        "intune.devices-compliant",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts"
      ],
      "RequiresOneOf": [],
      "RecommendedFirst": [
        "intune.mark-unassigned-noncompliant"
      ],
      "Conflicts": [],
      "OnlyWhen": [],
      "Rollout": [
        "Create the policy in report-only mode and review the sign-ins it would block.",
        "Turn it on for a pilot group.",
        "Turn it on for all users, keeping the emergency access accounts excluded."
      ],
      "Sources": [
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/policy-all-users-device-compliance",
          "Note": "The policy doesn't work as intended without an Intune compliance policy. Create one first, have at least one compliant device, and start in report-only.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant",
          "Note": "A device can be marked compliant only once it is registered in Microsoft Entra ID and enrolled in Intune or a supported partner.",
          "Reviewed": "2026-11-05"
        },
        {
          "Url": "https://learn.microsoft.com/intune/device-security/conditional-access-integration/device-based-policies",
          "Note": "Intune's guide sets up compliance policies before device-based Conditional Access, and tests the new policy with a small group first.",
          "Reviewed": "2026-11-05"
        }
      ]
    }
  ],
  "Goals": [
    {
      "Id": "compliant-devices",
      "Title": "Require compliant devices",
      "Summary": "Only devices that Intune manages and marks compliant can reach Microsoft 365.",
      "Step": "entra.ca-require-compliant-device",
      "Steps": [
        "intune.compliance-policies",
        "intune.automatic-enrollment",
        "intune.devices-compliant",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "intune.mark-unassigned-noncompliant",
        "entra.ca-require-compliant-device"
      ],
      "Done": 0,
      "Applicable": 8,
      "Status": "NotStarted"
    },
    {
      "Id": "managed-devices",
      "Title": "Require managed devices",
      "Summary": "Only devices that Intune marks compliant or that are hybrid joined to Microsoft Entra ID can reach Microsoft 365.",
      "Step": "entra.ca-require-managed-device",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "intune.compliance-policies",
        "intune.automatic-enrollment",
        "intune.devices-compliant",
        "entra.hybrid-join",
        "intune.mark-unassigned-noncompliant",
        "entra.ca-require-managed-device-admins",
        "entra.ca-require-managed-device"
      ],
      "Done": 0,
      "Applicable": 7,
      "Status": "NotStarted"
    },
    {
      "Id": "risk-policies",
      "Title": "Use risk-based Conditional Access",
      "Summary": "Users and sign-ins that ID Protection rates risky must prove themselves with MFA or a secure password change before they get in.",
      "Step": "entra.ca-user-risk",
      "Steps": [
        "entra.mfa-registered",
        "entra.password-writeback",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.remediate-risky-users",
        "entra.password-hash-sync",
        "entra.ca-exclude-sync-accounts",
        "entra.trusted-named-locations",
        "entra.ca-sign-in-risk",
        "entra.ca-user-risk"
      ],
      "Done": 0,
      "Applicable": 3,
      "Status": "NotStarted"
    },
    {
      "Id": "phishing-resistant-mfa",
      "Title": "Require phishing-resistant MFA",
      "Summary": "Every user signs in with a passkey, Windows Hello for Business or another method that a phishing site can't replay.",
      "Step": "entra.phishing-resistant-all",
      "Steps": [
        "entra.passkeys-enabled",
        "intune.windows-hello",
        "entra.certificate-based-auth",
        "intune.macos-platform-sso",
        "entra.temporary-access-pass",
        "entra.phishing-resistant-registered-all",
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.ca-exclude-sync-accounts",
        "entra.phishing-resistant-registered-admins",
        "entra.phishing-resistant-admins",
        "entra.phishing-resistant-all"
      ],
      "Done": 0,
      "Applicable": 3,
      "Status": "NotStarted"
    },
    {
      "Id": "privileged-access",
      "Title": "Replace standing admin access with PIM",
      "Summary": "Administrators activate privileged roles when they need them, and only the emergency access accounts keep standing access.",
      "Step": "entra.pim-eligible-roles",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.pim-approval-global-admin",
        "entra.pim-notifications",
        "entra.pim-eligible-roles"
      ],
      "Done": 0,
      "Applicable": 1,
      "Status": "NotStarted"
    },
    {
      "Id": "token-protection",
      "Title": "Protect sign-in tokens on Windows",
      "Summary": "Sign-in tokens for Exchange, SharePoint and Teams are bound to the Windows device they were issued to, so they can't be replayed elsewhere.",
      "Step": "entra.ca-token-protection-windows",
      "Steps": [
        "entra.emergency-access-accounts",
        "entra.emergency-access-excluded",
        "entra.windows-devices-registered",
        "entra.ca-block-unknown-platforms",
        "entra.ca-token-protection-windows"
      ],
      "Done": 0,
      "Applicable": 2,
      "Status": "NotStarted"
    },
    {
      "Id": "defender-device-risk",
      "Title": "Use Defender device risk in compliance",
      "Summary": "Devices that Defender for Endpoint rates risky become noncompliant, so the compliant-device Conditional Access policy blocks them.",
      "Step": "intune.compliance-device-risk",
      "Steps": [
        "intune.defender-connector",
        "intune.defender-compliance-evaluation",
        "defender.endpoint-onboarding",
        "intune.compliance-policies",
        "intune.compliance-device-risk"
      ],
      "Done": 0,
      "Applicable": 1,
      "Status": "NotStarted"
    }
  ]
}
