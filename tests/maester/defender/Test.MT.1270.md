Ensure no device runs **software with a high or critical vulnerability for which exploit code is publicly available**.

Defender Vulnerability Management knows two things separately: which vulnerabilities are present on each onboarded device, and — from its vulnerability knowledge base — whether exploit code for a given vulnerability is publicly available. The intersection of the two is the part of the fleet an attacker can act on today with code they do not have to write.

This check **fails** when any onboarded device runs software with a high or critical vulnerability whose exploit code is publicly available, and reports how many devices are exposed, across how many distinct CVEs, with up to ten CVEs, software products and device names.

## On the signal used

The issue that asked for this check names the **CISA Known Exploited Vulnerabilities** catalogue. The advanced hunting schema exposes no CISA KEV flag: `DeviceTvmSoftwareVulnerabilitiesKB` carries `CveId`, `CvssScore`, `IsExploitAvailable`, `VulnerabilitySeverityLevel`, `LastModifiedTime`, `PublishedDate`, `VulnerabilityDescription` and `AffectedSoftware`, and nothing else.

`IsExploitAvailable`, documented by Microsoft as *"whether exploit code for the vulnerability is publicly available"*, is the closest first-party signal, and it is what this check reports. **It does not claim CISA KEV membership.** The two sets overlap heavily but are not the same, and reporting one as the other would put a claim in the result that the data does not support.

## How this differs from MT.1087

`MT.1087` and this check look at the same vulnerability data and are deliberately not the same test.

| | MT.1087 | MT.1270 |
| --- | --- | --- |
| Device must be internet exposed | **Yes** - incoming connections from public IP addresses in the last 7 days | No |
| Vulnerability must be remotely exploitable over the network | **Yes** | No |
| Exploit code publicly available | Yes | Yes |
| Severity | `High` | `Medium` |

MT.1087 answers *which devices can be reached and attacked from the internet right now*, which is why it
is rated higher. This check answers the broader question: *where in the fleet is software an attacker
could exploit with code they do not have to write* - including devices that are not exposed, and
vulnerabilities that need local access. A tenant can pass MT.1087 and still fail this one, and that is
the intended reading, not a contradiction.

## When this is skipped

- **Nothing assessed.** The check carries the number of distinct devices Defender has any vulnerability data for as a denominator. When that is zero, no device is onboarded to Defender for Endpoint or none has reported, and the result is skipped as not applicable. **Zero exposed devices out of zero assessed devices is not a pass.**
- **Not licensed.** The check declares `DEFENDER_XDR`, so a tenant without a Defender XDR workload is skipped as not licensed, never failed.

## How to remediate

Patch or remove the software listed. Exploit code for these vulnerabilities is already public, so the window between disclosure and attack has closed. Work the list in **Microsoft Defender portal** → **Endpoints** → **Vulnerability management** → **Weaknesses**, filtered on exploit availability.

## Permissions

Read-only. This check runs an advanced hunting query through `security/runHuntingQuery` with `ThreatHunting.Read.All`, which is already one of Maester's default Graph scopes. It needs no additional permission.

<!--- Results --->
%TestResult%
