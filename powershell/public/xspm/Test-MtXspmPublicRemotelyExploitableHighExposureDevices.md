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

<!--- Results --->
%TestResult%

