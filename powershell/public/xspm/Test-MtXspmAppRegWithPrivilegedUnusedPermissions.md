Unused privileged permissions should not remain assigned to a service principal because they increase the attack surface and risk of unauthorized access. If these permissions are not required for the application's functionality, they can be exploited by attackers or misused, leading to potential privilege escalation or data exposure. Removing unnecessary privileged permissions helps maintain a stronger security posture and reduces the likelihood of security incidents.

### How to fix
Review the findings in the [Applications inventory](https://learn.microsoft.com/en-us/defender-cloud-apps/applications-inventory#oauth-apps) in App Governance, and verify that there are no activities or use cases requiring the affected service principal to have assignments to these API permissions. Use [hunting of app activities](https://learn.microsoft.com/en-us/defender-cloud-apps/app-activity-threat-hunting) to review access and required permissions.

<!--- Results --->
%TestResult%