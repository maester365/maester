#### Test-MtAdMachineAccountQuota

#### Why This Test Matters

The machine account quota (ms-DS-MachineAccountQuota) attribute controls how many computer accounts a standard (non-administrative) user can join to the domain. The default value of 10 can create security risks:

- **Rogue Computer Joins**: Attackers with valid user credentials can join unauthorized computers to the domain
- **Lateral Movement**: Joined computers can be used as pivot points for further attacks
- **Resource Exhaustion**: Excessive computer accounts can clutter the directory and complicate management

#### Security Recommendation

Consider reducing the machine account quota to 0 and using alternative methods for computer joins:

1. **Set quota to 0**: Prevents standard users from joining computers
2. **Use pre-staged accounts**: Administrators create computer accounts in advance
3. **Delegate join permissions**: Grant specific groups permission to join computers
4. **Implement privileged access workstations**: Use dedicated admin workstations for domain joins

To modify the quota:
```powershell
Set-ADDomain -Identity "yourdomain.com" -Replace @{"ms-DS-MachineAccountQuota"="0"}
```

#### How the Test Works

This test retrieves the current machine account quota value from Active Directory. The test is informational and helps you assess whether the default value poses a risk in your environment.

#### Related Tests

- `Test-MtAdDomainFunctionalLevel` - Retrieves the domain functional level
- `Test-MtAdDomainControllerCount` - Counts domain controllers
