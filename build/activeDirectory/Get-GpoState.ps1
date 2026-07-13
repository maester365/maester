New-Item -Type Directory "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)"
gci "\\$($env:USERDNSDOMAIN)\SYSVOL\$($env:USERDNSDOMAIN)\Policies"|ConvertTo-Json|Out-File "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\get-sysvolGpoGuids.json"
Copy-Item "\\$($env:USERDNSDOMAIN)\SYSVOL\$($env:USERDNSDOMAIN)\Policies" -Recurse -Destination "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)"
Get-GPO -All|ConvertTo-Json|Out-File "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\get-gpo.json"
Get-GPO -All|%{Get-GPOReport -Guid $_.Id -ReportType Xml -Path "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\$($_.Id).xml";Get-GPOReport -Guid $_.Id -ReportType Html -Path "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\$($_.Id).html"}
Get-GPO -All|%{Get-GPPermission -Guid $_.Id -All|ConvertTo-Json|Out-File "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\$($_.Id)-sec.json"}
Backup-GPO -All -Path "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)"
Get-ADObject -Filter * -SearchBase "CN=Sites,CN=Configuration,$(((Get-ADRootDSE).defaultNamingContext))" -Properties *|ConvertTo-Json|Out-File "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\get-siteContainers.json"
Get-ADObject -LDAPFilter "(objectClass=site)" -SearchBase "CN=Sites,CN=Configuration,$(((Get-ADRootDSE).defaultNamingContext))" -Properties gPLink|ConvertTo-Json|Out-File "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\get-siteLinks.json"
Compress-Archive -Path $env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)\ -DestinationPath $env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN).zip
Remove-Item -Recurse "$env:HOMEDRIVE$env:HOMEPATH\Desktop\$($env:USERDNSDOMAIN)" -Force
