Exchange application access policies should be configured for all applications with Exchange permissions.

### Remediation action:


1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Define variables for your application:
```powershell
# Get these values from your Application Registration
$AppID = "<your-app-id>"  # e.g. "0a3ad682-b031-416d-86c2-bf263f8b46a3"
$GroupName = "AAP_$AppID"  # example naming convention for clarity
$Description = "Restrict this app to members of distribution group"
```

3. Create a mail-enabled security group for policy scope:
```powershell
# Create group and hide from address list
$DGroup = New-DistributionGroup -Name $GroupName -Type Security
Start-Sleep -Seconds 5  # Wait for group creation to propagate
Set-DistributionGroup -Identity $DGroup.WindowsEmailAddress -HiddenFromAddressListsEnabled $true
```

4. Create the application access policy:
```powershell
New-ApplicationAccessPolicy -AppId $AppID `
                          -PolicyScopeGroupId $DGroup.WindowsEmailAddress `
                          -AccessRight RestrictAccess `
                          -Description $Description
```

5. Add members to the security group:
```powershell
Add-DistributionGroupMember -Identity $GroupName -Member user@contoso.com
```

6. Verify the policy:
```powershell
# List all policies
Get-ApplicationAccessPolicy

# Test for specific user
Test-ApplicationAccessPolicy -Identity user@contoso.com -AppId $AppID
```

<!--- Results --->
%TestResult%