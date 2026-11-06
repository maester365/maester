Ensure no device is left **non-compliant with a Defender Vulnerability Management security recommendation**.

Defender Vulnerability Management assesses each onboarded device against a catalogue of security configurations — attack surface reduction rules, antivirus settings, firewall state, encryption, account policies and others — and reports, per configuration, which devices comply. An assessor normally reads that one configuration at a time in the Defender portal. This check brings it into a Maester run.

It runs **once per assessed security configuration**, following the `InstanceSource` pattern `MT.1024` introduced for Entra recommendations. Each configuration becomes its own result, with its own pass or fail.

A configuration **passes** when every device it applies to complies with it, and **fails** when any applicable device does not. The result carries the configuration's category, its rated impact on the Defender configuration score (1 to 10), the number of applicable and non-compliant devices, the risk description, and up to ten of the non-compliant devices by name.

Severity follows the source, as #2510 asks: Defender's own rated impact. An impact of 8 or more is reported as High, 4 to 7 as Medium, below 4 as Low.

Only configurations Defender reports as **applicable to at least one device** are assessed. A configuration that applies to nothing cannot be complied with or breached, so it has no outcome to judge.

## When this is skipped

- **No Defender Vulnerability Management data.** When the hunting query returns no assessment, no device is onboarded to Defender for Endpoint or none has reported. The family is skipped with `NoInstances`. A tenant with no onboarded device has no configuration to be compliant with, and is never reported as having none non-compliant.
- **Not licensed.** The check declares `DEFENDER_XDR`, so a tenant without a Defender XDR workload is skipped as not licensed, never failed.

## How to remediate

Open the configuration in **Microsoft Defender portal** → **Endpoints** → **Vulnerability management** → **Recommendations**, and either remediate it on the devices listed or accept the risk there, so the recommendation stops being reported.

## Permissions

Read-only. This check runs an advanced hunting query through `security/runHuntingQuery` with `ThreatHunting.Read.All`, which is already one of Maester's default Graph scopes. It needs no additional permission.

<!--- Results --->
%TestResult%
