2.1.11 (L2) Ensure comprehensive attachment filtering is applied

The Common Attachment Types Filter lets a user block known and custom malicious file types from being attached to emails. The policy provided by Microsoft covers 53 extensions, and an additional custom list of extensions can be defined.
The list of 184 extensions provided in this recommendation is comprehensive but not exhaustive.

#### Rationale

Blocking known malicious file types can help prevent malware-infested files from infecting a host or performing other malicious attacks such as phishing and data extraction.
Defining a comprehensive list of attachments can help protect against additional unknown and known threats. Many legacy file formats, binary files and compressed files have been used as delivery mechanisms for malicious software. Organizations can protect themselves from Business E-mail Compromise (BEC) by allow-listing only the file types relevant to their line of business and blocking all others.

#### Impact

For file types that are business necessary users will need to use other organizationally approved methods to transfer blocked extension types between business partners.

#### Remediation action:

To implement a new policy containing a comprehensive list of extensions:
1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following script after editing **InternalSenderAdminAddress**:
```
# Create an attachment policy and associated rule. The rule is
# intentionally disabled allowing the org to enable it when ready
$Policy = @{
    Name                                   = "CIS L2 Attachment Policy"
    EnableFileFilter                       = $true
    ZapEnabled                             = $true
    EnableInternalSenderAdminNotifications = $true
    InternalSenderAdminAddress             = 'admin@contoso.com' # Change this.
}
$L2Extensions = @(
    "7z", "a3x", "ace", "ade", "adp", "ani", "app", "appinstaller",
    "applescript", "application", "appref-ms", "appx", "appxbundle", "arj",
    "asd", "asx", "bas", "bat", "bgi", "bz2", "cab", "chm", "cmd", "com",
    "cpl", "crt", "cs", "csh", "daa", "dbf", "dcr", "deb",
    "desktopthemepackfile", "dex", "diagcab", "dif", "dir", "dll", "dmg",
    "doc", "docm", "dot", "dotm", "elf", "eml", "exe", "fxp", "gadget", "gz",
    "hlp", "hta", "htc", "htm", "html", "hwpx", "ics", "img",
    "inf", "ins", "iqy", "iso", "isp", "jar", "jnlp", "js", "jse", "kext",
    "ksh", "lha", "lib", "library-ms", "lnk", "lzh", "macho", "mam", "mda",
    "mdb", "mde", "mdt", "mdw", "mdz", "mht", "mhtml", "mof", "msc", "msi",
    "msix", "msp", "msrcincident", "mst", "ocx", "odt", "ops", "oxps", "pcd",
    "pif", "plg", "pot", "potm", "ppa", "ppam", "ppkg", "pps", "ppsm", "ppt",
    "pptm", "prf", "prg", "ps1", "ps11", "ps11xml", "ps1xml", "ps2",
    "ps2xml", "psc1", "psc2", "pub", "py", "pyc", "pyo", "pyw", "pyz",
    "pyzw", "rar", "reg", "rev", "rtf", "scf", "scpt", "scr", "sct",
    "searchConnector-ms", "service", "settingcontent-ms", "sh", "shb", "shs",
    "shtm", "shtml", "sldm", "slk", "so", "spl", "stm", "svg", "swf", "sys",
    "tar", "theme", "themepack", "timer", "uif", "url", "uue", "vb", "vbe",
    "vbs", "vhd", "vhdx", "vxd", "wbk", "website", "wim", "wiz", "ws", "wsc",
    "wsf", "wsh", "xla", "xlam", "xlc", "xll", "xlm", "xls", "xlsb", "xlsm",
    "xlt", "xltm", "xlw", "xnk", "xps", "xsl", "xz", "z"
)
# Create the policy
New-MalwareFilterPolicy @Policy -FileTypes $L2Extensions
# Create the rule for all accepted domains
$Rule = @{
    Name                = $Policy.Name
    Enabled             = $false
    MalwareFilterPolicy = $Policy.Name
    RecipientDomainIs   = (Get-AcceptedDomain).Name
    Priority            = 0
}
New-MalwareFilterRule @Rule
```
3. When prepared enable the rule either through the UI or PowerShell.

#### Related links

* [Microsoft 365 Defender](https://security.microsoft.com)
* [Get-MalwareFilterPolicy](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/get-malwarefilterpolicy?view=exchange-ps)
* [Configure anti-malware policies for cloud mailboxes](https://learn.microsoft.com/en-us/defender-office-365/anti-malware-policies-configure?view=o365-worldwide)
* [File format reference for Word, Excel, and PowerPoint](https://learn.microsoft.com/en-us/office/compatibility/office-file-format-reference)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 109](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%