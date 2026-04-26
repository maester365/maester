function Test-MtAdUserSpnUnknownDetails {
    <#
    .SYNOPSIS
    Provides detailed information about unidentified SPN service classes on user accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on user objects
    and provides detailed information about service classes that are not in the known SPN database.
    This includes which users have these SPNs and how many instances exist.

    .EXAMPLE
    Test-MtAdUserSpnUnknownDetails

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes detailed information about unknown user SPNs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnUnknownDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Known SPN service classes
    $knownSpns = @(
        'HOST', 'HTTP', 'HTTPS', 'LDAP', 'GC', 'DNS', 'CIFS', 'RPC', 'SMB',
        'MSSQLSvc', 'SQLAgent', 'MSOLAPSvc', 'MSOLAPSvc.3', 'MSOLAPDisco.3',
        'exchangeAB', 'exchangeMDB', 'exchangeRFR', 'SMTP', 'SMTPSVC', 'POP', 'POP3', 'IMAP', 'IMAP4',
        'TERMSRV', 'TERMSERV', 'WSMAN', 'RestrictedKrbHost', 'nfs', 'iSCSITarget',
        'MSClusterVirtualServer', 'MSServerCluster', 'MSServerClusterMgmtAPI',
        'Hyper-V Replica Service', 'Microsoft Virtual Console Service', 'Microsoft Virtual System Migration Service',
        'VMMSvc', 'SCVMM', 'CmRcService',
        'FIMService', 'PCNSCLNT', 'AgpmServer', 'AdtServer',
        'MSOMHSvc', 'MSOMSdkSvc', 'LiveState Recovery Agent 6.x',
        'E3514235-4B06-11D1-AB04-00C04FC2DCD2', 'E3514235-4B06-11D1-AB04-00C04FC2DCD2-ADAM',
        'Dfsr-12F9A27C-BF97-4787-9364-D31B6C55EB04', 'NtFrs-88f5d2bd-b646-11d2-a6d3-00c04fc9b232',
        'kadmin', 'krbsvr400', 'oracle', 'postgres', 'mongod', 'mongos',
        'ftp', 'vnc', 'sip', 'xmpp', 'ipp', 'cvs', 'afpserver', 'pcast', 'xgrid',
        'hdb', 'hbase', 'hdfs', 'hive', 'impala', 'kafka', 'mapred', 'oozie',
        'solr', 'spark', 'yarn', 'zookeeper', 'sentry', 'flume', 'hue', 'boostfs',
        'SAP', 'SAPService', 'SAS', 'BOBJCentralMS', 'BOCMS', 'BOSSO', 'BICMS',
        'Cognos', 'DynamicsNAV', 'NAV2016', 'MSCRMAsyncService', 'MSCRMSandboxService',
        'M-Files', 'ImDmsSvc', 'SeapineLicenseSvr', 'PVSSoap', 'Norskale',
        'aradminsvc', 'CESREMOTE', 'CAXOsoftEngine', 'CAARCserveRHAEngine',
        'FileRepService', 'VProRecovery', 'Backup Exec System Recovery Agent 6.x',
        'LiveState Recovery Agent 6.x', 'SoftGrid', 'vssrvc', 'vmrc',
        'OA60', 'EDVR', 'iem', 'magfs', 'tapinego', 'tnetdgines',
        'CUSESSIONKEYSVR', 'ckp_pdp', 'secshd', 'informatica',
        'jboss', 'fcsvr', 'gateway', 'httpfs', 'JournalNode Server',
        'kafka_mirror_maker', 'kudu', 'mr2', 'Storm', 'Zeppelin',
        'PIAFServer', 'PIServer', 'AFServer', 'PowerBIReportServer',
        'AcronisAgent', 'NPPolicyEvaluator', 'NPRepository4(DEFAULT)', 'NPRepository4(*)',
        'Agent VProRecovery Norton Ghost 12.0', 'UPM_SPN_7DC3CE86',
        '{14E52635-0A95-4a5c-BDB1-E0D0C703B6C8}', '{54094C05-F977-4987-BFC9-E8B90E088973}'
    )

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $users = $adState.Users

    # Extract unknown SPNs from user objects
    $unknownSpnData = $users | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $user = $_
        $user.servicePrincipalName | ForEach-Object {
            if ($_ -match "^([^/]+)") {
                $serviceClass = $matches[1]
                if ($knownSpns -notcontains $serviceClass) {
                    [PSCustomObject]@{
                        ServiceClass = $serviceClass
                        User = $user.SamAccountName
                        SPN = $_
                    }
                }
            }
        }
    }

    # Group by service class
    $unknownGroups = $unknownSpnData | Group-Object ServiceClass | Sort-Object Count -Descending

    $unknownCount = ($unknownGroups | Measure-Object).Count
    $totalUnknownInstances = ($unknownSpnData | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Unknown Service Classes | $unknownCount |`n"
        $result += "| Total Unknown SPN Instances | $totalUnknownInstances |`n`n"

        if ($unknownCount -gt 0) {
            $result += "### Unknown Service Class Details`n`n"
            $result += "| Service Class | Count | Users |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($group in $unknownGroups) {
                $usersList = ($group.Group | Select-Object -ExpandProperty User -Unique) -join ', '
                if ($usersList.Length -gt 50) {
                    $usersList = $usersList.Substring(0, 47) + "..."
                }
                $result += "| $($group.Name) | $($group.Count) | $usersList |`n"
            }
        } else {
            $result += "No unknown SPN service classes found on user accounts. All SPNs match the known service database.`n"
        }

        $testResultMarkdown = "Active Directory user SPN unknown service class details.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


