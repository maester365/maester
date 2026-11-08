Devices shown in the output are devices where a TPM (Trusted Platform Module) is not enabled, but contains credentials of critical accounts. When critical credentials are stored on devices without a TPM enabled, it is more easy for adversaries to steal those credentials when the device is compromised.

### How to fix
Investigate the related devices and the steps that need to be taken in order to enable TPM support. This varies depending on operating system, hardware, and device. For more detailed results, you can [manually run the following query in advanced hunting](https://github.com/HybridBrothers/Hunting-Queries-Detection-Rules/blob/main/Exposure%20Management/HuntCriticalCredentialsOnNonTpmDevices.md).

<!--- Results --->
%TestResult%