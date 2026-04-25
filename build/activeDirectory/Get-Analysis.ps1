#Function Nesting
#Get-Analysis calls
##ConvertFrom-(AdRecon|DomainState|GpoState|AdDacls) calls
###ConvertFrom-Wrapper calls
####$(AdRecon|DomainState|GpoState|AdDaclsAdD)(FILE) scriptblocks

<#TODO
Control to category mapping
Rather than scriptblocks, separate file then organize by folder, allows more dynamic content to be added
-	Could ship in a module, but may not export those cmdlets
-	Make the controls discovered dynamically
o	New analysis in the folder
-	Each control ID goes into a file
Alias have a big performance impact
-	Alt+Shift+F
-	Josh King’s presentation
Audience persona – Aggregate findings by audience
#>

function Get-Analysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            Test-Path $_
        })]
        [string]$BasePath,
        [switch]$AdRecon,
        [switch]$DomainState,
        [switch]$GpoState,
        [switch]$AdDacls
    )

    begin {
        $BasePath = (Get-Item $BasePath).Parent.FullName + "\" +`
            (Get-Item $BasePath).BaseName
        Write-Debug "Normalized `$BasePath $BasePath"
    }

    process {
        $domains = Get-ChildItem $BasePath

        foreach ($domain in $domains.Name)
        {
            Write-Debug "[Analysis] Processing $domain"
            if ($AdRecon) { ConvertFrom-AdRecon -path $BasePath -domain $domain }
            if ($DomainState) { ConvertFrom-DomainState -path $BasePath -domain $domain }
            if ($GpoState) { ConvertFrom-GpoState -path $BasePath -domain $domain }
            if ($AdDacls) { ConvertFrom-AdDacls -path $BasePath -domain $domain}
        }
    }

    end{}
}

function ConvertFrom-AdRecon {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$path,
        [Parameter(Mandatory)]
        [string]$domain
    )

    begin {
        $topic="AdRecon"
        $files=@(
            "Computers.csv",
            "ComputerSPNs.csv",
            "DefaultPasswordPolicy.csv",
            "DNSNodes.csv",
            "DNSZones.csv",
            "Domain.csv",
            "DomainControllers.csv",
            "FineGrainedPasswordPolicy.csv",
            "Forest.csv",
            "gPLinks.csv",
            "GPOs.csv",
            "GroupChanges.csv",
            "GroupMembers.csv",
            "Groups.csv",
            "OUs.csv",
            "Printers.csv",
            "SchemaHistory.csv",
            "Sites.csv",
            "Subnets.csv",
            "Trusts.csv",
            "Users.csv",
            "UserSPNs.csv"
        )
        $mapping=@{}

        $pathFiles=Get-ChildItem "$path\$domain"

        foreach ($file in $files)
        {
            if ($file -notin $pathFiles.Name)
            {
                Write-Warning "[Analysis][$topic] $file not found in $path"
            }

            $mapping.Add($file,"$($file.Substring(0,$file.IndexOf(".")))")
        }
    }

    process {
        foreach ($cmdlet in $mapping.Keys)
        {
            if ($cmdlet -like "*spns*")
            {
                Write-Debug "[Analysis][$topic] Processing $($mapping[$cmdlet]) for file $cmdlet with known SPNs"
                Invoke-Expression "ConvertFrom-Wrapper -path $path -domain $domain -file $cmdlet -suffix $($mapping[$cmdlet]) -topic $topic -spns"
            }
            else
            {
                Write-Debug "[Analysis][$topic] Processing $($mapping[$cmdlet]) for file $cmdlet"
                Invoke-Expression "ConvertFrom-Wrapper -path $path -domain $domain -file $cmdlet -suffix $($mapping[$cmdlet]) -topic $topic"
            }
        }
    }

    end {}
}

function ConvertFrom-DomainState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$path,
        [Parameter(Mandatory)]
        [string]$domain
    )

    begin {
        $topic="DomainState"
        $files=@(
            "Dfsrmig.txt",
            "get-AdConfiguration.json",
            "get-Addfsrsubscribers.json",
            "get-Addomain.json",
            "get-Addomaincontroller.json",
            "get-Adforest.json",
            "get-Adkrbtgt.json",
            "get-Adoptionalfeature.json",
            "get-Adreplicationconnection.json",
            "get-Adrootdse.json",
            "get-Adserviceaccount.json",
            "get-AdComputer.json"
        )
        $mapping=@{}

        $pathFiles=Get-ChildItem "$path\$domain"

        foreach ($file in $files)
        {
            if ($file -notin $pathFiles.Name)
            {
                Write-Warning "[Analysis][$topic] $file not found in $path"
            }

            if ($file -like "get-*")
            {
                $suffix = $($file.Substring(4,$file.IndexOf(".")-4))
            }
            else
            {
                $suffix = $($file.Substring(0,$file.IndexOf(".")))
            }

            $mapping.Add($file,$suffix)
        }
    }

    process {
        foreach ($cmdlet in $mapping.Keys)
        {
            Write-Debug "[Analysis][$topic] Processing $($mapping[$cmdlet]) for file $cmdlet"
            Invoke-Expression "ConvertFrom-Wrapper -path $path -domain $domain -file $cmdlet -suffix $($mapping[$cmdlet]) -topic $topic"
        }
    }

    end {}
}

function ConvertFrom-GpoState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$path,
        [Parameter(Mandatory)]
        [string]$domain
    )

    begin {
        $topic="GpoState"
        $files=@(
            "get-gpo.json",
            "GpoReports"
        )
        $mapping=@{}

        $pathFiles=Get-ChildItem "$path\$domain"

        foreach ($file in $files)
        {
            if ($file -notin $pathFiles.Name)
            {
                Write-Warning "[Analysis][$topic] $file not found in $path"
            }

            if ($file -like "get-*")
            {
                $suffix = $($file.Substring(4,$file.IndexOf(".")-4))
            }
            else
            {
                $suffix = $($file)
            }

            $mapping.Add($file,$suffix)
        }
    }

    process {
        foreach ($cmdlet in $mapping.Keys)
        {
            Write-Debug "[Analysis][$topic] Processing $($mapping[$cmdlet]) for file $cmdlet"
            Invoke-Expression "ConvertFrom-Wrapper -path $path -domain $domain -file $cmdlet -suffix $($mapping[$cmdlet]) -topic $topic"
        }
    }

    end {}
}

function ConvertFrom-AdDacls {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$path,
        [Parameter(Mandatory)]
        [string]$domain
    )

    begin {
        $topic="AdDacls"
        $files=@(
            "Get-Acls-*.csv"
        )
        $mapping=@{}

        $pathFiles=Get-ChildItem "$path\$domain"

        $aclFiles=(Get-ChildItem "$path\$domain\$files").Name

        if ((($aclFiles|measure).Count) -ne 1) {
            Write-Warning "[Analysis][$topic] Found less than or more than one file for 'Get-Acls*.csv' in $path"
        }

        foreach ($file in $aclFiles)
        {
            if ($file -notin $pathFiles.Name)
            {
                Write-Warning "[Analysis][$topic] $file not found in $path"
            }

            $suffix = "AdD$($file.Substring(4,4))"

            $mapping.Add($file,$suffix)
        }
    }

    process {
        foreach ($cmdlet in $mapping.Keys)
        {
            Write-Debug "[Analysis][$topic] Processing $($mapping[$cmdlet]) for file $cmdlet"
            Invoke-Expression "ConvertFrom-Wrapper -path $path -domain $domain -file $cmdlet -suffix $($mapping[$cmdlet]) -topic $topic"
        }
    }

    end {}
}

function ConvertFrom-Wrapper {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$path,
        [Parameter(Mandatory)]
        [string]$domain,
        [Parameter(Mandatory)]
        [ValidateScript({
            Test-Path "$path\$domain\$_"
        })]
        [string]$file,
        [Parameter(Mandatory)]
        [string]$suffix,
        [Parameter(Mandatory)]
        [string]$topic,
        [Parameter()]
        [switch]$spns
    )

    begin {
        #1/22
        #XicNotifier,Unknown
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
"@
        $knownSpns=$knownSpns|ConvertFrom-Csv

        $obj=@()

        if ($spns)
        {
            Write-Debug "[Analysis][$topic][$suffix] Invoking scriptblock $topic$suffix with known SPNs"
            $controls = Invoke-Command -ScriptBlock (Get-Variable -Name "$topic$suffix" -ValueOnly) -ArgumentList $path,$domain,$file,$knownSpns
        }
        else
        {
            Write-Debug "[Analysis][$topic][$suffix] Invoking scriptblock $topic$suffix"
            $controls = Invoke-Command -ScriptBlock (Get-Variable -Name "$topic$suffix" -ValueOnly) -ArgumentList $path,$domain,$file
        }
}

    process {
        foreach ($control in $controls.Keys)
        {
            Write-Debug "[Analysis][$topic][$suffix] Processing $control"
            foreach ($finding in $controls[$control])
            {
                $obj += [PSCustomObject]@{
                    domain = $domain
                    file = $file
                    topic = $topic
                    control = $control
                    finding = $finding
                }
            }
        }
    }

    end {
        return $obj|Sort-Object control
    }
}

#region AdRecon Scriptblocks
$AdReconComputers = {
    param($path,$domain,$file)
    $computers=Import-Csv "$path\$domain\$file"
    $enabledComputers=$computers|?{$_.Enabled -eq "True"}

    $controls=@{
        "$file.01"="$(($computers|?{$_.Enabled -eq "False"}|measure).Count)/$(($computers|measure).Count) Computer Objects are Disabled"
        "$file.02"="$(($computers|?{$_."Dormant (> 90 days)" -eq "True"}|measure).Count)/$(($computers|measure).Count) Computer Objects are Dormant (Inactive for more than 90 days)"
        "$file.03"="$(($enabledComputers|?{$_."ms-ds-CreatorSid" -ne ''}|measure).Count)/$(($enabledComputers|measure).Count) enabled Computer Objects have an ms-ds-CreatorSid attribute set"
        "$file.04"="$(($enabledComputers|?{$_."Primary Group ID" -notin @(515,516,521)}|measure).Count)/$(($enabledComputers|measure).Count) enabled Computer Objects have a non-standard Primary Group ID"
        "$file.05"="$(($enabledComputers|?{$_.SIDHistory -ne ''}|measure).Count)/$(($enabledComputers|measure).Count) enabled Computer Objects have a SID History attribute set"
        "$file.06"="$(($enabledComputers|select @{n="BaseDN";e={($_.'Distinguished Name').Substring(($_.'Distinguished Name').IndexOf(",")+1)}}|?{$_.BaseDN -like "CN=Computers*"}|measure).Count)/$(($enabledComputers|measure).Count) enabled Computer Objects reside in the default Computers Container"
        "$file.07"="$(($enabledComputers|select @{n="BaseDN";e={($_.'Distinguished Name').Substring(($_.'Distinguished Name').IndexOf(",")+1)}}|group BaseDN|measure).Count) distinct OUs contain enabled computer objects"
        "$file.08"="$([Math]::Round(($enabledComputers|select @{n="BaseDN";e={($_.'Distinguished Name').Substring(($_.'Distinguished Name').IndexOf(",")+1)}}|group BaseDN|measure -Sum Count).Sum/($enabledComputers|select @{n="BaseDN";e={($_.'Distinguished Name').Substring(($_.'Distinguished Name').IndexOf(",")+1)}}|group BaseDN|measure).Count,2)) enabled Computers per distinct container"
        "$file.09"="$(($enabledComputers|group 'Delegation Type','Delegation Protocol','Delegation Services'|?{$_.Name -ne ", , "}|measure).Count) enabled computers have delegations configured"
        "$file.10"=($enabledComputers|group 'Delegation Type','Delegation Protocol','Delegation Services'|?{$_.Name -ne ", , "}|sort Count -Descending|%{"$($_.Count)/$(($enabledComputers|measure).Count) enabled computer objects have $(($_.Name).Split(",").Trim()[0]) $(($_.Name).Split(",").Trim()[1]) delegation to $(($_.Name).Split(",").Trim()[2]) service provider"})
    }

    return $controls
}

#TODO - Handle Overlapping SPNS
$AdReconComputerSpns = {
    param($path,$domain,$file,$knownSpns)
    $computerSpns=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($computerSpns|group service|measure).Count) distinct SPN Service Classes are in use"
        "$file.02"=$computerSpns|group Service|sort Count|%{"SPN Service Class $($_.Name) was in use with $($_.Count) computers"}
        "$file.03"="$(($computerSpns|?{$_.Service -notin $knownSpns.SPN}|group Service|measure).Count) distinct unidentified SPN Service Classes were in use"
        "$file.04"=$computerSpns|?{$_.Service -notin $knownSpns.SPN}|group Service|sort Count|%{"Unidentified SPN Service Class $($_.Name) was in use with $($_.Count) computers"}
        "$file.05"="$(($computerSpns|?{$_.Host -notlike "*.*"}|measure).Count)/$(($computerSpns|measure).Count) hosts do not have an FQDN available for a defined service class"
    }

    return $controls
}

$AdReconDefaultPasswordPolicy = {
    param($path,$domain,$file)
    $defaultPassword=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($defaultPassword|?{$_.Policy -eq 'Enforce password history (passwords)'}).'Current Value') prior passwords are monitered for password history"
        "$file.02"="$(($defaultPassword|?{$_.Policy -eq 'Maximum password age (days)'}).'Current Value') days is current maximum password age"
        "$file.03"="$(($defaultPassword|?{$_.Policy -eq 'Minimum password length (characters)'}).'Current Value') characters is the current minimum password length"
        "$file.04"="$(($defaultPassword|?{$_.Policy -eq 'Password must meet complexity requirements'}).'Current Value'), password complexity is required"
        "$file.05"="$(($defaultPassword|?{$_.Policy -eq 'Store password using reversible encryption for all users in the domain'}).'Current Value'), reversible encryption is in use"
        "$file.06"="$(($defaultPassword|?{$_.Policy -eq 'Account lockout duration (mins)'}).'Current Value') minutes is current account lockout duration"
        "$file.07"="$(($defaultPassword|?{$_.Policy -eq 'Account lockout threshold (attempts)'}).'Current Value') failed attempts will trigger an account lockout"
    }

    return $controls
}

$AdReconDNSNodes = {
    param($path,$domain,$file)
    $dnsNodes=Import-Csv "$path\$domain\$file"
    #@('a'..'m')|%{((Resolve-Dns "$_.root-servers.net").AllRecords|?{$_.RecordType -eq "A"}).Address.IPAddressToString}
    #7/2023
    $rootServers=@{
        "a.root-servers.net"="198.41.0.4";
        "b.root-servers.net"="199.9.14.201";
        "c.root-servers.net"="192.33.4.12";
        "d.root-servers.net"="199.7.91.13";
        "e.root-servers.net"="192.203.230.10";
        "f.root-servers.net"="192.5.5.241";
        "g.root-servers.net"="192.112.36.4";
        "h.root-servers.net"="198.97.190.53";
        "i.root-servers.net"="192.36.148.17";
        "j.root-servers.net"="192.58.128.30";
        "k.root-servers.net"="193.0.14.129";
        "l.root-servers.net"="199.7.83.42";
        "m.root-servers.net"="202.12.27.33"
    }

    $defaultZones=@("RootDNSServers","..TrustAnchors")
    $excludedRecords=@("SOA","NS")
    $records=@("_ldap","_gc","_kerberos","_kpasswd")

    $controls=@{
        "$file.01"="$(($dnsNodes|group ZoneName|measure).Count) DNS Zones have records"
        "$file.02"="$(($dnsNodes|group ZoneName|measure).Count-($dnsNodes|?{$_.RecordType -notin @("SOA","NS")}|group ZoneName|measure).Count)/$(($dnsNodes|group ZoneName|measure).Count) DNS Zones only include SOA or NS records"
        "$file.03"="$(($dnsNodes|?{$_.ZoneName -eq "RootDNSServers" -and $_.Name -ne "@"}|select Name,Data -Unique|sort Name|?{$rootServers.$($_.Name) -ne $_.Data}|measure).Count) Root Servers have incorrect IP addresses"
        "$file.04"=$dnsNodes|?{$_.ZoneName -eq "RootDNSServers" -and $_.Name -ne "@"}|select Name,Data -Unique|sort Name|?{$rootServers.$($_.Name) -ne $_.Data}|%{"Root Server $($_.Name) has an incorrect IP address of $($_.Data), correct is $($rootServers.$($_.Name))"}
        "$file.05"="$(($dnsNodes|?{$_.TimeStamp -ne "[static]"}|measure).Count)/$(($dnsNodes|measure).Count) DNS records are dynamic"
        "$file.06"="$(($dnsNodes|?{$_.ZoneName -notin $defaultZones -and $_.ZoneName -notlike "*.in-addr.arpa" -and $_.ZoneName -notlike "_msdcs.*" -and $_.RecordType -notin $excludedRecords}|group ZoneName|measure).Count) Zones have records other than SOA and NS"
        "$file.07"=$dnsNodes|?{$_.ZoneName -notin $defaultZones -and $_.ZoneName -notlike "*.in-addr.arpa" -and $_.ZoneName -notlike "_msdcs.*" -and $_.RecordType -notin $excludedRecords}|group ZoneName|sort Count -Descending|%{"$($_.Name) Zone has $($_.Count) records (excluding SOA and NS)"}
        "$file.13"="$(($dnsNodes|?{$_.RecordType -eq "NS" -and $_.Name -ne "@"}|measure).Count) Zone delegations exist"
        "$file.08"=$dnsNodes|?{$_.RecordType -eq "NS" -and $_.Name -ne "@"}|%{"Zone delegation exists for $($_.Name).$($_.ZoneName). to $($_.Data)"}
        "$file.09"=$dnsNodes|?{$_.RecordType -eq "SOA" -and $_.ZoneName -notlike "*.in-addr.arpa"}|%{"SOA for zone $($_.ZoneName) is $($_.Data)"}
        "$file.10"="$(($records|%{$record=$_;$dnsNodes|?{$_.Name -like "$($record).*"}}|select RecordType,@{n="Record";e={$_.Name+"."+$_.ZoneName}},Data|measure).Count) AD DS SRV records exist"
        "$file.11"=$records|%{$record=$_;$dnsNodes|?{$_.Name -like "$($record).*"}}|select RecordType,@{n="Record";e={$_.Name+"."+$_.ZoneName}},Data|%{"AD DS SRV Record for $($_.Data) exists at $($_.Record)"}
        "$file.12"="$(($dnsNodes|?{$_.ZoneName -eq "..TrustAnchors" -and $_.Name -ne "@"}|measure).Count) DNSSEC Records are configured"
    }

    return $controls
}

$AdReconDNSZones = {
    param($path,$domain,$file)
    $dnsZones=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($dnsZones|?{$_.RecordCount -eq 0}|measure).Count)/$(($dnsZones|measure).Count) DNS Zones have 0 records"
        "$file.02"="$(($dnsZones|?{$_.Name -like "..InProgress-*" -or $_.Name -like "* CNF:*"}|measure).Count)/$(($dnsZones|measure).Count) DNS Zones are duplicates (requires validation on each domain controller)"
        "$file.03"="$(($dnsZones|?{$_.Name -like "*.in-addr.arpa"}|measure).Count)/$(($dnsZones|measure).Count) DNS Zones are for reverse lookup"
        "$file.04"="$(($dnsZones|?{$_.Name -notmatch "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$" -and $_.Name -ne "..TrustAnchors" -and $_.Name -notlike "_msdcs.*"}|measure).Count) DNS Zones do not meet standards"
        "$file.05"=$dnsZones|?{$_.Name -notmatch "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$" -and $_.Name -ne "..TrustAnchors" -and $_.Name -notlike "_msdcs.*"}|%{"$($_.Name) does not meet standards for internet domain names (RFCs 952, 1035, 1123)"}
        "$file.06"="$(($dnsZones|?{$_.Name -like "*.in-addr.arpa"}|select @{n="Network";e={$y=($_.Name.Substring(0,$_.Name.IndexOf(".in-addr"))).Split(".");[array]::Reverse($y);$y -join "."}}|measure).Count) Reverse Lookup Zones exist"
        "$file.07"=$dnsZones|?{$_.Name -like "*.in-addr.arpa"}|select @{n="Network";e={$y=($_.Name.Substring(0,$_.Name.IndexOf(".in-addr"))).Split(".");[array]::Reverse($y);$y -join "."}}|%{"$($_.Network) Reverse Lookup Zone exists"}
    }

    return $controls
}

$AdReconDomain = {
    param($path,$domain,$file)
    $domains=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($domains|?{$_.Category -eq 'Functional Level'}).Value) Domain Functional Level"
        "$file.02"="$(($domains|?{$_.Category -eq 'ms-DS-MachineAccountQuota'}).Value) computers for ms-DS-MachineAccountQuota (default 10)"
        "$file.03"="$(($domains|?{$_.Category -eq 'Domain Controller'}|measure).Count) domain controllers within the domain"
        "$file.04"="$(($domains|?{$_.Category -eq 'RIDs Remaining'}).Value) RIDs Remaining in the domain"
        "$file.05"="$(($domains|?{$_.Category -eq 'Name'}|?{$_.Value -notmatch "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"}|measure).Count) domains do not meet standards"
        "$file.06"=$domains|?{$_.Category -eq 'Name'}|?{$_.Value -notmatch "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"}|%{"$($_.Value) does not meet standards for internet domain names (RFCs 952, 1035, 1123)"}
        "$file.07"="$(($domains|?{$_.Category -eq 'NetBIOS'}|?{$_.Value -notmatch "^([a-zA-Z0-9]{0,15})?$"}|measure).Count) NetBIOS namespaces do not meet standards"
        "$file.08"=$domains|?{$_.Category -eq 'NetBIOS'}|?{$_.Value -notmatch "^([a-zA-Z0-9]{0,15})?$"}|%{"$($_.Value) does not meet standards for internet domain names (RFCs 952, 1035, 1123)"}
    }

    return $controls
}

$AdReconDomainControllers = {
    param($path,$domain,$file)
    $domainControllers=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($domainControllers|group site|measure).Count) Sites have active domain controllers"
        "$file.02"="$(($domainControllers|?{$_.'SMB1(NT LM 0.12)' -eq "True"}|measure).Count)/$(($domainControllers|measure).Count) domain controllers have SMBv1 enabled"
        "$file.03"="$(($domainControllers|?{$_.'SMB3(0x0311)' -eq "True"}|measure).Count)/$(($domainControllers|measure).Count) domain controllers have SMBv3.1.1 enabled"
        "$file.04"="$(($domainControllers|?{$_.'SMB Signing' -eq "True"}|measure).Count)/$(($domainControllers|measure).Count) domain controllers have SMB Signing enabled"
        "$file.05"="$(($domainControllers|?{$_.Infra -ne "False" -and $_.Naming -ne "False" -and $_.Schmea -ne "False" -and $_.RID -ne "False" -and $_.PDC}|measure).Count) domain controllers hold all 5 FSMO roles"
        "$file.06"=$domainControllers|?{$_.Infra -ne "False" -and $_.Naming -ne "False" -and $_.Schmea -ne "False" -and $_.RID -ne "False" -and $_.PDC}|%{"$($_.Name) holds all 5 FSMO roles"}
        "$file.07"="$((($domainControllers|group 'Operating System'|measure).Count)) Opearting System Environment is in use by domain controllers"
        "$file.08"=$domainControllers|group 'Operating System'|%{"$($_.Count)/$(($domainControllers|measure).Count) domain controllers use $($_.Name)"}
    }

    return $controls
}

$AdReconFineGrainedPasswordPolicy = {
    param($path,$domain,$file)
    $fgpps=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($fgpps|group Policy|select -First 1).Count) Fine Grained Password Policies are available"
        "$file.02"=$fgpps|group Policy|?{$_.Name -ne 'Name' -and $_.Name -ne 'Applies To'}|%{"$($_.Name) has $(($_.Group|group Value|measure).Count) distinct values across $(($fgpps|group Policy|select -First 1).Count) policies"}
        "$file.03"=$fgpps|group Policy|?{$_.Name -ne 'Name' -and $_.Name -ne 'Applies To'}|%{$policy=$_.Name;$_.Group|group Value|%{"$($_.Count) policies have $policy set to $($_.Name)"}}
        "$file.04"=$fgpps|group Policy|?{$_.Name -eq 'Applies To'}|%{$policy=$_.Name;$_.Group|group Value|%{"$($_.Count) policies have $policy set to $($_.Name)"}}
    }

    return $controls
}

$AdReconForest = {
    param($path,$domain,$file)
    $forest=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($forest|?{$_.Category -eq 'Functional Level'}).Value) Forest Functional Level"
        "$file.02"="$(($forest|?{$_.Category -eq 'Domain'}|measure).Count) domains in the forest"
        "$file.03"="$(($forest|?{$_.Category -eq 'Tombstone Lifetime'}).Value) days for Tombstone Lifetime (default 60 or 180, if blank assume 60)"
        "$file.04"="$(($forest|?{$_.Category -eq 'Recycle Bin (2008 R2 onwards)'}).Value), Active Directory Domain Service Recycle Bin"
    }

    return $controls
}

#TODO - #$gpLinks|?{$_.gPLink -ne ""}|group DistinguishedName|sort Count -Descending|%{"$($_.Name) has $($_.Count) GPO Links set"}
$AdReconGpLinks = {
    param($path,$domain,$file)
    $gpLinks=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($gpLinks|group GPO|?{$_.Name -ne ''}|measure).Count) distinct GPOs with links"
        "$file.02"="$(($gpLinks|?{$_.'Link Enabled' -eq 'False' -and $_.GPO -ne ''}|measure).Count)/$(($gpLinks|?{$_.'GPO' -ne ''}|measure).Count) GPO Links are disabled"
        "$file.03"="$(($gpLinks|?{$_.GPO -eq ''}|measure).Count) targets do not have GPOs linked"
        "$file.04"="$(($gpLinks|?{$_.Enforced -eq "True"}|measure).Count)/$(($gpLinks|?{$_.'GPO' -ne ''}|measure).Count) GPOs are enforced"
        "$file.05"="$(($gpLinks|?{$_.BlockInheritance -eq "True"}|measure).Count) targets block inheritance"
        "$file.06"="$(($gpLinks|?{$_.gPLink -ne ''}|group DistinguishedName|measure).Count) OUs have GPO Links set"
    }

    return $controls
}

$AdReconGPOs = {
    param($path,$domain,$file)
    $gpos=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($gpos|measure).Count) GPOs exist"
        "$file.02"="$(($gpos|?{[datetime]$_.whenCreated -lt (Get-Date -Date "2020-01-01T00:00:00")}|measure).Count)/$(($gpos|measure).Count) were created prior to 1/1/2020"
        "$file.03"="$(($gpos|?{[datetime]$_.whenChanged -lt (Get-Date -Date "2020-01-01T00:00:00")}|measure).Count)/$(($gpos|measure).Count) were changed prior to 1/1/2020"
        "$file.04"="$(($gpos.DisplayName|?{$_ -notin $gpLinks.GPO}|measure).Count) GPOs do not have any links set"
        "$file.05"=$gpos.DisplayName|?{$_ -notin $gpLinks.GPO}|%{"$_ has no Links configured"}
    }

    return $controls
}

$AdReconGroupChanges = {
    param($path,$domain,$file)
    $groupChanges=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($groupChanges|select @{n='Year';e={([datetime]$_.'Added Date').Year}}|group Year|sort Year -Descending|measure Count -Average).Average) average group additions per year since $(($groupChanges|select @{n='Year';e={([datetime]$_.'Added Date').Year}}|group Year|sort Name -Descending|select -Last 1).Name)"
    }

    return $controls
}

$AdReconGroups = {
    param($path,$domain,$file)
    $groups=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($groups|group AdminCount|?{$_.Name -eq "1"}).Count)/$(($groups|measure).Count) Group objects have Admin Count set"
        "$file.02"="$(($groups|?{$_.DistinguishedName -like "*,CN=*"}|measure).Count)/$(($groups|measure).Count) Group objects reside within a Container object"
        "$file.03"="$(($groups|?{[datetime]$_.whenChanged -lt (Get-Date -Date "2020-01-01T00:00:00")}|measure).Count)/$(($groups|measure).Count) Group objects were changed prior to 1/1/2020"
        "$file.04"="$(($groups|?{$_.ManagedBy -ne ''}|measure).Count)/$(($groups|measure).Count) Group objects have a manager set"
        "$file.05"="$(($groups|?{$_.SIDHistory -ne ''}|measure).Count)/$(($groups|measure).Count) Group objects have SID History set"
        "$file.06"="$(($groups|?{$_.GroupCategory -eq "Distribution" -or $_.GroupCategory -eq "0"}|measure).Count)/$(($groups|measure).Count) distribution groups exist"
        "$file.07"="$(($groups|?{$_.GroupCategory -eq "Security" -or $_.GroupCategory -eq "1"}|measure).Count)/$(($groups|measure).Count) security groups exist"
        "$file.08"="$(($groups|?{$_.GroupScope -eq "DomainLocal" -or $_.GroupScope -eq "0"}|measure).Count)/$(($groups|measure).Count) Domain Local groups exist"
        "$file.09"="$(($groups|?{$_.GroupScope -eq "Global" -or $_.GroupScope -eq "1"}|measure).Count)/$(($groups|measure).Count) Global groups exist"
        "$file.10"="$(($groups|?{$_.GroupScope -eq "Universal" -or $_.GroupScope -eq "2"}|measure).Count)/$(($groups|measure).Count) Universal groups exist"
    }

    return $controls
}

$AdReconPrinters = {
    param($path,$domain,$file)
    $printers=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($printers|measure).Count) Printers exist in the domain"
    }

    return $controls
}

$AdReconSchemaHistory = {
    param($path,$domain,$file)
    $schema=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($schema|select @{n='Year';e={([datetime]$_.whenCreated).Year}}|?{$_.Year -ne "1630"}|Group Year|measure).Count) years have additions to the schema with the earliest in $(($schema|select @{n='Year';e={([datetime]$_.whenCreated).Year}}|?{$_.Year -ne "1630"}|Group Year|sort Name -Descending|select -Last 1).Name)"
        "$file.02"=$schema|select @{n='Year';e={([datetime]$_.whenCreated).Year}}|?{$_.Year -ne "1630"}|Group Year|%{"$($_.Count) schema creations occured in $($_.Name)"}
        "$file.03"="$(($schema|?{$_.DistinguishedName -match ".{0,}Schema.{0,}Version.{0,}"}|measure).Count) Schema Version entries found"
        "$file.04"=$schema|?{$_.DistinguishedName -match ".{0,}Schema.{0,}Version.{0,}"}|sort WhenCreated -Descending|%{"$($_.Name) added $(([datetime]$_.WhenCreated).ToString("MM/dd/yyyy"))"}
        "$file.05"="$([bool]($schema|?{$_.DistinguishedName -like "CN=ms-mcs-admpwd,*"}|measure).Count) LAPS is installed"
    }

    return $controls
}

$AdReconSites = {
    param($path,$domain,$file)
    $sites=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($sites|measure).Count) Sites exist in the domain"
        "$file.02"="$(($sites|?{$_.Name -notin ($domainControllers|group Site).Name}|measure).Count)/$(($sites|measure).Count) Sites do not have a domain controller association"
        "$file.03"=$sites|?{$_.Name -notin ($domainControllers|group Site).Name}|%{"Site $($_.Name) does not have any associated domain controllers"}
    }

    return $controls
}

$AdReconSubnets = {
    param($path,$domain,$file)
    $subnets=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($subnets|measure).Count) Subnets exist in the domain"
        "$file.02"="$(($subnets|group Site|measure).Count) distinct Sites have subnet associations"
        "$file.03"="$(($subnets|?{$_.Name -in @("10.0.0.0/8","172.16.0.0/12","192.168.0.0/16")}|measure).Count) catch-all subnets configured"
        "$file.04"="$(($sites|?{$_.Name -notin ($subnets|group Site).Name}|measure).Count)/$(($sites|measure).Count) Sites have no subnet associations"
        "$file.05"=$sites|?{$_.Name -notin ($subnets|group Site).Name}|%{"Site $($_.Name) does not have any subnet associations"}
        "$file.06"="$(($subnets|?{$_.Name.Substring(0,$_.Name.IndexOf("/")) -match "/^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/"}|measure).Count) subnets are configured for IPv6 (per RFC4291 legal cases)"
        "$file.07"="$(($subnets|?{$_.Name -eq "::/128"}|measure).Count) IPv6 catch-all subnets configured"
        "$file.08"="$(($subnets|?{$_.Name -notlike "10.*" -and $_.Name -notmatch "172\.([1][6-9]|[2][0-9]|[3][0-1])\..*" -and $_.Name -notlike "192.168.*"}|measure).Count) subnets are not internal ranges (per RFC1918)"
        "$file.09"=$subnets|?{$_.Name -notlike "10.*" -and $_.Name -notmatch "172\.([1][6-9]|[2][0-9]|[3][0-1])\..*" -and $_.Name -notlike "192.168.*"}|%{"$($_.Name) in site $($_.Site) is an Internet address"}
        "$file.10"="$(($subnets|select @{n='1st8';e={$_.Name.Substring(0,$_.Name.IndexOf('.'))}}|group 1st8|measure).Count) distinct first one octets are used in subnets"
        "$file.11"="$(($subnets|select @{n='2nd8';e={$_.Name.Substring(0,$_.Name.IndexOf('.',$_.Name.IndexOf('.')+1))}}|group 2nd8|measure).Count) distinct first two octets are used in subnets"
        "$file.12"="$(($subnets|select @{n='3rd8';e={$_.Name.Substring(0,$_.Name.LastIndexOf('.'))}}|group 3rd8|measure).Count) distinct first three octets are used in subnets"
        "$file.13"="$(($subnets|?{$_.Site -eq ''}|measure).Count) subnets do not have a site association"
        "$file.14"=$subnets|?{$_.Site -eq ''}|%{"$($_.Name) subnets do not have a site association"}
    }

    return $controls
}

$AdReconTrusts = {
    param($path,$domain,$file)
    $trusts=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($trusts|measure).Count) trusts exist"
        "$file.02"="$(($trusts|?{$_.Attributes -notlike "*Within Forest*"}|measure).Count)/$(($trusts|measure).Count) trusts are inter-forest"
        "$file.03"="$(($trusts|?{$_.Attributes -like "*Quarantined*"}|measure).Count)/$(($trusts|measure).Count) trusts are quarantined"
        "$file.04"=$trusts|?{$_.Attributes -notlike "*Quarantined*"}|%{"$($_.'Target Domain') trust is not quarantined"}
        "$file.05"=$trusts|%{"$($_.'Target Domain') has a $($_.'Trust Direction') $($_.'Trust Type') with $($_.Attributes) attributes"}
        "$file.06"="$(($trusts|?{[datetime]$_.whenChanged -lt (Get-Date).AddDays(-60)}|measure).Count)/$(($trusts|measure).Count) trusts are stale (>60 days since last change, needs validation on each domain controller)"
        "$file.07"=$trusts|?{[datetime]$_.whenChanged -lt (Get-Date).AddDays(-60)}|%{"$($_.'Target Domain') trust is stale"}
    }

    return $controls
}

$AdReconSites = {
    param($path,$domain,$file)
    $sites=Import-Csv "$path\$domain\$file"

    $controls=@{
        "$file.01"="$(($sites|measure).Count) Sites exist in the domain"
        "$file.02"="$(($sites|?{$_.Name -notin ($domainControllers|group Site).Name}|measure).Count)/$(($sites|measure).Count) Sites do not have a domain controller association"
        "$file.03"=$sites|?{$_.Name -notin ($domainControllers|group Site).Name}|%{"Site $($_.Name) does not have any associated domain controllers"}
    }

    return $controls
}

#"$domain,$file,users.csv.22,$(($users|?{$_.Description -like "*Built-in account for administering*"}|measure).Count) built-in administrator account identified"
#$users|?{$_.Description -like "*Built-in account for administering*"}|?{$_.Enabled -eq "True"}|%{"$domain,$file,users.csv.23,$($_.UserName) account is Enabled"}
#$users|?{$_.Description -like "*Built-in account for administering*"}|?{$_.Enabled -eq "True"}|%{"$domain,$file,users.csv.24,$($_.UserName) account last logged on $($_.'Last Logon Date')"}
#$users|?{$_.Description -like "*Built-in account for administering*"}|?{$_.Enabled -eq "True"}|%{"$domain,$file,users.csv.25,$($_.UserName) account password was last set $($_.'Password LastSet')"}
$AdReconUsers = {
    param($path,$domain,$file)
    $users=Import-Csv "$path\$domain\$file"
    $domainAdmin=$users|?{$_.SID -like "*S-1-5-*-500}" -or $_.SID -like "S-1-5-*-500"}
    $enabledusers=$users|?{$_.Enabled -eq "True"}

    $controls=@{
        "$file.01"="$(($users|?{$_.Enabled -eq "False"}|measure).Count)/$(($users|measure).Count) User objects are disabled"
        "$file.02"="$(($users|?{$_.Enabled -eq "True" -and $_.'Dormant (> 90 days)' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects are dormant (not logged in for > 90 days)"
        "$file.03"="$(($users|?{$_.Enabled -eq "True" -and $_.'Password Never Expires' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User object passwords never expire"
        "$file.04"="$(($users|?{$_.Enabled -eq "True" -and $_.'Reversible Password Encryption' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User object passwords are stored with reversible encryption"
        "$file.05"="$(($users|?{$_.Enabled -eq "True" -and $_.'Delegation Permitted' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User object allow delegation"
        "$file.06"="$(($users|?{$_.Enabled -eq "True" -and $_.'Kerberos DES Only' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects use DES only for Kerberos"
        "$file.07"="$(($users|?{$_.Enabled -eq "True" -and $_.'Does Not Require Pre Auth' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects do not require pre-authentication"
        "$file.08"="$(($users|?{$_.Enabled -eq "True" -and $_.'Never Logged in' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have never logged in"
        "$file.09"="$(($users|?{$_.Enabled -eq "True" -and $_.'Password Not Required' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects do not require a password"
        "$file.10"="$(($users|?{$_.Enabled -eq "True" -and $_.'Logon Workstations' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have workstation restrictions"
        "$file.11"="$(($users|?{$_.Enabled -eq "True" -and $_.'AdminCount' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have Admin Count set"
        "$file.12"="$(($users|?{$_.Enabled -eq "True" -and $_.'Primary GroupID' -ne "513"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have a Primary Group ID other than 513"
        "$file.13"="$(($users|?{$_.Enabled -eq "True" -and $_.'SIDHistory' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have SID History set"
        "$file.14"="$(($users|?{$_.Enabled -eq "True" -and $_.'HasSPN' -eq "True"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have an SPN set"
        "$file.15"="$(($users|?{$_.Enabled -eq "True" -and $_.'Manager' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have a manager set"
        "$file.16"="$(($users|?{$_.Enabled -eq "True" -and $_.'HomeDirectory' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have a Home Directory set"
        "$file.17"="$(($users|?{$_.Enabled -eq "True" -and $_.'ProfilePath' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have a Profile Path set"
        "$file.18"="$(($users|?{$_.Enabled -eq "True" -and $_.'ScriptPath' -ne ''}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects have a Script Path set"
        "$file.19"="$(($users|?{$_.Enabled -eq "True" -and $_.DistinguishedName -like "*,CN=*,DC=*"}|measure).Count)/$(($users|?{$_.Enabled -eq "True"}|measure).Count) enabled User objects reside in a Container object"
        "$file.20"="$(($users|?{$_.UserName -like "AAD_*" -or $_.UserName -like "MSOL_*" -or $_.UserName -eq "SUPPORT_388945a0" -or $_.UserName -like "CAS_*"}|measure).Count) known service accounts identified"
        "$file.21"=$users|?{$_.UserName -like "AAD_*" -or $_.UserName -like "MSOL_*" -or $_.UserName -eq "SUPPORT_388945a0" -or $_.UserName -like "CAS_*"}|%{"$($_.UserName) known service account identified"}
        "$file.22"="$(($domainAdmin|measure).Count) built-in administrator account identified"
        "$file.23"=$users|?{($_.SID -like "*S-1-5-*-500}" -or $_.SID -like "S-1-5-*-500") -and $_.Enabled -eq "True"}|%{"$($_.UserName) account is Enabled"}
        "$file.24"=$domainAdmin|%{"$($_.UserName) account last logged on $($_.'Last Logon Date')"}
        "$file.25"=$domainAdmin|%{"$($_.UserName) account password was last set $($_.'Password LastSet')"}
        "$file.26"="$(($users|?{$_.Description -like "*honey*"}|measure).Count) honey pot users identified"
        "$file.27"=$users|?{$_.Description -like "*honey*"}|%{"$($_.UserName) appears to be a honey pot based on description $($_.Description)"}
        "$file.28"="$(($enabledUsers|group 'Delegation Type','Delegation Protocol','Delegation Services'|?{$_.Name -ne ", , "}|measure).Count)/$(($enabledUsers|measure).Count) users have delegations configured"
        "$file.29"=($enabledUsers|group 'Delegation Type','Delegation Protocol','Delegation Services'|?{$_.Name -ne ", , "}|sort Count -Descending|%{"$($_.Count)/$(($enabledUsers|measure).Count) enabled user objects have $(($_.Name).Split(",").Trim()[0]) $(($_.Name).Split(",").Trim()[1]) delegation to $(($_.Name).Split(",").Trim()[2]) service provider"})
    }

    return $controls
}

$AdReconUserSPNs = {
    param($path,$domain,$file,$knownSpns)
    $userSPNs=Import-Csv "$path\$domain\$file"
    $users=Import-Csv "$path\$domain\Users.csv"
    $domainAdmin=$users|?{$_.SID -like "*S-1-5-*-500}"}

    $controls=@{
        "$file.01"="$(($userSpns|measure).Count) User SPNs in use"
        "$file.02"="$(($userSpns|group service|measure).Count) distinct SPN Service Classes are in use"
        "$file.03"=$userSpns|group Service|sort Count -Descending|%{"SPN Service Class $($_.Name) was in use with $($_.Count) users"}
        "$file.04"="$(($userSpns|?{$_.Service -notin $knownSpns.SPN}|group Service|measure).Count) distinct unidentified SPN Service Classes were in use"
        "$file.05"=$userSpns|?{$_.Service -notin $knownSpns.SPN}|group Service|sort Count -Descending|%{"Unidentified SPN Service Class $($_.Name) was in use with $($_.Count) users"}
        "$file.06"="$(($userSpns|?{$_.Host -notlike "*.*"}|measure).Count)/$(($userSpns|measure).Count) hosts do not have an FQDN available for a defined service class"
        "$file.07"="$(($userSpns|?{$_.Username -eq $domainAdmin.UserName}|measure).Count) SPNs associated with the Domain Admin"
        "$file.08"=$userSpns|?{$_.Username -eq $domainAdmin.UserName}|%{"Domain Admin SPN for $($_.Service) on $($_.Host)"}
    }

    return $controls
}

$AdReconOUs = {
    param($path,$domain,$file)
    $OUs=Import-Csv "$path\$domain\$file"
    $groups=Import-Csv "$path\$domain\Groups.csv"
    $users=Import-Csv "$path\$domain\Users.csv"
    $computers=Import-Csv "$path\$domain\computers.csv"

    $computerBaseDns=$computers|select @{n='BaseDN';e={$_.'Distinguished Name'.Substring($_.'Distinguished Name'.IndexOf(",OU=")+1)}} -Unique
    $userBaseDns=$users|select @{n='BaseDN';e={$_.DistinguishedName.Substring($_.DistinguishedName.IndexOf(",OU=")+1)}} -Unique
    $groupBaseDns=$groups|select @{n='BaseDN';e={$_.DistinguishedName.Substring($_.DistinguishedName.IndexOf(",OU=")+1)}} -Unique

    $controls=@{
        "$file.01"="$(($ous|group Name|?{$_.Count -gt 1}|measure).Count)/$(($ous|measure).Count) OU container objects have overlapping names"
        "$file.02"="$(($ous|?{$_.Depth -eq "1"}|measure).Count)/$(($ous|measure).Count) OU container objects are at the domain root"
        "$file.03"="$(($ous|?{[datetime]$_.whenChanged -lt (Get-Date -Date "2020-01-01T00:00:00")}|measure).Count)/$(($ous|measure).Count) OU container objects were changed prior to 1/1/2020"
        "$file.04"="$(($ous|?{$_.DistinguishedName -notin $computerBaseDns -and $_.DistinguishedName -notin $userBaseDns -and $_.DistinguishedName -notin $groupBaseDns}|measure).Count)/$(($ous|measure).Count) OUs do not contain any user, group, or computer objects"
        "$file.05"=$ous|?{$_.DistinguishedName -notin $computerBaseDns -and $_.DistinguishedName -notin $userBaseDns -and $_.DistinguishedName -notin $groupBaseDns}|%{"Group does not have any computer, group, or user objects: $($_.DistinguishedName)"}
    }

    return $controls
}

$AdReconGroupMembers = {
    param($path,$domain,$file)
    $groupMembers=Import-Csv "$path\$domain\$file"
    $groups=Import-Csv "$path\$domain\Groups.csv"
    $users=Import-Csv "$path\$domain\Users.csv"

    #https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory
    $privilegedGroups=@(
        "Access Control Assistance Operators",
        "Account Operators",
        "Administrators",
        "Allowed RODC Password Replication Group",
        "Backup Operators",
        "Cert Publishers",
        "Certificate Service DCOM Access",
        "Cloneable Domain Controllers",
        "Cryptographic Operators",
        "Debugger Users",
        "Denied RODC Password Replication Group",
        "DHCP Administrators",
        "DHCP Users",
        "Distributed COM Users",
        "DnsAdmins",
        "DnsUpdateProxy",
        "Domain Admins",
        "Domain Controllers",
        "Domain Guests",
        "Enterprise Admins",
        "Enterprise Key Admins",
        "Enterprise Read-only Domain Controllers",
        "Event Log Readers",
        "Group Policy Creator Owners",
        "Guests",
        "Hyper-V Administrators",
        "IIS_IUSRS",
        "Incoming Forest Trust Builders",
        "Network Configuration Operators",
        "Performance Log Users",
        "Performance Monitor Users",
        "Pre-Windows 2000 Compatible Access",
        "Print Operators",
        "RAS and IAS Servers",
        "RDS Endpoint Servers",
        "RDS Management Servers",
        "RDS Remote Access Servers",
        "Read-only Domain Controllers",
        "Remote Desktop Users",
        "Remote Management Users",
        "Replicator",
        "Schema Admins",
        "Server Operators",
        "Terminal Server License Servers",
        "Windows Authorization Access Group",
        "WinRMRemoteWMIUsers_",
        "WinRMRemoteWMIUsers__"
    )

    $emptyGroups=@(
        "Access Control Assistance Operators",
        "Account Operators",
        "Allowed RODC Password Replication Group",
        "Backup Operators",
        "Cert Publishers",
        "Certificate Service DCOM Access",
        "Cloneable Domain Controllers",
        "Cryptographic Operators",
        "Distributed COM Users",
        "DnsAdmins",
        "DnsUpdateProxy",
        "Enterprise Key Admins",
        "Enterprise Read-only Domain Controllers",
        "Event Log Readers",
        "Hybrid agent extension applications",
        "Hyper-V Administrators",
        "Incoming Forest Trust Builders",
        "Key Admins",
        "Network Configuration Operators",
        "Performance Log Users",
        "Performance Monitor Users",
        "Print Operators",
        "RAS and IAS Servers",
        "RDS Endpoint Servers",
        "RDS Management Servers",
        "RDS Remote Access Servers",
        "Read-only Domain Controllers",
        "Remote Desktop Users",
        "Remote Management Users",
        "Replicator",
        "Server Operators",
        "Storage Replica Administrators",
        "Terminal Server License Servers"
    )

    #https://docs.microsoft.com/en-us/exchange/plan-and-deploy/active-directory/ad-changes
    $exchangeGroups=@(
        "Compliance Management",
        "Delegated Setup",
        "Discovery Management",
        "Exchange Servers",
        "Exchange Trusted Subsystem",
        "Exchange Windows Permissions",
        "Exchange Domain Servers",
        "Exchange Enterprise Servers",
        "Exchange Admins",
        "ExchangeLegacyInterop",
        "Help Desk",
        "Hygiene Management",
        "Managed Availability Servers",
        "Organization Management",
        "Public Folder Management",
        "Recipient Management",
        "Records Management",
        "Server Management",
        "View-Only Organization Management"
    )

    $groupMemberCounts=$groupMembers|group 'Group Name'|select Name,Count
    $dormantPrivilege=($groupMemberCounts|?{$_.Name -in $privilegedGroups -and $_.Count -gt 0}|%{$group=$_.Name;$groupMembers|?{$_.'Group Name' -eq $group -and $_.AccountType -eq "user"}|%{$user=$_.'Member UserName';$users|?{$_.UserName -eq $user -and $_.'Dormant (> 90 days)' -eq "True"}|select @{n='Group';e={$group}},UserName}})

    $controls=@{
        "$file.01"="$(($groupMembers|group 'Group Name'|measure).Count) distinct groups have members"
        "$file.02"="$(($groupMembers|group AccountType|measure).Count) types of members are in groups"
        "$file.03"=$groupMembers|group AccountType|%{"$($_.Count) $($_.Name) members exist in groups"}
        "$file.04"="$(($groupMembers|?{$_.AccountType -eq "trust"}|measure).Count) trust members exist"
        "$file.05"=$groupMembers|?{$_.AccountType -eq "trust"}|group 'Group Name'|%{"$($_.Count)/$(($groupMembers|?{$_.AccountType -eq "trust"}|measure).Count) trust members exist in the $($_.Name) group"}
        "$file.06"="$(($groupMembers|?{$_.AccountType -eq "foreignSecurityPrincipal"}|select 'Group Name',@{n='DomainID';e={($_.'Member UserName').Substring(0,($_.'Member UserName').IndexOf('-',($_.'Member UserName').IndexOf('21-')+24))}}|group DomainID|measure).Count) Domain IDs are in use by foreignSecurityPrincipal group members"
        "$file.07"=$groupMembers|?{$_.AccountType -eq "foreignSecurityPrincipal"}|select 'Group Name',@{n='DomainID';e={($_.'Member UserName').Substring(0,($_.'Member UserName').IndexOf('-',($_.'Member UserName').IndexOf('21-')+24))}}|group DomainID|%{"$($_.Count) foreignSecurityPrincipal members exist in $($_.Name)"}
        "$file.08"="$(($groupMemberCounts|?{$_.Name -notin $emptyGroups -and $_.Name -notin $privilegedGroups -and $_.Count -eq 0}|measure).Count)/$(($groups|measure).Count) groups have no members and are not a built-in priveleged or empty group"
        "$file.09"=$groupMemberCounts|?{$_.Name -notin $emptyGroups -and $_.Name -notin $privilegedGroups -and $_.Count -eq 0}|%{"$($_.Name) has no members and is not a built-in privileged or empty group"}
        "$file.10"="$(($groupMemberCounts|?{$_.Name -in $emptyGroups -and $_.Count -gt 0}|measure).Count)/$(($emptyGroups|measure).Count) groups have members and are empty by default"
        "$file.11"=$groupMemberCounts|?{$_.Name -in $emptyGroups -and $_.Count -gt 0}|%{"$($_.Name) group has $($_.Count) members"}
        "$file.12"="$(($groupMemberCounts|?{$_.Name -in $exchangeGroups -and $_.Count -gt 0}|measure).Count)/$(($exchangeGroups|measure).Count) Exchange groups have members"
        "$file.13"=$groupMemberCounts|?{$_.Name -in $exchangeGroups -and $_.Count -gt 0}|%{"$($_.Name) group has $($_.Count) members"}
        "$file.14"="$(($groupMemberCounts|?{$_.Name -eq 'Protected Users'}|measure).Count) members are in the Protected Users groups"
        "$file.15"="$(($groupMemberCounts|?{$_.Name -in $privilegedGroups -and $_.Count -gt 0}|measure).Count)/$(($privilegedGroups|measure).Count) privileged groups have members"
        "$file.16"=$groupMemberCounts|?{$_.Name -in $privilegedGroups -and $_.Count -gt 0}|%{"$($_.Name) group has $($_.Count) members"}
        "$file.17"="$(($dormantPrivilege|group Group|measure).Count)/$(($privilegedGroups|measure).Count) privileged groups have $(($dormantPrivilege|measure).Count) dormant members"
        "$file.18"=$dormantPrivilege|%{"$($_.UserName) is dormant in the $($_.Group) group"}
    }

    return $controls
}
#endregion

#region Domain State Scriptblocks
$DomainStateDfsrmig = {
    param($path,$domain,$file)
    $dfsrmig=Get-Content "$path\$domain\$file"

    $controls=@{
        "$file.01"="$($dfsrmig|select -First 1)"
    }

    return $controls
}

# Default Query Policy in Server 2019: MaxValRange=1500 MaxReceiveBuffer=10485760 MaxDatagramRecv=4096 MaxPoolThreads=4 MaxResultSetSize=262144 MaxTempTableSize=10000 MaxQueryDuration=120 MaxPageSize=1000 MaxNotificationPerConn=5 MaxActiveQueries=20 MaxConnIdleTime=900 InitRecvTimeout=120 MaxConnections=5000
$DomainStateAdConfiguration = {
    param($path,$domain,$file)
    $adConfiguration=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adConfiguration|?{$_.DistinguishedName -like "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}).tombstoneLifetime) days is current Tombstone Lifetime (60 or 180 days is default)"
        "$file.02"="$(($adConfiguration|?{$_.DistinguishedName -like "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*" -and $_.dSHeuristics -ne $null}|measure).Count) dSHeuristics are in use"
        "$file.03"="SPN Mappings: $(($adConfiguration|?{$_.DistinguishedName -like "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}).sPNMappings)"
        "$file.04"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}|measure).Count) Optional Features are available"
        "$file.05"="$((($adConfiguration|?{$_.DistinguishedName -eq "CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}).'msDS-EnabledFeatureBL'|measure).Count) paths have Recycle Bin Feature enabled"
        "$file.06"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Query-Policies,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}|measure).Count) LDAP Query Policies are set"
        "$file.07"="Default Query Policy: $(($adConfiguration|?{$_.DistinguishedName -like "CN=Default Query Policy,CN=Query-Policies,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=*"}).lDAPAdminLimits)"
        "$file.08"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=AuthN Policy Configuration,CN=Services,CN=Configuration,DC=*"}|measure).Count) Authentication Policy Configuration containers exist (2 identifies policies are not in use)"
        "$file.09"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Microsoft SPP,CN=Services,CN=Configuration,DC=*"}|measure).Count) Active Directory based activation objects (1 identifies activation is not in use)"
        "$file.10"="$((($adConfiguration|?{$_.DistinguishedName -like "*,CN=WellKnown Security Principals,CN=Configuration,DC=*"})|select Name -ExpandProperty ObjectSID|select Name,Value|measure).Count) WellKnown Security Principals exist (27 is default)"
        "$file.11"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=NetServices,CN=Services,CN=Configuration,DC=*" -and $_.DistinguishedName -notlike "CN=DhcpRoot,*"}|select -ExpandProperty dhcpServers|measure).Count) DHCP Servers are registered with Active Directory"
        "$file.12"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|measure).Count) Certificate Authorities are available for enterprise enrollment"
        "$file.13"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|measure).Count) Certificate Templates exist in the directory"
        "$file.14"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|select -ExpandProperty certificateTemplates -Unique|measure).Count) Certificate Templates are available for enterprise enrollment"
        "$file.15"=$adConfiguration|?{$_.DistinguishedName -like "*,CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|select -ExpandProperty caCertificate|%{[System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]($_).Split(" "))|select Subject,NotAfter|%{"Enrollment CA, $($_.Subject) valid until $($_.NotAfter)"}}
        "$file.16"="$domain,$file,get-adconfiguration.json.16,$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Certification Authorities,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|measure).Count) Trusted Root Certificate Authorities are configured"
        "$file.17"=$adConfiguration|?{$_.DistinguishedName -like "*,CN=Certification Authorities,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|select -ExpandProperty caCertificate|%{[System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]($_).Split(" "))|select Subject,NotAfter|%{"Root CA, $($_.Subject) valid until $($_.NotAfter)"}}
        "$file.18"="$domain,$file,get-adconfiguration.json.18,$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=AIA,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|measure).Count) Intermediate Certificate Authorities are configured"
        "$file.19"=$adConfiguration|?{$_.DistinguishedName -like "*,CN=AIA,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|select -ExpandProperty caCertificate|%{[System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]($_).Split(" "))|select Subject,NotAfter|%{"Intermediate CA, $($_.Subject) valid until $($_.NotAfter)"}}
        "$file.20"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=CDP,CN=Public Key Services,CN=Services,CN=Configuration,DC=*" -and $_.ObjectClass -eq "cRLDistributionPoint"}|measure).Count) Certificate Revocation List (CRL) Distribution Points (CDP) exist"
        "$file.21"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=NTAuthCertificates,CN=Public Key Services,CN=Services,CN=Configuration,DC=*"}|measure).Count) Certificate Authorities are eligible to issue smart card logon or perform client private key archival"
        "$file.22"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services,CN=Configuration,DC=*"}|measure).Count) Key Distribution Service (KDS) Root Keys for group Managed Service Accounts (gMSA) are available"
        "$file.23"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=SMTP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=*"}|measure).Count) SMTP Site Links available"
        "$file.24"="$(($adConfiguration|?{$_.DistinguishedName -like "*,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=*"}|measure).Count) IP Site Links available"
    }

    return $controls
}

$DomainStateAdDfsrSubscribers = {
    param($path,$domain,$file)
    $addfsrsubscribers=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($addfsrsubscribers|?{$_.Name -eq "SYSVOL Subscription"}|measure).Count) Domain Controllers are part of the SYSVOL Distributed File System Replication (DFS-R) subscription"
    }

    return $controls
}

$DomainStateAdDomain = {
    param($path,$domain,$file)
    $addomain=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($addomain.AllowedDNSSuffixes|measure).Count) Domain Name System (DNS) Suffixes allowed"
    }

    return $controls
}

#TODO - Domain Controllers are in appropriate site/subnet for IPv4 Address and Site
$DomainStateAdDomainController = {
    param($path,$domain,$file)
    $addomain=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adDomainControllers|?{$_.LdapPort -ne "389"}|measure).Count)/$(($adDomainControllers|measure).Count) domain controllers have a non-standard LDAP port"
        "$file.02"="$(($adDomainControllers|?{$_.SslPort -ne "636"}|measure).Count)/$(($adDomainControllers|measure).Count) domain controllers have a non-standard LDAPS port"
        "$file.03"="$(($adDomainControllers|?{$_.IsReadOnly -eq "True"}|measure).Count)/$(($adDomainControllers|measure).Count) domain controllers are read only"
        "$file.04"="$(($adDomainControllers|?{$_.IsGlobalCatalog -ne "False"}|measure).Count)/$(($adDomainControllers|measure).Count) domain controllers are not Global Catalogs"
    }

    return $controls
}

$DomainStateAdForest = {
    param($path,$domain,$file)
    $adforest=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adForest.UPNSuffixes|measure).Count) UPN Suffixes are configured"
        "$file.02"=$adForest.UPNSuffixes|%{"$_ UPN Suffix is available"}
        "$file.03"="$(($adForest.SPNSuffixes|measure).Count) SPN Suffixes are configured"
        "$file.04"="$(($adForest.CrossForestReferences|measure).Count) CrossForestReferences are configured"
    }

    return $controls
}

#TODO msds-keyversionnumber
$DomainStateAdKrbTgt = {
    param($path,$domain,$file)
    $adKrbTgt=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$([datetime]::FromFileTime($adKrbTgt.pwdLastSet)) KRBTGT password last set"
        "$file.02"="$([datetime]$adKrbTgt.lastLogon) KRBTGT last logon time"
        "$file.03"="$(($adKrbTgt|?{$_.userAccountControl -ne "514"}|measure).Count) KRBTGT account in a non-standard UAC state"
    }

    return $controls
}

$DomainStateAdOptionalFeature = {
    param($path,$domain,$file)
    $adOptionalFeature=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adOptionalFeature|measure).Count) Optional Features available"
        "$file.02"=$adOptionalFeature|select cn,enabledScopes|?{$_.EnabledScopes -gt 0}|%{$feature=$_.cn;$_|select -ExpandProperty EnabledScopes|%{"$feature enabled for $_"}}
    }

    return $controls
}

$DomainStateAdReplicationConnection = {
    param($path,$domain,$file)
    $adReplicationConnection=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adReplicationConnection|?{$_.enabledConnection -ne "True"}|measure).Count) Replication Connections are disabled"
        "$file.02"="$(($adReplicationConnection|?{$_.AutoGenerated -ne "True"}|measure).Count) Replication Connections are not automatically generated"
    }

    return $controls
}

$DomainStateAdRootDse = {
    param($path,$domain,$file)
    $AdRootDse=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adRootDse.SupportedSASLMechanisms|measure).Count) SASL providers are supported (4 is default)"
        "$file.02"=$adRootDse.SupportedSASLMechanisms|%{"SASL provider $_ is available"}
        "$file.03"="$($adRootDse.Synchronized) Root DSE is synchronized"
    }

    return $controls
}

$DomainStateAdServiceAccount = {
    param($path,$domain,$file)
    $adServiceAccount=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adServiceAccount|measure).Count) managed service accounts exist"
    }

    return $controls
}

$DomainStateAdComputer = {
    param($path,$domain,$file)
    $adComputer=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable
    $enabledAdComputers=$adComputer|?{$_.Enabled -eq "True"}

    $controls=@{
        "$file.01"="$(($enabledAdComputers|?{$_.TrustedForDelegation -eq "True"}|measure).Count)/$(($enabledAdComputers|measure).Count) enabled computer objects allow unconstrained delegation"
        "$file.02"="$(($enabledAdComputers|?{$_.TrustedForDelegation -eq "True" -and $_.primaryGroupId -notin @(516,521)}|measure).Count)/$(($enabledAdComputers|?{$_.primaryGroupId -notin @(516,521)}|measure).Count) enabled, non-domain controler, computer objects allow unconstrained delegation"
        "$file.03"="$(($enabledAdComputers|?{$_.TrustedToAuthForDelegation -eq "True" -and $_.primaryGroupId -notin @(516,521)}|measure).Count)/$(($enabledAdComputers|?{$_.primaryGroupId -notin @(516,521)}|measure).Count) enabled, non-domain controler, computer objects allow constrained delegation"
        "$file.04"="$(($enabledAdComputers|group OperatingSystem|measure).Count) distinct Operating System Environments identified"
        "$file.05"=$enabledAdComputers|group OperatingSystem|sort Count -Descending|%{"$($_.Count)/$(($enabledAdComputers|measure).Count) enabled Computer Objects report an Operating System of $($_.Name)"}
        "$file.06"="$(($enabledAdComputers|?{$_.LastLogonDate -lt (Get-Date).AddDays(-180)}|measure).Count)/$(($enabledAdComputers|measure).Count) enabled computer objects have not logged on in the last 180 days and would not be tombstones (assumes default of 180 days)"
        "$file.07"="$(($enabledAdComputers|?{$_.DNSHostName -ne ''}|select @{n="Zone";e={($_.DNSHostName).substring(($_.DNSHostName).indexOf(".")+1,($_.DNSHostName).length-($_.DNSHostName).indexOf(".")-1)}}|measure).Count)/$(($enabledAdComputers|measure).Count) enabled computer objects have a DNS Host name registered with AD DS"
        "$file.08"="$(($enabledAdComputers|?{$_.DNSHostName -ne ''}|select @{n="Zone";e={($_.DNSHostName).substring(($_.DNSHostName).indexOf(".")+1,($_.DNSHostName).length-($_.DNSHostName).indexOf(".")-1)}}|group Zone|measure).Count) DNS Zones are in use by enabled computer objects"
        "$file.09"=$enabledAdComputers|?{$_.DNSHostName -ne ''}|select @{n="Zone";e={($_.DNSHostName).substring(($_.DNSHostName).indexOf(".")+1,($_.DNSHostName).length-($_.DNSHostName).indexOf(".")-1)}}|group Zone|%{"$($_.Count)/$(($enabledAdComputers|measure).Count) enabled computer objects reside in the DNS Zone $($_.Name)"}
    }

    return $controls
}
#endregion

#region GPO State Scriptblocks
# TODO - #$siteLinks=gc "$path\get-sitelinks.json"|ConvertFrom-Json -AsHashtable
# TODO - #$sitecontainers=gc "$path\get-sitecontainers.json"|ConvertFrom-Json -AsHashtable
# TODO - #$sysvolgpoguids=gc "$path\get-sysvolgpoguids.json"|ConvertFrom-Json -AsHashtable
$GpoStateGpo = {
    param($path,$domain,$file)
    $adGpos=Get-Content "$path\$domain\$file"|ConvertFrom-Json -AsHashtable

    $controls=@{
        "$file.01"="$(($adGpos|measure).Count) GPOs exist in the domain"
        "$file.02"="$(($adgpos|?{$_.WmiFiler -ne $null}|measure).Count) GPOs have WMI Filters set"
        "$file.03"=$adgpos|?{$_.WmiFiler -ne $null}|%{"$($_.DisplayName) has WMI Filter set"}
        "$file.04"="$(($adGpos|?{$_.GpoStatus -ne "3"}|measure).Count) GPOs have settings disabled"
        "$file.05"=$adGpos|?{$_.GpoStatus -eq "2"}|%{"$($_.DisplayName) has Computer Settings Disabled"}
        "$file.06"=$adGpos|?{$_.GpoStatus -eq "1"}|%{"$($_.DisplayName) has User Settings Disabled"}
        "$file.07"=$adGpos|?{$_.GpoStatus -eq "0"}|%{"$($_.DisplayName) has All Settings Disabled"}
        "$file.08"="$(($adGpos|group Owner|measure).Count) distinct owners exist for $(($adGpos|measure).Count) GPOs"
        "$file.09"=$adGpos|group Owner|%{"$($_.Name) is the owner of $($_.Count)/$(($adGpos|measure).Count) GPOs"}
    }

    return $controls
}

#Encrypted GPO credentials are AES-256 bit encrypted but Microsoft has published the AES encryption key on MSDN which can be used to decrypt the password.
#$objs|?{$_.TrusteeNames -notcontains "NT Authority\Authenticated Users"}|%{"$domain,$file,gporeports.06,$($_.Name) does not include Enterprise Domain Controllers as a trustee"}
#$objs|?{($_.TrusteeNames -like "*\Domain Computers").Count -eq 0}|%{"$domain,$file,gporeports.08,$($_.Name) does not include Domain Computers as a trustee"}
#$objs|?{$_.TrusteeInheritence -contains $true}|%{"$domain,$file,gporeports.12,$($_.Name) has direct access control entries"}
#$objs|?{$_.Enforcement -ne $null}|%{"$domain,$file,gporeports.18,$($_.Name) will $($_.Enforcement)"}
<#
TODO - Add controls for ADMX Central Store
 - Confirm SYSVOL\domain.tld\Policies\PolicyDefinitions exists
 - Summarize ADMXs in central store
 - Summarize ADMXs that are not Microsoft native
#>
$GpoStateGpoReports = {
    param($path,$domain,$file)
    $objs=@()
    gci "$path\$domain\$file\*.xml" -Recurse|%{
        [xml]$doc=gc $_.FullName
        [string]$string=gc $_.FullName
        $obj = New-Object PSCustomObject
        $obj|Add-Member -MemberType NoteProperty -Name Name -Value $doc.GPO.Name
        $obj|Add-Member -MemberType NoteProperty -Name Owner -Value $doc.GPO.SecurityDescriptor.Owner.Name."#text"
        $obj|Add-Member -MemberType NoteProperty -Name PermissionsPresent -Value ($doc.GPO.SecurityDescriptor.PermissionsPresent."#text" -eq $true)
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeNames -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.Trustee.Name."#text"})
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeTypes -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.Type.PermissionType -eq "Allow"})
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeInheritence -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.Inherited -eq $false})
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeSelf -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.Applicability.ToSelf -eq $true})
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeStandard -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.Standard})
        $obj|Add-Member -MemberType NoteProperty -Name TrusteeAccessMask -Value ($doc.GPO.SecurityDescriptor.Permissions.TrusteePermissions|%{$_.AccessMask -eq "0"})
        $obj|Add-Member -MemberType NoteProperty -Name DisabledLinks -Value ($doc.GPO.LinksTo|%{if (-not $_.Enabled){"Disabled "+$_.SOMPath}})
        $obj|Add-Member -MemberType NoteProperty -Name Enforcement -Value ($doc.GPO.LinksTo|%{if ($_.NoOverride){"Enforce "+$_.SOMPath}})
        $obj|Add-Member -MemberType NoteProperty -Name ComputerEnabled -Value ($doc.GPO.Computer.Enabled -eq $true)
        $obj|Add-Member -MemberType NoteProperty -Name UserEnabled -Value ($doc.GPO.User.Enabled -eq $true)
        $obj|Add-Member -MemberType NoteProperty -Name CompDirVer -Value $doc.GPO.Computer.VersionDirectory
        $obj|Add-Member -MemberType NoteProperty -Name CompSysVer -Value $doc.GPO.Computer.VersionSysvol
        $obj|Add-Member -MemberType NoteProperty -Name UserDirVer -Value $doc.GPO.User.VersionDirectory
        $obj|Add-Member -MemberType NoteProperty -Name UserSysVer -Value $doc.GPO.User.VersionSysvol
        $obj|Add-Member -MemberType NoteProperty -Name ComputerSettings -Value ($doc.GPO.Computer.ExtensionData -ne $null)
        $obj|Add-Member -MemberType NoteProperty -Name UserSettings -Value ($doc.GPO.User.ExtensionData -ne $null)
        $obj|Add-Member -MemberType NoteProperty -Name CountCompSettings -Value (($doc.GPO.Computer.ExtensionData|measure).Count)
        $obj|Add-Member -MemberType NoteProperty -Name CountUserSettings -Value (($doc.GPO.User.ExtensionData|measure).Count)
        $obj|Add-Member -MemberType NoteProperty -Name CpasswordFound -value ([bool]($string|?{$_ -like "*Cpassword*"}))
        $obj|Add-Member -MemberType NoteProperty -Name DefaultPasswordFound -value ([bool]($string|?{$_ -like "*DefaultPassword*"}))
        $objs+=$obj
    }

    $controls=@{
        "$file.01"="$(($objs|?{$_.PermissionsPresent -eq $false}|measure).Count)/$(($objs|measure).Count) GPOs do not have permissions set"
        "$file.02"=$objs|?{$_.PermissionsPresent -eq $false}|%{"$($_.Name) does not have permissions set"}
        "$file.03"="$(($objs|?{$_.TrusteeNames -notcontains "NT Authority\Authenticated Users"}|measure).Count)/$(($objs|measure).Count) GPOs do not have Authenticated Users in trustees"
        "$file.04"=$objs|?{$_.TrusteeNames -notcontains "NT Authority\Authenticated Users"}|%{"$($_.Name) does not include Authenticated Users as a trustee"}
        "$file.05"="$(($objs|?{$_.TrusteeNames -notcontains "NT Authority\ENTERPRISE DOMAIN CONTROLLERS"}|measure).Count)/$(($objs|measure).Count) GPOs do not have Enterprise Domain Controllers in trustees"
        "$file.07"="$(($objs|?{($_.TrusteeNames -like "*\Domain Computers").Count -eq 0}|measure).Count)/$(($objs|measure).Count) GPOs do not have Domain Computers in trustees"
        "$file.09"="$(($objs|?{$_.TrusteeTypes -contains $false}|measure).Count)/$(($objs|measure).Count) GPOs have a deny access control entry set"
        "$file.10"=$objs|?{$_.TrusteeTypes -contains $false}|%{"$($_.Name) has a deny entry set"}
        "$file.11"="$(($objs|?{$_.TrusteeInheritence -contains $true}|measure).Count)/$(($objs|measure).Count) GPOs use inherited permissions"
        "$file.13"="$(($objs|?{$_.trusteeStandard.GPOGroupedAccessEnum -notcontains "Apply Group Policy"}|measure).Count)/$(($objs|measure).Count) GPOs do not include an access control entry for Apply Group Policy"
        "$file.14"=$objs|?{$_.trusteeStandard.GPOGroupedAccessEnum -notcontains "Apply Group Policy"}|%{"$($_.Name) does not include an access control entry for Apply Group Policy"}
        "$file.15"="$(($objs|?{$_.DisabledLinks -ne $null}|measure).Count)/$(($objs|measure).Count) GPOs have a disabled link"
        "$file.16"=$objs|?{$_.DisabledLinks -ne $null}|%{"$($_.Name) has a disabled link"}
        "$file.17"="$(($objs|?{$_.Enforcement -ne $null}|measure).Count)/$(($objs|measure).Count) GPOs have enforcement set"
        "$file.19"="$(($objs|?{(($_.ComputerEnabled -band ($_.CountCompSettings -gt 0))+($_.UserEnabled -band ($_.CountUserSettings -gt 0))) -eq 0}|measure).Count)/$(($objs|measure).Count) GPOs have settings enabled but no respective settings defined"
        "$file.20"=$objs|?{(($_.ComputerEnabled -band ($_.CountCompSettings -gt 0))+($_.UserEnabled -band ($_.CountUserSettings -gt 0))) -eq 0}|%{"$($_.Name) has 0 settings defined"}
        "$file.21"="$(($objs|?{$_.CompDirVer -ne $_.CompSysVer -or $_.UserDirVer -ne $_.UserSysVer}|measure).Count)/$(($objs|measure).Count) GPOs have mismatching directory and Sysvol versions"
        "$file.22"=$objs|?{$_.CompDirVer -ne $_.CompSysVer -or $_.UserDirVer -ne $_.UserSysVer}|%{"$($_.Name) has a mismatch for Computer ($($_.CompDirVer):$($_.CompSysVer)) or User ($($_.UserDirVer):$($_.UserSysVer)) versions between directory and Sysvol"}
        "$file.23"="$(($objs|?{$_.CpasswordFound -eq $true}|measure).Count) GPOs were found to contain a Cpassword entry"
        "$file.24"=$objs|?{$_.CpasswordFound -eq $true}|%{"$($_.Name) contains a Cpassword entry"}
        "$file.25"="$(($objs|?{$_.DefaultPasswordFound -eq $true}|measure).Count) GPOs were found to contain a DefaultPassword entry"
        "$file.26"=$objs|?{$_.DefaultPasswordFound -eq $true}|%{"$($_.Name) contains a DefaultPassword entry"}
    }

    return $controls
}
#endregion

#region AD DACLs Scriptblocks
$AdDaclsAdDacls = {
    param($path,$domain,$file)
    $dacls=Import-Csv "$path\$domain\$file"

    #1/2022 - https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryrights?view=dotnet-plat-ext-6.0
    $privilegedAcls=@(
        "AccessSystemSecurity",
        "CreateChild",
        "Delete",
        "DeleteChild",
        "DeleteTree",
        "GenericAll",
        "GenericWrite",
        "WriteDacl",
        "WriteOwner",
        "WriteProperty",
        "Self"
    )

    #1/2022 - https://docs.microsoft.com/en-us/windows/win32/adschema/extended-rights
    $privilegedExtensions=@(
        "Add GUID",
        "Change Domain Master",
        "Change Infrastructure Master",
        "Change PDC",
        "Change Rid Master",
        "Change Schema Master",
        "Create Inbound Forest Trust",
        "DS-Clone-Domain-Controller",
        "DS-Execute-Intentions-Script",
        "DS-Install-Replica",
        "DS-Replication-Get-Changes",
        "DS-Replication-Get-Changes-All",
        "DS-Replication-Get-Changes-In-Filtered-Set",
        "DS-Replication-Manage-Topology",
        "Enable Per User Reversibly Encrypted Password",
        "Manage-Optional-Features",
        "Migrate SID History",
        "msmq-Open-Connector",
        "msmq-Peek",
        "msmq-Peek-computer-Journal",
        "msmq-Peek-Dead-Letter",
        "msmq-Receive",
        "msmq-Receive-computer-Journal",
        "msmq-Receive-Dead-Letter",
        "msmq-Receive-journal",
        "msmq-Send",
        "Read Only Replication Secret Synchronization",
        "Reanimate Tombstones",
        "Recalculate Security Inheritance",
        "Receive As",
        "Run Protect Admin Groups Task",
        "Enumerate Entire SAM Domain",
        "Send As",
        "Unexpire Password",
        "Update Password Not Required Bit",
        "Change Password",
        "Reset Password"
    )

    #1/2022
    $objectClasses=@"
Object Class,GUID
Organizational Units,bf967aa5-0de6-11d0-a285-00aa003049e2
Computer,bf967a86-0de6-11d0-a285-00aa003049e2
User,bf967aba-0de6-11d0-a285-00aa003049e2
Groups,bf967a9c-0de6-11d0-a285-00aa003049e2
Contacts,5cb41ed0-0e4c-11d0-a286-00aa003049e2
department,bf96794f-0de6-11d0-a285-00aa003049e2
description,bf967950-0de6-11d0-a285-00aa003049e2
displayName,bf967953-0de6-11d0-a285-00aa003049e2
givenName,f0f8ff8e-1191-11d0-a060-00aa006c33ed
mail,bf967961-0de6-11d0-a285-00aa003049e2
member,bf9679c0-0de6-11d0-a285-00aa003049e2
physicalDeliveryOfficeName,bf9679f7-0de6-11d0-a285-00aa003049e2
proxyAddresses,bf967a06-0de6-11d0-a285-00aa003049e2
sn,bf967a41-0de6-11d0-a285-00aa003049e2
telephoneNumber,bf967a49-0de6-11d0-a285-00aa003049e2
General Information,59ba2f42-79a2-11d0-9020-00c04fc2d3cf
Personal Information,77b5b886-944a-11d1-aebd-0000f80367c1
Private Information,91e647de-d96f-4b70-9557-d63ff4f3ccd8
Public Information,e48d0154-bcf8-11d1-8702-00c04fb96050
Administer Exchange information store,d74a8762-22b9-11d3-aa62-00c04f8eedd8
Create Inbound Forest Trust,e2a36dc9-ae17-47c3-b58b-be34c55ba633
Change Password,ab721a53-1e2f-11d0-9819-00aa0040529b
Migrate SID History,ba33815a-4f93-4c76-87f3-57574bff8109
Reanimate Tombstones,45ec5156-db7e-47bb-b53f-dbeb2d03c40f
Receive As,ab721a56-1e2f-11d0-9819-00aa0040529b
Replication Synchronization,1131f6ab-9c07-11d1-f79f-00c04fc2dcd2
Reset Password,00299570-246d-11d0-a768-00aa006e0529
Send As,ab721a54-1e2f-11d0-9819-00aa0040529b
Unexpire Password,ccc2dc7d-a6ad-4a7a-8846-c04e3cc53501
View Exchange information store status,d74a875e-22b9-11d3-aa62-00c04f8eedd8
All,00000000-0000-0000-0000-000000000000
ms-Exch-Public-Delegates,f0f8ff9a-1191-11d0-a060-00aa006c33ed
Garbage-Coll-Period,5fd424a1-1262-11d0-a060-00aa006c33ed
ms-DS-Key-Credential-Link,5b47d60f-6090-40b2-9f37-2a4de88f3063
Display-Name-Printable,bf967954-0de6-11d0-a285-00aa003049e2
Admin-Display-Name,bf96791a-0de6-11d0-a285-00aa003049e2
Legacy-Exchange-DN,28630ebc-41d5-11d1-a9c1-0000f80367c1
ms-Exch-Active-Sync-Devices,c975c901-6cea-4b6f-8319-d67f45449506
ms-Exch-Active-Sync-Device,e8b2aff2-59a7-4eac-9a70-819adef701dd
public-folder,f0f8ffac-1191-11d0-a060-00aa006c33ed
Text-Encoded-OR-Address,a8df7489-c5ea-11d1-bbcb-0080c76670c0
Show-In-Address-Book,3e74f60e-3e73-11d1-a9c0-0000f80367c1
ms-Exch-Dynamic-Distribution-List,018849b0-a981-11d2-a9ff-00c04f8eedd8
Is-Member-Of-DL,bf967991-0de6-11d0-a285-00aa003049e2
User-Account-Control,bf967a68-0de6-11d0-a285-00aa003049e2
SAM-Account-Name,3e0abfd0-126a-11d0-a060-00aa006c33ed
inetOrgPerson,4828cc14-1437-45bc-9b07-ad6f015e5f28
Group-Type,9a9a021e-4a5b-11d1-a9c3-0000f80367c1
Service-Principal-Name,f3a64788-5306-11d1-a9c5-0000f80367c1
X509-Cert,bf967a7f-0de6-11d0-a285-00aa003049e2
ms-Exch-Mailbox-Security-Descriptor,934de926-b09e-11d2-aa06-00c04f8eedd8
WWW-Home-Page,bf967a7a-0de6-11d0-a285-00aa003049e2
Pwd-Last-Set,bf967a0a-0de6-11d0-a285-00aa003049e2
Canonical-Name,9a7ad945-ca53-11d1-bbd0-0080c76670c0
ms-Exch-Mobile-Mailbox-Flags,5430e777-c3ea-4024-902e-dde192204669
ms-Exch-UM-Spoken-Name,2cc06e9d-6f7e-426a-8825-0215de176e11
Country-Code,5fd42471-1262-11d0-a060-00aa006c33ed
ms-Exch-UM-Server-Writable-Flags,5e353847-f36c-48be-a7f7-49685402503c
ms-Exch-Safe-Senders-Hash,7cb4c7d3-8787-42b0-b438-3c5d479ad31e
ms-Exch-UM-Pin-Checksum,3263e3b8-fd6b-4c60-87f2-34bdaa9d69eb
Picture,8d3bca50-1d7e-11d0-a081-00aa006c33ed
ms-Exch-UM-Dtmf-Map,614aea82-abc6-4dd0-a148-d67a59c72816
Managed-By,0296c120-40da-11d1-a9c0-0000f80367c1
ms-Exch-User-Culture,275b2f54-982d-4dcd-b0ad-e53501445efb
ms-Exch-Blocked-Senders-Hash,66437984-c3c5-498f-b269-987819ef484b
ms-Exch-Safe-Recipients-Hash,6f606079-3a82-4c1b-8efb-dcc8c91d26fe
DNS-Host-Name,72e39547-7b18-11d1-adef-00c04fd8d5cd
citrix-SSOSecret,e08244c8-5001-467f-8253-74aee260ed7d
Lockout-Time,28630ebf-41d5-11d1-a9c1-0000f80367c1
Script-Path,bf9679a8-0de6-11d0-a285-00aa003049e2
User-Principal-Name,28630ebb-41d5-11d1-a9c1-0000f80367c1
ms-DS-Allowed-To-Act-On-Behalf-Of-Other-Identity,3f78c3e5-f79a-46bd-a0b8-9d18116ddc79
citrix-SSOConfig,df33358a-eade-4190-8931-714f8fba1598
Account-Expires,bf967915-0de6-11d0-a285-00aa003049e2
ms-TPM-Tpm-Information-For-Computer,ea1b7b93-5e48-46d5-bc6c-4df4fda78a35
ms-net-ieee-80211-GroupPolicy,1cb81863-b822-4379-9ea2-5ff7bdc6386d
ms-net-ieee-8023-GroupPolicy,99a03a6a-ab19-4446-9350-0cb878ed2d9b
MemberUid,03dab236-672e-4f61-ab64-f77d2dc2ffab
Token-Groups-Global-And-Universal,46a9b11d-60ae-405a-b7e8-ff8a58d456d2
ms-Mcs-AdmPwdExpirationTime,1a8498ba-9f20-4595-8ccf-94173e36e8ee
ms-Mcs-AdmPwd,5cc8fdca-e1bc-4278-9c41-1be421246070
Print-Queue,bf967aa8-0de6-11d0-a285-00aa003049e2
Terminal-Server,6db69a1c-9422-11d1-aebd-0000f80367c1
ms-Exch-External-Sync-State;ms-Exch-ELC-Mailbox-Flags;ms-Exch-Shadow-When-Soft-Deleted-Time;ms-Exch-UM-Addresses;ms-Exch-Disabled-Archive-GUID;ms-Exch-Disabled-Archive-Database-Link;ms-Exch-Supervision-User-Link;ms-Exch-Supervision-DL-Link;ms-Exch-Supervision-One-Off-Link;ms-Exch-UM-Calling-Line-IDs;ms-Exch-Aggregation-Subscription-Credential;ms-Exch-Send-As-Addresses;ms-Exch-Archive-GUID;ms-Exch-Server-Association-BL;ms-Exch-Server-Association-Link;ms-Exch-Sharing-Policy-Link;ms-Exch-Transport-Recipient-Settings-Flags;ms-Exch-UM-Phone-Provider;ms-Exch-Sharing-Anonymous-Identities;ms-Exch-Archive-Name;ms-Exch-Archive-Quota;ms-Exch-Archive-Warn-Quota;ms-Exch-OWA-Remote-Documents-Internal-Domain-Suffix-List-BL;ms-Exch-Parent-Plan-BL;ms-Exch-Supervision-DL-BL;ms-Exch-Supervision-One-Off-BL;ms-Exch-Archive-Database-Link;ms-Exch-Archive-Database-BL;ms-Exch-Device-Access-State;ms-Exch-Device-Access-State-Reason;ms-Exch-Device-EAS-Version;ms-Exch-Blocked-Senders-Hash;ms-Exch-Device-Friendly-Name;ms-Exch-Device-Health;ms-Exch-Device-ID;ms-Exch-Device-IMEI;ms-Exch-Device-Mobile-Operator;ms-Exch-Device-OS;ms-Exch-Device-OS-Language;ms-Exch-Device-Telephone-Number;ms-Exch-Device-Type;ms-Exch-Device-User-Agent;ms-Exch-Mobile-Blocked-Device-IDs;ms-Exch-Message-Hygiene-Flags;ms-Exch-Message-Hygiene-SCL-Delete-Threshold;ms-Exch-Message-Hygiene-SCL-Quarantine-Threshold;ms-Exch-Message-Hygiene-SCL-Reject-Threshold;ms-Exch-First-Sync-Time;ms-Exch-UM-Pin-Checksum;ms-Exch-Retention-Comment;ms-Exch-Retention-URL;ms-Exch-Last-Update-Time;ms-Exch-Alternate-Mailboxes;ms-Exch-Delegate-List-Link;ms-Exch-Delegate-List-BL;ms-Exch-Device-Access-Control-Rule-Link;ms-Exch-Device-Access-Control-Rule-BL;ms-Exch-Signup-Addresses;ms-Exch-User-Display-Name;ms-Exch-Litigation-Hold-Date;ms-Exch-Litigation-Hold-Owner;ms-Exch-Device-Model;ms-Exch-Safe-Recipients-Hash;ms-Exch-Safe-Senders-Hash;ms-Exch-Immutable-Id;ms-Exch-Sharing-Partner-Identities,b1b3a417-ec55-4191-b327-b72e33e38af2
ms-DS-Key-Credential-Link,9b026da6-0d3c-465c-8bee-5199d7165cba
DNS-Host-Name;ms-DS-Additional-Dns-Host-Name,72e39547-7b18-11d1-adef-00c04fd8d5cd
Account-Expires;Pwd-Last-Set;User-Account-Control;User-Parameters;ms-DS-Allowed-To-Act-On-Behalf-Of-Other-Identity;ms-DS-User-Password-Expiry-Time-Computed;ms-DS-User-Account-Control-Computed,4c164200-20c0-11d0-a768-00aa006e0529
MS-TS-ExpireDate;MS-TS-LicenseVersion;MS-TS-ManagingLS;Terminal-Server;MS-TS-ManagingLS2;MS-TS-ManagingLS3;MS-TS-ManagingLS4;MS-TS-ExpireDate2;MS-TS-ExpireDate3;MS-TS-ExpireDate4;MS-TS-LicenseVersion2;MS-TS-LicenseVersion3;MS-TS-LicenseVersion4,5805bc62-bdc9-4428-a5e2-856a0f4c185e
Bad-Pwd-Count;Script-Path;Home-Directory;Home-Drive;User-Workstations;Last-Logoff;Last-Logon;Logon-Count;Logon-Hours;Last-Logon-Timestamp;Logon-Workstation;Profile-Path,5f202010-79a5-11d0-9020-00c04fc2d4cf
WWW-Home-Page;WWW-Page-Other,e45795b3-9455-11d1-aebd-0000f80367c1
Is-Member-Of-DL;Member,bc0ac240-79a9-11d0-9020-00c04fc2d4cf
Token-Groups;Token-Groups-Global-And-Universal;Token-Groups-No-GC-Acceptable;ms-DS-Token-Group-Names;ms-DS-Token-Group-Names-Global-And-Universal;ms-DS-Token-Group-Names-No-GC-Acceptable;msNPAllowDialin;msNPCallingStationID;msRADIUSCallbackNumber;msRADIUSFramedIPAddress;msRADIUSFramedRoute;msRADIUSServiceType,037088f8-0ae1-11d2-b422-00a0c968f939
DS-Replication-Get-Changes,1131f6aa-9c07-11d1-f79f-00c04fc2dcd2
Generate-RSoP-Logging,b7b1b3de-ab09-4242-9e30-9980e5d322f7
Generate-RSoP-Planning,b7b1b3dd-ab09-4242-9e30-9980e5d322f7
Send-To,ab721a55-1e2f-11d0-9819-00aa0040529b
Phone and Mail Options,E45795B2-9455-11D1-AEBD-0000F80367C1
DS-Replication-Get-Changes-All,1131f6ad-9c07-11d1-f79f-00c04fc2dcd2
DS-Replication-Get-Changes-In-Filtered-Set,89e95b76-444d-4c62-991a-0facbeda640c
DS-Replication-Manage-Topology,1131f6ac-9c07-11d1-f79f-00c04fc2dcd2
Add GUID,440820ad-65b4-11d1-a3da-0000f875ae0d
dnsNode,e0fa1e8c-9b45-11d0-afdd-00c04fd930c9
"@
    $objectClasses=$objectClasses|ConvertFrom-Csv

    $dacls|%{$type=$_.ObjectType;$_.ObjectType=($objectClasses|?{$_.GUID -eq $type}).'Object Class'}
    $dacls|%{$type=$_.InheritedObjectType;$_.InheritedObjectType=($objectClasses|?{$_.GUID -eq $type}).'Object Class'}

    $controls=@{
        "$file.01"="$(($dacls|select @{n='object';e={$_.Object.Substring(0+10,$_.Object.IndexOf(",")-10)}}|group object|measure).Count) distinct object discretionary access control lists"
        "$file.02"="$(($dacls|?{$_.Object -like "LDAP://OU=*"}|measure).Count) access control entries apply to Organizational Unit objects"
        "$file.03"="$(($dacls|?{$_.Object -like "*\0ACNF:*"}|group object|measure).Count) conflict objects were found"
        "$file.04"=$dacls|?{$_.Object -like "*\0ACNF:*"}|group object|%{"Conflict identified with object: $($_.Name)"}
        "$file.05"="$(($dacls|?{$_.AccessControlType -eq "Deny"}|group ActiveDirectoryRights,ObjectType|measure).Count) access control authorization is set to deny"
        "$file.06"=$dacls|?{$_.AccessControlType -eq "Deny"}|group ActiveDirectoryRights,ObjectType|%{$authz=$_.Name;$_.Group|group IdentityReference|%{$identity=$_.Name;$_.Group|group Object|%{"Deny authorization for $authz by $identity on $($_.Name)"}}}
        "$file.07"="$(($dacls|group IdentityReference|measure).Count) distinct identities are referenced within ACEs"
        "$file.08"=$dacls|group IdentityReference|sort Count|%{"$($_.Count) ACEs for $($_.Name) in the sample of DACLs"}
        "$file.09"="$(($dacls|?{$_.AccessControlType -eq "Allow" -and ($_.ActiveDirectoryRights).Split(", ") -in $privilegedAcls}|group ActiveDirectoryRights|measure).Count) distinct privileged Active Directory allow authorizations are in use"
        "$file.10"=$dacls|?{$_.AccessControlType -eq "Allow" -and ($_.ActiveDirectoryRights).Split(", ") -in $privilegedAcls}|group ActiveDirectoryRights|%{"$($_.Count) allow ACEs for $($_.Name)"}
        "$file.11"="$(($dacls|?{$_.AccessControlType -eq "Allow" -and $_.ActiveDirectoryRights -eq "ExtendedRight" -and ($_.ObjectType) -in $privilegedExtensions}|group ObjectType|measure).Count) allow Extended Rights are in use"
        "$file.12"=$dacls|?{$_.AccessControlType -eq "Allow" -and $_.ActiveDirectoryRights -eq "ExtendedRight" -and ($_.ObjectType) -in $privilegedExtensions}|group ObjectType|%{"$($_.Count) allow ACEs for $($_.Name)"}
        "$file.13"=$dacls|?{$_.AccessControlType -eq "Allow" -and $_.ActiveDirectoryRights -eq "ExtendedRight" -and ($_.ObjectType) -in $privilegedExtensions}|group ObjectType|%{$type=$_.Name;$_.Group|group IdentityReference|%{"$($_.Name) is authorized for $type"}}
        "$file.14"="$(($dacls|?{$_.IsInherited -eq "False"}|measure).Count) ACEs are not inherited"
        "$file.15"="$(($dacls|?{$_.IdentityReference -like "S-1-5-21-*"}|group IdentityReference|measure).Count) distinct identites have ACEs, but is not longer resolvable"
        "$file.16"=$dacls|?{$_.IdentityReference -like "S-1-5-21-*"}|group IdentityReference|%{"$($_.Name) exists in ACEs and no longer is resolvable"}
        "$file.17"="$(($dacls|group InheritedObjectType|measure).Count) types of inherited objects are targeted by ACEs"
        "$file.18"=$dacls|group InheritedObjectType|%{"Inheritence targets $($_.Name) objects for $($_.Count) ACEs"}
    }

    return $controls
}
#endregion

#region TODO
<#
$computerInfo=gci -Recurse "$path\DomainControllers\" -Filter "get-computerinfo.json"
foreach($computer in $computerInfo)
{
    $doc=gc $computer.FullName|ConvertFrom-Json
    "$domain,$file,computerinfo.json.01,$($doc.CsCaption)-Registry install date $($doc.WindowsInstallDateFromRegistry)"
    "$domain,$file,computerinfo.json.01,$($doc.CsCaption)-OS install date $($doc.OsInstallDate)"
    "$domain,$file,computerinfo.json.02,$($doc.CsCaption)-ProductName: $($doc.WindowsProductName)"
    "$domain,$file,computerinfo.json.02,$($doc.CsCaption)-ProductName: $($doc.OsName)"
    "$domain,$file,computerinfo.json.03,$($doc.CsCaption)-EditionId: $($doc.WindowsEditionId)"
    "$domain,$file,computerinfo.json.04,$($doc.CsCaption)-InstallType: $($doc.WindowsInstallationType)"
    "$domain,$file,computerinfo.json.05,$($doc.CsCaption)-Version: $($doc.OsVersion)"
    "$domain,$file,computerinfo.json.06,$($doc.CsCaption)-Platform: $($doc.CsManufacturer)-$($doc.CsModel)"
    "$domain,$file,computerinfo.json.07,$($doc.CsCaption)-Architecture: $($doc.OsArchitecture)"
    "$domain,$file,computerinfo.json.07,$($doc.CsCaption)-Architecture: $($doc.CsSystemType)"
    "$domain,$file,computerinfo.json.08,$($doc.CsCaption)-$(($doc.CsProcessors|measure).Count) Processors with $($doc.CsNumberOfLogicalProcessors) cores"
    $doc.CsProcessors|%{"$domain,$file,computerinfo.json.09,$($doc.CsCaption)-$($_.Manufacturer) $($_.Name) ($($_.NumberOfCores) Cores)"}
    "$domain,$file,computerinfo.json.10,$($doc.CsCaption)-$([Math]::Round($doc.OsInUseVirtualMemory/1024/1024)) GB in use of $([Math]::Round($doc.OsTotalVisibleMemorySize/1024/1024)) GB available memory"
    "$domain,$file,computerinfo.json.11,$($doc.CsCaption)-The paging file at $($doc.OsPagingFiles) is enabled ($($doc.CsAutomaticManagedPagefile)) for $($doc.OsFreeSpaceInPagingFiles/1024/1024) GB free of $($doc.OsSizeStoredInPagingFiles/1024/1024) GB available"
    "$domain,$file,computerinfo.json.12,$($doc.CsCaption)-BIOS is $($doc.BiosManufacturer) $($doc.BiosName) released on $($doc.BiosReleaseDate)"
    "$domain,$file,computerinfo.json.13,$($doc.CsCaption)-Boot state is $($doc.CsBootupState)"
    "$domain,$file,computerinfo.json.14,$($doc.CsCaption)-OSE is a virtual machine ($($doc.CsHypervisorPresent)-$($doc.HyperVisorPresent))"
    "$domain,$file,computerinfo.json.15,$($doc.CsCaption)-Encrytion is set to $($doc.OsEncryptionLevel)"
    "$domain,$file,computerinfo.json.16,$($doc.CsCaption)-Device Guard is $($doc.DeviceGuardSmartStatus) [0=Off|1=Configured|2=Running]"
    #https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.deviceguardsmartstatus?view=powershellsdk-1.1.0
    "$domain,$file,computerinfo.json.17,$($doc.CsCaption)-Data Execution Prevention is available $($doc.OsDataExecutionPreventionAvailable) and policy is set to $($doc.OsDataExecutionPreventionSupportPolicy) [0=Off|1=On|2=OptIn|3=OptOut]"
    #https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.dataexecutionpreventionsupportpolicy?view=powershellsdk-1.1.0
    "$domain,$file,computerinfo.json.18,$($doc.CsCaption)-$(($doc.CsNetworkAdapters|measure).Count) network adapters identified"
    $doc.CsNetworkAdapters|%{"$domain,$file,computerinfo.json.19,$($doc.CsCaption)-$($_.ConnectionID) adapter ($($_.Description)) with IP Address $($_.IPAddresses) from DHCP ($($_.DHCPEnabled)) server $($_.DHCPServer)"}
}

$knownProcesses=@(
    "splunkd",
    "vmtoolsd",
    "CSFalconService",
    "CcmExec",
    "ntservices",
    "nessusd",
    "enstart64",
    "ad_server",
    "nimbus",
    "hpqams",
    "ccSvcHst",
    "w3wp",
    "EMET_Agent",
    "dsm_om_shrsvc64",
    "SACMonitor",
    "qlsrvc",
    "vmware-converter",
    "nsrexecd",
    "Veeam.EndPoint.Service",
    "SLAgentSvc",
    "lmagent",
    "HTVSSSrv",
    "Microsoft.HttpForwarder.WindowsService",
    "TsaoCliAgent"
)
$processes=gci -Recurse "$path\DomainControllers\" -Filter "get-process.json"
foreach($computer in $processes)
{
    $doc=gc $computer.FullName|ConvertFrom-Json
    $comp=$computer.DirectoryName.Substring($computer.DirectoryName.LastIndexOf("\")+1)
    #$doc|sort Product,ProcessName,FileVersion|ft Product,ProcessName,Path,FileVersion,Description
    #$doc|?{$_.Product -notlike "Microsoft*"}|sort Product,ProcessName,FileVersion|ft Product,ProcessName,Path,FileVersion,Description
    #https://www.splunk.com/en_us/page/previous_releases/universalforwarder#x86_64windows
    #https://packages.vmware.com/tools/versions
    #https://docs.vmware.com/en/VMware-Tools/10.3/rn/vmware-tools-1035-release-notes.html
    "$domain,$file,process.json.01,$comp-$(($doc|?{$_.ProcessName -in $knownProcesses}|measure).Count) known processes found"
    $doc|?{$_.ProcessName -in $knownProcesses}|%{"$domain,$file,process.json.02,$comp-$($_.Product) $($_.ProcessName) with file version $($_.FileVersion)"}
    "$domain,$file,process.json.03,$comp-$(($doc|?{$_.Path -ne $null}|select @{n='BasePath';e={$_.Path.Substring(0,$_.Path.IndexOf("\",5))}}|group BasePath|measure).Count) base paths contain process executables"
    $doc|?{$_.Path -ne $null}|select @{n='BasePath';e={$_.Path.Substring(0,$_.Path.IndexOf("\",5))}}|group BasePath|%{"$domain,$file,process.json.04,$comp-Base Path: $($_.Name)"}
}

$knownDcPorts=@(
    "53",
    "88",
    "464",
    "123",
    "135",
    "389",
    "636",
    "3268",
    "3269",
    "139",
    "445",
    "3389",
    "5985"
)
$connections=gci -Recurse "$path\DomainControllers\" -Filter "get-nettcpconnection.json"
foreach($computer in $connections)
{
    $doc=gc $computer.FullName|ConvertFrom-Json
    $comp=($doc|select -First 1|select -ExpandProperty CimSystemProperties).ServerName
    #https://docs.microsoft.com/en-us/previous-versions/windows/desktop/nettcpipprov/msft-nettcpconnection#:~:text=The%20state%20of%20the%20TCP%20connection
    #Non-dynamic listening ports - https://docs.microsoft.com/en-us/troubleshoot/windows-server/networking/default-dynamic-port-range-tcpip-chang
    "$domain,$file,nettcpconnection.json.01,$comp-$(($doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(1024..65535)}|group LocalPort|measure).Count) non-dynamic listening ports identified"
    #$doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(1024..65535)}|group LocalPort|%{"$domain,$file,nettcpconnection.json.02,$comp-TCP Port $($_.Name) listening"}
    "$domain,$file,nettcpconnection.json.03,$comp-$(($doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(49152..65535)}|group LocalPort|measure).Count) non-dynamic (2012+) listening ports identified"
    #$doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(49152..65535)}|group LocalPort|%{"$domain,$file,nettcpconnection.json.04,$comp-TCP Port $($_.Name) listening"}
    "$domain,$file,nettcpconnection.json.05,$comp-$(($doc|?{$_.State -eq 5 -and $_.LocalAddress -notin @("127.0.0.1","::1") -and $_.LocalPort -in @(1024..65535) -and $_.RemotePort -notin @(1024..65535) -and $_.RemoteAddress -ne $_.LocalAddress}|group RemoteAddress|measure).Count) remote addresses with established outbound connections"
    #$doc|?{$_.State -eq 5 -and $_.LocalAddress -notin @("127.0.0.1","::1") -and $_.LocalPort -in @(1024..65535) -and $_.RemotePort -notin @(1024..65535) -and $_.RemoteAddress -ne $_.LocalAddress}|group RemoteAddress,RemotePort|%{"$domain,$file,nettcpconnection.json.06,$comp-Remote address and port of $($_.Name)"}
    "$domain,$file,nettcpconnection.json.07,$comp-$(($doc|?{$_.State -eq 5 -and $_.LocalAddress -notin @("127.0.0.1","::1") -and $_.LocalPort -notin @(1024..65535) -and $_.RemotePort -in @(1024..65535) -and $_.RemoteAddress -ne $_.LocalAddress}|group RemoteAddress|measure).Count) remote addresses with established inbound connections"
    #$doc|?{$_.State -eq 5 -and $_.LocalAddress -notin @("127.0.0.1","::1") -and $_.LocalPort -notin @(1024..65535) -and $_.RemotePort -in @(1024..65535) -and $_.RemoteAddress -ne $_.LocalAddress}|group LocalPort,RemoteAddress|%{"$domain,$file,nettcpconnection.json.08,$comp-Local port with established connection from remote address $($_.Name)"}
    "$domain,$file,nettcpconnection.json.09,$comp-$(($doc|?{$_.RemoteAddress -notin @("0.0.0.0","127.0.0.1","::","::1") -and $_.RemoteAddress -notlike "10.*" -and $_.RemoteAddress -notmatch "172\.([1][6-9]|[2][0-9]|[3][0-1])\..*" -and $_.RemoteAddress -notlike "192.168.*" -and $_.RemoteAddress -notlike "fe80*"}|measure).Count) remote public addresses with established outbound connections"
    $doc|?{$_.RemoteAddress -notin @("0.0.0.0","127.0.0.1","::","::1") -and $_.RemoteAddress -notlike "10.*" -and $_.RemoteAddress -notmatch "172\.([1][6-9]|[2][0-9]|[3][0-1])\..*" -and $_.RemoteAddress -notlike "192.168.*" -and $_.RemoteAddress -notlike "fe80*"}|%{"$domain,$file,nettcpconnection.json.10,$comp-Outbound established connection to remote public address $($_.RemoteAddress) over port $($_.RemotePort)"}
    "$domain,$file,nettcpconnection.json.09,$comp-$(($doc|?{$_.RemoteAddress -notlike "10.*" -and $_.RemoteAddress -notmatch "172\.([1][6-9]|[2][0-9]|[3][0-1])\..*" -and $_.RemoteAddress -notlike "192.168.*" -and $_.RemoteAddress -notin @("0.0.0.0","127.0.0.1","::","::1") -and $_.LocalPort -notin @(49152..65535) -and $_.RemoteAddress -notlike "fe80*"}|measure).Count) remote public addresses with established inbound connections"
    "$domain,$file,nettcpconnection.json.10,$comp-$(($doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(49152..65535) -and $_.LocalPort -notin $knownDcPorts}|group LocalPort|measure).Count) non-dynamic (2012+), non-standard domain controller, listening ports identified"
    #$doc|?{$_.State -eq 2 -and $_.LocalPort -notin @(49152..65535) -and $_.LocalPort -notin $knownDcPorts}|group LocalPort|%{"$domain,$file,nettcpconnection.json.11,$comp-TCP Port $($_.Name) non-standard domain controller listening port"}
    "$domain,$file,nettcpconnection.json.12,$comp-$(($doc|?{$_.State -eq 2 -and $_.LocalPort -in $knownDcPorts}|group LocalPort|measure).Count)/$(($knownDcPorts|measure).Count) standard domain controller listening ports identified"
}

#GPOBackup.01,number of ADM files

#$adUser=gc "$path\get-aduser.json"|ConvertFrom-Json -AsHashtable

#$repadmin=gc "$path\repadmin.txt"
#repadmin.txt.01,failure rate
#repadmin.txt.02,largest delta

#$showBackup=gc "$path\repadminShowBackup.txt"
#Verify last backup time should be [less than X days]

#$adComputer=gc "$path\get-adComputer.json"|ConvertFrom-Json -AsHashtable
#unixUserPassword

#$adFrsSubscribers=gc "$path\get-adfrssubscribers.json"|ConvertFrom-Json -AsHashtable
#not null

#$adGroups=gc "$path\get-adgroup.json"|ConvertFrom-Json -AsHashtable

#$adSchemaHistory=gc "$path\get-adschemahistory.json"|ConvertFrom-Json -AsHashtable

#$adReplicationSite=gc "$path\get-adreplicationsite.json"|ConvertFrom-Json -AsHashtable
#Verify each DC in replication site can [reach other replication members]

#$adObjectDomainController=gc "$path\get-adobjectdomaincontroller.json"|ConvertFrom-Json -AsHashtable
#Verify each FSMO holder is [reachable]

#Get-ADObjects|Group ObjectClass for enabled and disabled object classes
#Analyze for unusual object types
#https://twitter.com/SamErde/status/1588259903021674496

#Verify each Trust TGTDelegation is set to True
#msds-keyversionnumber
#schedule, ReplicateToDirectoryServer, ReplicateFromDirectoryServer, Options, PartiallyReplicatedNamingContexts
#Verify each site link uses notifications
#$adConfiguration|?{$_.ObjectClass -eq "pKIEnrollmentService"}|select msPKI-Site-Name
#($adConfiguration|?{$_.DistinguishedName -like "*,CN=CDP,CN=Public Key Services,CN=Services,CN=Configuration,DC=*" -and $_.ObjectClass -eq "cRLDistributionPoint"})|select certificateRevocationList,deltaRevocationList
#KRA
#PublicKeyRequiredPasswordRolling
#((get-addomaincontroller -filter * -Server $domain).computerObjectDN | Get-ADObject -Server $domain -properties ProtectedFromAccidentalDeletion | Where-Object { -not $_.ProtectedFromAccidentalDeletion })
#siteList, schedule, cost, replInterval
#NTDS Site Settings for each site

<#
Verify folder is at it's defaults.
ComputersContainer, DomainControllersContainer, UsersContainer, DeletedObjectsContainer, SystemsContainer, LostAndFoundContainer, QuotasContainer, ForeignSecurityPrincipalsContainer
Verify there are no orphaned FSP objects.
Verify Domain Controller is writable (DSA Not Writable)
Domain Controller
Verify all {Services} are [running]
Verify all {Services} are set to [automatic startup]
Verify Print Spooler Service is set to disabled
Verify Print Spooler Service is stopped
Verify DC is [reachable]
Verify Following ports 53, 88, 135, 139, 389, 445, 464, 636, 3268, 3269, 9389 are open
Verify Following ports 3389 (RDP) is open
Verify NLA is enabled
Verify all {LDAP Ports} are open]
Verify all {LDAP SSL Ports} are open]
Verify windows firewall is enabled for all network cards
Verify Windows Remote Management identification requests are managed
Verify DNS on DC [resolves Internal DNS]
Verify DNS on DC [resolves External DNS]
Verify DNS Name servers for primary zone are identical
Verify DNS for interfaces
Verify DC responds to PowerShell queries
Verify PDC should [sync time to external source]
Verify Non-PDC should [sync time to PDC emulator]
Verify Virtualized DCs should [sync to hypervisor during boot time only]
Verify Time Synchronization Difference to PDC [less than X seconds]
Verify Time Synchronization Difference to pool.ntp.org [less than X seconds]
Verify OS partition Free space is [at least X %]
Verify NTDS partition Free space is [at least X %]
Verify multiple disks are used
Verify Windows Operating system is Windows 2012 or higher
Verify Last patch was installed less than 60 days ago
Verify default SMB shares NETLOGON/SYSVOL are visible
Verify DFSR AutoRecovery is enabled
Verify Windows Features for AD/DNS/File Services are enabled
#>
#endregion