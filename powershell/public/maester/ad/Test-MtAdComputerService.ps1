<#
.SYNOPSIS
    Checks Computer SPNs

.DESCRIPTION
    Identifies potential misconfiguration of computer SPNs

.PARAMETER Server
    Server name to pass through to the AD Cmdlets

.PARAMETER Credential
    Credential object to pass through to the AD Cmdlets

.EXAMPLE
    Test-MtAdComputerService

    Returns true if AD Computer SPNs are proper

.LINK
    https://maester.dev/docs/commands/Test-MtAdComputerService
#>
function Test-MtAdComputerService {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Server = $__MtSession.AdServer,
        [pscredential]$Credential = $__MtSession.AdCredential
    )

    if ('ActiveDirectory' -notin $__MtSession.Connections -and 'All' -notin $__MtSession.Connections ) {
        Write-Verbose "ActiveDirectory not set as connection"
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    if (-not $__MtSession.AdCache.AdComputers.SetFlag){
        Set-MtAdCache -Objects "Computers" -Server $Server -Credential $Credential
    }

    #Bulk of list from https://adsecurity.org/?page_id=183 as of 12/2025
    #Thank you Sean Metcalf
    $knownSpns=@"
SPN,Application
{14E52635-0A95-4a5c-BDB1-E0D0C703B6C8},
{54094C05-F977-4987-BFC9-E8B90E088973},Graphon
AcronisAgent,Acronis backup/data recovery software
AdtServer,Microsoft System Center Operations Manager (2007/2012) Management Server with ACS
afpserver,Apple Filing Protocol
AFServer,Pi AF Server
Agent VProRecovery Norton Ghost 12.0,VProRecovery Norton Ghost 12.0
AgpmServer,Microsoft Advanced Group Policy Management (AGPM)
aradminsvc,Quest Active Roles Server
Backup Exec System Recovery Agent 6.x,Backup Exec System Recovery Agent 6.x
BICMS,SAP Business Objects
BO3SSO,Business Objects?
BOBJCentralMS,SAL
BOCMS,SAP Business Objects
BOSSO,Business Objects
CAXOsoftEngine,CA XOsoft Exchange Replication
CAARCserveRHAEngine,CA ArcServe
CESREMOTE,seems to be related to a Citrix VDI solution on VMWare. Many VDI workstations have this SPN.
CIFS,Common Internet File System
ckp_pdp,Checkpoint Identity
CmRcService,Microsoft System Center Configuration Manager (SCCM) Remote Control
Cognos,IBM Cognos
CUSESSIONKEYSVR,Cisco Unity VOIP System
cvs,CVS Repository
Dfsr-12F9A27C-BF97-4787-9364-D31B6C55EB04,Distributed File System Replication
DNS,Domain Name Server
DynamicsNAV,Microsoft Dynamics?
E3514235-4B06-11D1-AB04-00C04FC2DCD2,NTDS DC RPC Replication
E3514235-4B06-11D1-AB04-00C04FC2DCD2-ADAM,Microsoft ADAM Instance
exchangeAB,Exchange Address Book service (typically a Domain Controller supporting NSPI, which is usually all GCs)
exchangeMDB,RPC client access - Client Access Server role
exchangeRFR,Exchange Address Book service
EDVR,ExacqVision
fcsvr,Apple Final Cut Server
FIMService,Microsoft Forefront Identity Manager (FIM)
FileRepService,WSFileRepService.exe ?
ftp,File Transfer Protocol
flume,Clodera Flume
gateway,Hadoop Knox
GC,Domain Controller Global Catalog services
hbase,Cloudera Hbase
HBase,Hadoop MasterServer
hdb,Hana DB
hdfs,Hadoop
hive,Hadoop Metastore
host,The HOST service represents the host computer. The HOST SPN is used to access the host computer account whose long term key is used by the Kerberos protocol when it creates a service ticket.
HTTP,SPN for http web services that support Kerberos authentication
httpfs,Hadoop HDFS over HTTP
https,SPN for http web services that support Kerberos authentication
Hue,Hadoop Hue Interface
Hyper-V Replica Service,Microsoft Hyper-V's Replica Service
iem,IBM BigFix
IMAP,Internet Message Access Protocol
IMAP4,Internet Message Access Protocol version 4
impala,Cloudera Impala
ImDmsSvc,Worksite (Imanage) Server
ipp,Internet Printing Protocol
iSCSITarget,iSCSI Configuration
jboss,RedHat Jboss
JournalNode Server,Hadoop JournalNode
kadmin,Kerberos
Kafka,Hadoop KafkaServer
kafka,Apache Kafka
kudu,Apache Kudu
kafka_mirror_maker,Apache Kafka
krbsvr400,IBM OS/400
ldap,LDAP service such as on a Domain Controller or ADAM instance.
LiveState Recovery Agent 6.x,Symantec LiveState Recovery
magfs,Maginatics MagFS
mapred,Cloudera Map reduce
M-Files,M-Files?
Microsoft Virtual Console Service,HyperV Host
Microsoft Virtual System Migration Service,P2V Support (Hyper-V)
mongod,MongoDB Enterprise
mongos,MongoDB Enterprise
mr2,Hadoop History Server
MSClusterVirtualServer,Windows Cluster Server
MSCRMAsyncService,Microsoft Dynamics 365
MSCRMSandboxService,Microsoft Dynamics 365
MSOLAPDisco.3,SQL Server Analysis Services
msolapdisco3,SQL Server Analysis Services
MSOLAPSvc,SQL Server Analysis Services
MSOLAPSvc.3,SQL Server Analysis Services
MSOMHSvc,Micrsoft SCOM 2012
MSOMSdkSvc,Micrsoft SCOM 2012
MSServerCluster,Windows Cluster Server
MSServerClusterMgmtAPI,This SPN is needed for cluster APIs to authenticate to the server by using Kerberos
MSSQL,Microsoft SQL Server
MSSQL`$ADOBECONNECT,Microsoft SQL Server supporting Adobe Connect
MSSQL`$BIZTALK,Microsoft SQL Server supporting Microsoft Biztalk Server
MSSQL`$BUSINESSOBJECTS,Microsoft SQL Server supporting Business Objects
MSSQL`$DB01NETIQ,Microsoft SQL Server supporting NetIQ
MSSQLSvc,Microsoft SQL Server
NAV2016,Microsoft Dynamics NAV
nfs,Network File System
Norskale,Citrix Infrastructure
NPPolicyEvaluator,Quest Change Auditor
NPRepository4(DEFAULT),Quest Change Auditor
NPRepository4(*),Quest Change Auditor
NtFrs-88f5d2bd-b646-11d2-a6d3-00c04fc9b232,NT File Replication Service
oozie,Hadoop Oozie Server
OA60,OpenAccess (sometimes)
oracle,Oracle Kerberos auth
pcast,Apple Podcast Producer
PCNSCLNT,Automated Password Synchronization Solution (MIIS 2003 & FIM)
PIServer,Pi AF Server
PowerBIReportServer,Power BI Report Server
POP,Post Office Protocol
POP3,Post Office Protocol version 3
PVSSoap,Citrix Provisioning Services (7.1)
postgres,Postgres database server
RestrictedKrbHost,The class of services that use SPNs with the serviceclass string equal to “RestrictedKrbHost”, whose service tickets use the computer account’s key and share a session key.
RPC,Remote Procedure Call
SAP,SAP/SAPService<SID>
SAPService,SAP/SAPService<SID>
SAS,SAS 9.3 Intelligence Platform
SCVMM,Micrsoft System Center Virtual Machine Manager (SCVMM)
SQLAgent`$DB01NETIQ,SQL service for NetIQ
secshd,IBM InfoSphere
SeapineLicenseSvr,Helix ALM
sentry,Cloudera Enterprise 5.2.x
sip,Session Initiation Protocol
SMTP,Simple Mail Transfer Protocol
SMTPSVC,Simple Mail Transfer Protocol
SoftGrid,Microsoft Application Virtualization (App-V) formerly “SoftGrid”
solr,Apache Solr
spark,Apache Spark Server
*informatica*,Informatica
Storm,Hadoop Nimbus server
STS,VMWare SSO service
tapinego,Associated with routing applications such as Microsoft firewalls (ISA, TMG, etc)
TERMSERV,Microsoft Remote Desktop Protocol Services, aka Terminal Services.
TERMSRV,Microsoft Remote Desktop Protocol Services, aka Terminal Services.
tnetdgines,Juniper Kerberos auth? “Tnetd is a daemon used for internal communication between different components like Routing Engine and Packet Forwarding En
VCSClusterVirtualServer,Microsoft Cluster Server
VMMSvc,Micrsoft System Center Virtual Machine Manager (SCVMM)
vmrc,Microsoft Virtual Server 2005
vnc,VNC Server
vpn,Virtual Private Network
VProRecovery Backup Exec System Recovery Agent 7.0,
VProRecovery Backup Exec System Recovery Agent 8.0,
VProRecovery Backup Exec System Recovery Agent 8.5,
VProRecovery Backup Exec System Recovery Agent 9.0,
VProRecovery Norton Ghost Agent 12.0,
VProRecovery Norton Ghost Agent 14.0,
VProRecovery Norton Ghost Agent 15.0,
VProRecovery Symantec System Recovery Agent 10.0,
VProRecovery Symantec System Recovery Agent 11.0,
VProRecovery Symantec System Recovery Agent 11.1,
VProRecovery Symantec System Recovery Agent 14.0,
vssrvc,Microsoft Virtual Server (2005)
WSMAN,Windows Remote Management (based on WS-Management standard) service
xgrid,Apple's distributed (grid) computing / Mac OS X 10.6 Server Admin
xmpp,Extensible Messaging and Presence Protocol (Jabber)
yarn,Hadoop NodeManager
yarn,Cloudera MapReduce
Zeppelin,Hadoop Zeppelin Server
ZooKeeper,Hadoop ZooKeeper
zookeeper,Cloudera Zookeeper
boostfs,Data Domain
UPM_SPN_7DC3CE86,Citrix UPM
http,Web Server
https,Web Server
DNS,DNS,
host,alias
SCVMM,System Center Virtual Machine Manager
BOBJCentralMS,SAL
MSSQL`$ADOBECONNECT,Microsoft SQL Server supporting Adobe Connect
MSSQL`$BIZTALK,Microsoft SQL Server supporting Microsoft Biztalk Server
MSSQL`$BUSINESSOBJECTS,Microsoft SQL Server supporting Business Objects
MSSQL`$DB01NETIQ,Microsoft SQL Server supporting NetIQ
PowerBIReportServer,Power BI Report Server
SQLAgent`$DB01NETIQ,SQL service for NetIQ
boostfs,Data Domain
UPM_SPN_7DC3CE86,Citrix UPM
XicNotifier,Honeywell Notifier
"@
    $knownSpns=$knownSpns|ConvertFrom-Csv

    $AdObjects = @{
        Computers = $__MtSession.AdCache.AdComputers.Computers
        Data      = $__MtSession.AdCache.AdComputers.Data
    }

    #region Collect
    $AdObjects.Data.ServiceClasses = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceClasses"
        Expression = {($_.servicePrincipalName) -replace "\/.*$"}
    }).ServiceClasses | Group-Object
    $AdObjects.Data.ServiceClassesCount = ($AdObjects.Data.ServiceClasses | Measure-Object).Count

    $AdObjects.Data.ServiceClassesComputers = $AdObjects.Computers | Select-Object ObjectGUID,@{
        Name       = "ServiceClasses"
        Expression = {
            (($_.servicePrincipalName) -replace "\/.*$") | Sort-Object -Unique
        }
    } | Where-Object {$null -ne $_.ServiceClasses}
    $AdObjects.Data.ServiceClassesComputersCount = ($AdObjects.Data.ServiceClassesComputers | Measure-Object).Count
    $AdObjects.Data.ServiceClassesComputersRatio = try{
        $AdObjects.Data.ServiceClassesComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.UnknownServiceClasses = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceClasses"
        Expression = {($_.servicePrincipalName) -replace "\/.*$"}
    }).ServiceClasses | Group-Object | Where-Object {$_.Name -notin $knownSpns.SPN}
    $AdObjects.Data.UnknownServiceClassesCount = ($AdObjects.Data.UnknownServiceClasses | Measure-Object).Count

    $AdObjects.Data.HostBypassComputers = $AdObjects.Data.ServiceClassesComputers | Select-Object ObjectGUID,@{
        Name       = "ServiceClassesBypassingHost"
        Expression = {
            $_.serviceClasses | ForEach-Object {
                $_ | Where-Object {
                    $_ -in $AdObjects.Data.HostSpnAlias -and
                    $_ -ne "host"
                }
            }
        }
    }
    $AdObjects.Data.HostBypassComputersCount = ($AdObjects.Data.HostBypassComputers | Measure-Object).Count
    $AdObjects.Data.HostBypassComputersRatio = try{
        $AdObjects.Data.UnconstrainedComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceHosts = ($AdObjects.Computers | Select-Object @{
        Name       = "ServiceHosts"
        Expression = {($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$"}
    }).ServiceHosts | Group-Object
    $AdObjects.Data.ServiceHostsCount = ($AdObjects.Data.ServiceHosts | Measure-Object).Count
    $AdObjects.Data.ServiceHostsRatio = try{
        $AdObjects.Data.ServiceHostsCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceHostsComputers = $AdObjects.Computers | Select-Object ObjectGUID,@{
        Name       = "ServiceHosts"
        Expression = {
            (($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique
        }
    } | Where-Object {$null -ne $_.ServiceHosts}
    $AdObjects.Data.ServiceHostsComputersCount = ($AdObjects.Data.ServiceHostsComputers | Measure-Object).Count
    $AdObjects.Data.ServiceHostsComputersRatio = try{
        $AdObjects.Data.ServiceHostsComputersCount / $AdObjects.Data.ComputersCount
    }catch{0}

    $AdObjects.Data.ServiceNoFqdnComputers = $AdObjects.Computers | Select-Object ObjectGUID,DNSHostName,@{
        Name       = "FqdnCheck"
        Expression = {
            $dnsHostName = $_.DNSHostName
            $null -ne $dnsHostName -and
            $dnsHostName -eq ((($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique | Where-Object {
                $dnsHostName -eq $_
            })
        }
    } | Where-Object {-not $_.FqdnCheck}
    $AdObjects.Data.ServiceNoFqdnComputersCount = ($AdObjects.Data.ServiceNoFqdnComputers | Measure-Object).Count

    $AdObjects.Data.ServiceDnsBypassComputers = $AdObjects.Computers | Select-Object ObjectGUID,DNSHostName,@{
        Name       = "ServiceDnsBypass"
        Expression = {
            $dnsHostName = $_.DNSHostName
            (($_.servicePrincipalName) -replace "^[^\/]*\/" -replace "\/[^\/]*$") | Sort-Object -Unique | ForEach-Object {
                $_ | Where-Object {
                    $_ -ne $dnsHostName -and
                    $_ -ne ($dnsHostName -replace "\..*$")
                }
            }
        }
    } | Where-Object {$null -ne $_.ServiceDnsBypass}
    $AdObjects.Data.ServiceDnsBypassComputersCount = ($AdObjects.Data.ServiceDnsBypassComputers | Measure-Object).Count
    $AdObjects.Data.ServiceDnsBypassComputersRatio = try{
        $AdObjects.Data.ServiceDnsBypassComputersCount / $AdObjects.Data.ServiceHostsComputersCount
    }catch{0}
    #endregion

    $__MtSession.AdCache.AdComputers.Data = $AdObjects.Data

    #region Analysis
    $Tests = @{
        ServiceClasses = @{
            Name        = "SPN Service Classes Found"
            Value       = $AdObjects.Data.ServiceClassesCount
            Threshold   = 10
            Indicator   = "<"
            Description = "Discrete number of Service Principal Name (SPN) Service Classes observed"
            Status      = $null
        }
        ServiceClassesComputers = @{
            Name        = "Computers with SPN configured"
            Value       = $AdObjects.Data.ServiceClassesComputersRatio
            Threshold   = 0.3
            Indicator   = "<"
            Description = "Percent of computer objects with Service Principal Names (SPN) configured"
            Status      = $null
        }
        UnknonwServiceClasses = @{
            Name        = "Unknown SPN Service Classes Found"
            Value       = $AdObjects.Data.UnknonwServiceClassesCount
            Threshold   = 0
            Indicator   = "="
            Description = "Discrete number of Service Principal Name (SPN) Service Classes observed where the purpose is not known"
            Status      = $null
        }
        HostBypassComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.HostBypassComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects with Service Principal Names (SPN) configured that overlap with the HOST SPN Service Class alias"
            Status      = $null
        }
        ServiceHosts = @{
            Name        = "Hostnames found in SPNs of computer objects"
            Value       = $AdObjects.Data.ServiceHostsRatio
            Threshold   = 2
            Indicator   = "<"
            Description = "Percent of unique Service Principal Names (SPN) hostnames configured relative to the total number of computer objects"
            Status      = $null
        }
        ServiceHostsComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.ServiceHostsComputersRatio
            Threshold   = 1
            Indicator   = "<"
            Description = "Percent of computer objects with Service Principal Names (SPN) configured relative to the total number of computer objects"
            Status      = $null
        }
        ServiceNoFqdnComputers = @{
            Name        = "Computers without SPN matching DNS Hostname"
            Value       = $AdObjects.Data.ServiceHostsComputersRatio
            Threshold   = 0
            Indicator   = "="
            Description = "Discrete number of computers without Fully Qualified Domain Name (FQDN) Service Principal Names (SPN)"
            Status      = $null
        }
        ServiceDnsBypassComputers = @{
            Name        = "Computers with SPN configured that overlaps with HOST alias"
            Value       = $AdObjects.Data.ServiceDnsBypassComputersRatio
            Threshold   = 0.00
            Indicator   = "="
            Description = "Percent of computer objects with Service Principal Names (SPN) configured with a service hostname that does not match their DNS hostname"
            Status      = $null
        }
    }
    #endregion

    #region Processing
    foreach($test in $Tests.GetEnumerator()){
        switch($test.Value.Indicator){
            "=" {
                $test.Value.Status = $test.Value.Value -eq $test.Value.Threshold
            }
            "<" {
                $test.Value.Status = $test.Value.Value -lt $test.Value.Threshold
            }
            "<=" {
                $test.Value.Status = $test.Value.Value -le $test.Value.Threshold
            }
            ">" {
                $test.Value.Status = $test.Value.Value -gt $test.Value.Threshold
            }
            ">=" {
                $test.Value.Status = $test.Value.Value -ge $test.Value.Threshold
            }
        }
    }

    $result = $true
    $testResultMarkdown = $null
    foreach($test in $Tests.GetEnumerator()){
        [int]$result *= [int]$test.Value.Status

        $testResultMarkdown += "#### $($test.Value.Name)`n`n"
        $testResultMarkdown += "$($test.Value.Description)`n`n"
        $testResultMarkdown += "| Current State Value | Comparison | Threshold |`n"
        $testResultMarkdown += "| - | - | - |`n"
        $testResultMarkdown += "| $($test.Value.Value) | $($test.Value.Indicator) | $($test.Value.threshold) |`n`n"
        if($test.Value.Status){
            $testResultMarkdown += "Well done. Your current state is in alignment with the threshold.`n`n"
        }else{
            $testResultMarkdown += "Your current state is **NOT** in alignment with the threshold.`n`n"
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return [bool]$result
    #endregion
}
