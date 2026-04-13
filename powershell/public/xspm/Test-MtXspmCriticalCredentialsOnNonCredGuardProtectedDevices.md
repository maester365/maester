Devices shown in the output are devices where Credential Guard is not enabled or misconfigured, but contains credentials of critical accounts. When critical credentials are stored on devices without Credential Guard enabled, it is easy for adversaries to steal those credentials when the device is compromised. This is because, without Credential Guard enabled, Kerberos, NTLM, and Credential Manager secrets are stored in the Local Security Authority (LSA) process called `lsass.exe`, which can be dumped with various tools like MimiKatz. With Credential Guard enabled, these secrets are protected and isolated using Virtualization-based security (VBS).

### How to fix
Investigate the related devices and the steps that need to be taken in order to enable Credential Guard. This varies depending on operating system, hardware, and device. More information on how Credential Guard works and how it can be configured can be found in [this documentation page](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/).

<!--- Results --->
%TestResult%
