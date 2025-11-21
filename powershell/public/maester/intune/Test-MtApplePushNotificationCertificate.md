Check the validity of the Apple Push Notification Service (APNS) Certificate for Intune. The Apple Push Notification Service (APNS) Certificate is required for managing Apple devices with Microsoft Intune. This test checks if the APNS certificate is valid and not expired.

#### Remediation action

It is critical that you renew your APNs certificate, not request a new one. This means you must ensure that you use the same Apple ID and renew the same certificate from Apple’s site. If you request a new certificate instead of renewing your existing certificate, you will be forced to unenroll and re-enroll all of your existing iOS devices.

See the [Microsoft learn instructions to Renew Apple MDM certificate](https://learn.microsoft.com/en-us/intune-education/renew-ios-certificate-token#renew-apple-mdm-certificate).

<!--- Results --->
%TestResult%