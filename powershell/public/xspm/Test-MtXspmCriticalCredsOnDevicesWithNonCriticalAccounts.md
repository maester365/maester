Normal user account (or non-critical user account) credentials should not live on devices that also have credentials of critical users. This makes the related devices an interesting target for attackers to exploit to eventually perform privilege escalation and lateral movement.

### How to fix

Analyze the devices shown in the output, and investigate the accounts present on the device. If the device is a client device, make sure Admin accounts get their own specific device (like a PAW) to ensure it cannot be abused by exploiting the normal user account. For servers, make sure to implement a tiering architecture forcing accounts to only login into servers of their shared tier.

<!--- Results --->
%TestResult%