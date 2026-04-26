$DnBases = @(
    "OU=orgUnit,DC=example,DC=com",
    "OU=Domain Controllers,DC=example,DC=com"
)

$GUIDs = @{'00000000-0000-0000-0000-000000000000' = 'All'}
$ADDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$ADForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
$SchemaPath = $ADForest.Schema.Name
Remove-Variable ADForest

If ($SchemaPath)
{
    Write-Verbose "[*] Enumerating schemaIDs"
    $objSearcherPath = New-Object System.DirectoryServices.DirectorySearcher ([ADSI] "LDAP://$($SchemaPath)")
    $objSearcherPath.PageSize = 200
    $objSearcherPath.filter = "(schemaIDGUID=*)"

    Try
    {
        $SchemaSearcher = $objSearcherPath.FindAll()
    }
    Catch
    {
        Write-Warning "[Get-ADRACL] Error enumerating SchemaIDs"
        Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    }

    If ($SchemaSearcher)
    {
        $SchemaSearcher | Where-Object {$_} | ForEach-Object {
            # convert the GUID
            $GUIDs[(New-Object Guid (,$_.properties.schemaidguid[0])).Guid] = $_.properties.name[0]
        }
        $SchemaSearcher.dispose()
    }
    $objSearcherPath.dispose()

    Write-Verbose "[*] Enumerating Active Directory Rights"
    $objSearcherPath = New-Object System.DirectoryServices.DirectorySearcher ([ADSI] "LDAP://$($SchemaPath.replace("Schema","Extended-Rights"))")
    $objSearcherPath.PageSize = 200
    $objSearcherPath.filter = "(objectClass=controlAccessRight)"
            
    Try
    {
        $RightsSearcher = $objSearcherPath.FindAll()
    }
    Catch
    {
        Write-Warning "[Get-ADRACL] Error enumerating Active Directory Rights"
        Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    }

    If ($RightsSearcher)
    {
        $RightsSearcher | Where-Object {$_} | ForEach-Object {
            # convert the GUID
            $GUIDs[$_.properties.rightsguid[0].toString()] = $_.properties.name[0]
        }
        $RightsSearcher.dispose()
    }
    $objSearcherPath.dispose()
}

$path="$env:USERPROFILE\Desktop\Get-Acls-$(Get-Date -Format yyyyMMdd-HHmm).csv"
foreach ($DnBase in $DnBases)
{
    Write-Host "[*] Starting DN Base [$(Get-Date -Format HHmm)]: $DnBase"
    # Get the Domain, OUs, Root Containers, GPO, User, Computer and Group objects.
    $Objs = @()
    Write-Verbose "[*] Enumerating Domain, OU, GPO, User, Computer and Group Objects"
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
    $ObjSearcher.PageSize = 200
    $objSearcher.SearchRoot = "LDAP://$DnBase"
    $ObjSearcher.Filter = "(|(objectClass=domain)(objectCategory=organizationalunit)(objectCategory=groupPolicyContainer)(samAccountType=805306368)(samAccountType=805306369)(samaccounttype=268435456)(samaccounttype=268435457)(samaccounttype=536870912)(samaccounttype=536870913))"
    # https://msdn.microsoft.com/en-us/library/system.directoryservices.securitymasks(v=vs.110).aspx
    $ObjSearcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Sacl
    $ObjSearcher.PropertiesToLoad.AddRange(("displayname","distinguishedname","name","ntsecuritydescriptor","objectclass","objectsid"))
    $ObjSearcher.SearchScope = "Subtree"

    Try
    {
        $Objs += $ObjSearcher.FindAll()
    }
    Catch
    {
        Write-Warning "[Get-ADRACL] Error while enumerating Domain, OU, GPO, User, Computer and Group Objects"
        Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    }
    $ObjSearcher.dispose()

    Write-Verbose "[*] Enumerating Root Container Objects"
    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
    $ObjSearcher.PageSize = 200
    $objSearcher.SearchRoot = "LDAP://$DnBase"
    $ObjSearcher.Filter = "(objectClass=container)"
    # https://msdn.microsoft.com/en-us/library/system.directoryservices.securitymasks(v=vs.110).aspx
    $ObjSearcher.SecurityMasks = $ObjSearcher.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl -bor [System.DirectoryServices.SecurityMasks]::Group -bor [System.DirectoryServices.SecurityMasks]::Owner -bor [System.DirectoryServices.SecurityMasks]::Sacl
    $ObjSearcher.PropertiesToLoad.AddRange(("distinguishedname","name","ntsecuritydescriptor","objectclass"))
    $ObjSearcher.SearchScope = "OneLevel"

    Try
    {
        $Objs += $ObjSearcher.FindAll()
    }
    Catch
    {
        Write-Warning "[Get-ADRACL] Error while enumerating Root Container Objects"
        Write-Verbose "[EXCEPTION] $($_.Exception.Message)"
    }
    $ObjSearcher.dispose()

    if ($Objs)
    {
        $i=1
        Write-Host "[*] Object [$(Get-Date -Format HHmm)]: $i/$($objs.Length)"
        foreach ($obj in $objs)
        {
            if ($i % 1000 -eq 0)
            {
                Write-Host "[*] Object [$(Get-Date -Format HHmm)]: $i/$($objs.Length)"
            }
            $aces = ([adsi]$obj.Path).ObjectSecurity.Access

            $aces|Add-Member -MemberType NoteProperty -Name Object -Value $obj.Path
            $aces|Export-Csv -NoTypeInformation -Append -Path $path

            $i++
        }
    }
}