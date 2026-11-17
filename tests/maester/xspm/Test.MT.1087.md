The query behind this test searches for devices that comply with the following criteria:

- Incoming connections from public IP addresses in last 7 days (internet exposed)
- High or Critical severity CVE's
- CVE's must have known exploits
- CVE's are remotely exploitable over the network
- No user interaction is required to exploit the CVE's
- EPSS score of CVE must be above 10% (likelihood of exploitation)

> NOTE! If devices are placed behind a proxy, they will not be returned in this query by default

Devices that return from these results are possible high-risk devices that could be exploited successfully any time.

### How to fix
Review the devices in the list and either patch the severities, or make sure to implement mitigative controls to reduce exposure. If you want to have more details on the exposed devices and their related CVE's, you can [run the following query manually](https://github.com/HybridBrothers/Hunting-Queries-Detection-Rules/blob/main/Exposure%20Management/HuntPublicRemotelyExploitableDevicesWithHighEPSS.md) in Advanced Hunting.

### When this is skipped
- **Advanced hunting does not serve the Defender for Endpoint tables.** This check reads `DeviceNetworkEvents` and `DeviceTvmSoftwareVulnerabilities`, and its assessed-device fallback reads `DeviceTvmSoftwareInventory`. It probes `DeviceInfo` before either and skips when that table does not answer. A tenant holding both Defender for Business (from Business Premium) and Defender for Endpoint Plan 2 (for instance from an E5 trial) keeps the [Defender for Business experience](https://learn.microsoft.com/defender-business/mdb-faq#can-i-have-a-mix-of-microsoft-endpoint-security-subscriptions) until Support switches it, and [advanced hunting belongs to Plan 2 only](https://learn.microsoft.com/defender-business/mdb-overview#how-does-defender-for-business-compare-to-microsoft-defender-for-endpoint). A licence gate cannot see this: the tenant holds the entitlement and not the experience.
- **Nothing assessed.** When no device has any software inventory in Defender Vulnerability Management, there is no fleet to judge. Zero exposed devices out of zero assessed devices is not a pass.

<!--- Results --->
%TestResult%

