$domain = $env:USERDOMAIN
$path = "$env:TEMP\$domain"

New-Item -Type Directory $path
Get-ADDomain|ConvertTo-Json|Out-File $path\get-addomain.json
Get-ADForest|ConvertTo-Json|Out-File $path\get-adforest.json
Get-ADComputer -Filter * -Properties createTimeStamp, distinguishedName, enabled, isCriticalSystemObject, lastLogonDate, managedBy, modified, operatingSystem, passwordExpired, passwordLastSet, PasswordNeverExpires, PasswordNotRequired, primaryGroupId, SIDHistory, TrustedForDelegation, TrustedToAuthForDelegation|ConvertTo-Json|Out-File $path\get-adcomputer.json
Get-ADUser -Filter * -Properties adminCount, CannotChangePassword, createTimeStamp, DistinguishedName, Enabled, isCriticalSystemObject, LastBadPasswordAttempt, LastLogonDate, LockedOut, logonHours, LogonWorkstations, managedBy, modifyTimeStamp, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, SIDHistory|ConvertTo-Json|Out-File $path\get-aduser.json
Get-ADGroup -Filter * -Properties adminCount, createTimeStamp, DistinguishedName, GroupCategory, GroupScope, isCriticalSystemObject, ManagedBy, modifyTimeStamp, SIDHistory|ConvertTo-Json|Out-File $path\get-adgroup.json
Get-ADServiceAccount -Filter *|ConvertTo-Json|Out-File $path\get-adserviceaccount.json
Get-ADDomainController -Filter *|ConvertTo-Json|Out-File $path\get-addomaincontroller.json
Get-ADObject -Properties * -LDAPFilter "(&(objectCategory=Computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))"|ConvertTo-Json|Out-File $path\get-adobjectdomaincontroller.json
Get-ADReplicationSite|ConvertTo-Json|Out-File $path\get-adreplicationsite.json
Get-ADRootDSE|ConvertTo-Json|Out-File $path\get-adrootdse.json
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -Properties * -Filter *|ConvertTo-Json|Out-File "$path\get-adschemahistory.json"
Get-ADObject -SearchBase "CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$(((Get-ADRootDSE).defaultNamingContext))" -Filter * -Properties *|ConvertTo-Json|Out-File $path\get-adoptionalfeatures.json
Get-ADObject -LDAPFilter "(serviceprincipalname=kadmin/changepw)" -Properties *|ConvertTo-Json|Out-File $path\get-adkrbtgt.json
Get-ADObject -LDAPFilter "(objectClass=nTFRSSubscriber)"|ConvertTo-Json|Out-File $path\get-adfrssubscribers.json
Get-ADObject -LDAPFilter "(objectClass=msDFSR-Subscription)"|ConvertTo-Json|Out-File $path\get-addfsrsubscribers.json
Get-ADReplicationConnection -Properties * -Filter *|ConvertTo-Json|Out-File $path\get-adreplicationconnection.json
& dfsrmig /getmigrationstate|Out-File $path\dfsrmig.txt
& repadmin /replsummary|Out-File $path\repadmin.txt
& repadmin.exe /showbackup|Out-File $path\repadminShowBackup.txt
Get-ADReplicationSite -Filter * -Properties *|ConvertTo-Json|Out-File "$path\get-adreplicationsite.json"
Get-ADOptionalFeature -Filter * -Properties *|ConvertTo-Json|Out-File "$path\Get-ADOptionalFeature.json"
Get-ADObject -SearchBase "CN=Configuration,$((Get-ADRootDSE).defaultNamingContext)" -Filter * -Properties *|ConvertTo-Json|Out-File $path\get-adConfiguration.json
(Get-ADForest).Domains|%{$d=$_;(Get-ADRootDSE -Server $d).NamingContexts|%{$n=$_;(([System.DirectoryServices.ActiveDirectory.DomainController]::FindOne([System.DirectoryServices.ActiveDirectory.DirectoryContext]::new("Domain",$d))).GetReplicationMetadata($_)).Item("dsaSignature")|select {$d}, {$n}, lastOriginatingChangeTime}}|ConvertTo-Json -Compress|Out-File $path\Get-ReplicationMetadata.json
Compress-Archive -Path $path -DestinationPath $path\..\$domain.zip
Remove-Item -Recurse "$path" -Force