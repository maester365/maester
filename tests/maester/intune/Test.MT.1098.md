This test verifies the health of Intune Mobile Threat Defense Connectors, including Microsoft Defender for Endpoint.

Each connector must be enabled and have a heartbeat in the last 48 hours. The result table explains unhealthy states and reports a missing or year-1 heartbeat as **Never received**.

A connector in `notSetUp` has not completed setup and blocks device threat messages. A connector in `available` has completed setup but needs a platform toggle enabled. Neither state satisfies this health check. An `unresponsive` connector needs attention because Intune ignores its compliance state once the configured unresponsiveness threshold is reached.

#### Remediation action

Review each connector's **Reason** in the result table. Complete setup and required permissions for a `notSetUp` connector, enable the relevant platform for an `available` connector, or remove a connector that is no longer needed. For a missing or stale heartbeat, verify the partner service and its connectivity to Intune.

For Microsoft Defender for Endpoint visit the [Microsoft Defender for Endpoint Tenant Settings](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/TenantAdminConnectorsMenu/~/windowsDefenderATP) and ensure that the connector is also enabled from the Microsoft Defender XDR Settings as part of the [Microsoft Intune connection](https://security.microsoft.com/securitysettings/endpoints/integration).

Additional information:

* [Integrate Microsoft Defender for Endpoint with Intune and Onboard Devices](https://learn.microsoft.com/intune/intune-service/protect/microsoft-defender-integrate)

* If you have a third party connector, consult your third party MTD solution. More information can be found on the [Mobile Threat Defense integration with Intune](https://learn.microsoft.com/intune/device-security/mobile-threat-defense/overview#connector-status) learn page.

<!--- Results --->
%TestResult%
