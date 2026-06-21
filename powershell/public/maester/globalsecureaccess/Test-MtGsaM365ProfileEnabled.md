The Microsoft 365 traffic forwarding profile routes Microsoft 365 traffic (Exchange Online, SharePoint Online, Teams) through Global Secure Access. Enabling it is the lowest-risk entry point to Global Secure Access and is included with Microsoft Entra ID P1.

Enabling the Microsoft 365 profile unlocks:

* **Source IP restoration** for Microsoft 365 sign-in logs and Identity Protection detections
* The **Compliant Network** signal in Conditional Access (token replay protection)
* **Universal Tenant Restrictions** to help prevent data exfiltration to other tenants
* **Network access traffic logs** (`NetworkAccessTraffic`) for security operations

#### Remediation action:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Global Secure Access Administrator**.
2. Browse to **Global Secure Access** > **Connect** > **[Traffic forwarding](https://entra.microsoft.com/#view/Microsoft_Azure_Network_Access/TrafficForwarding.ReactView)**.
3. Enable the **Microsoft 365 traffic forwarding profile**.
4. Review and assign the profile to the users and groups that should be protected.

#### Related links

* [Entra admin center - Global Secure Access | Traffic forwarding](https://entra.microsoft.com/#view/Microsoft_Azure_Network_Access/TrafficForwarding.ReactView)
* [Global Secure Access traffic forwarding profiles](https://learn.microsoft.com/entra/global-secure-access/concept-traffic-forwarding)
* [Learn about the Microsoft 365 traffic forwarding profile](https://learn.microsoft.com/entra/global-secure-access/how-to-manage-microsoft-365-profile)

<!--- Results --->
%TestResult%
