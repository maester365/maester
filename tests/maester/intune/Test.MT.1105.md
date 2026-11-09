This test verifies whether Microsoft Intune is set as MDM authority. In tenants where Intune is used to provision and manage devices, this should be automatically the case.

#### Remediation action

1. In the Microsoft Intune admin center, select the orange banner to open the Mobile Device Management Authority setting. The orange banner is only displayed if you haven't yet set the MDM authority. If the orange banner is not visible, you can navigate directly to the [MDM Authority settings](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/ChooseMDMAuthorityBlade) to configure the MDM authority.

2. Under Mobile Device Management Authority, choose your MDM authority to: Intune MDM Authority

Additional information:

* [Set the mobile device management authority](https://learn.microsoft.com/intune/intune-service/fundamentals/mdm-authority-set)

<!--- Results --->
%TestResult%