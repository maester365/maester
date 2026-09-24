function Test-MtSysvolWindowsPlatform {
    <#
    .SYNOPSIS
    Determines whether the SYSVOL Windows adapter should be used.

    .DESCRIPTION
    Returns true on Windows PowerShell and PowerShell running on Windows. This
    helper isolates platform detection so the public transport contract does
    not expose platform-specific switches.

    .EXAMPLE
    Test-MtSysvolWindowsPlatform
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows
}

function Resolve-MtSysvolRelativePath {
    <#
    .SYNOPSIS
    Validates and normalizes a path below a GPO's SYSVOL directory.

    .DESCRIPTION
    Rejects rooted paths, parent traversal, alternate data streams, control
    characters, and SMB command delimiters before returning a slash-normalized
    relative path.

    .PARAMETER Path
    Relative path below the selected GPO directory.

    .PARAMETER AllowEmpty
    Allows an empty path for operations that address the GPO root.

    .EXAMPLE
    Resolve-MtSysvolRelativePath -Path 'Machine/Preferences/Groups/Groups.xml'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$Path,

        [switch]$AllowEmpty
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        if ($AllowEmpty) {
            return ''
        }
        throw 'A relative SYSVOL path is required for this operation.'
    }

    $normalizedPath = $Path.Replace('\', '/').Trim()
    if ($normalizedPath.StartsWith('/') -or
        $normalizedPath -match '^[A-Za-z]:' -or
        $normalizedPath -match '(^|/)\.\.(/|$)' -or
        $normalizedPath -match '(^|/)\.(/|$)' -or
        $normalizedPath.IndexOfAny([char[]]@(':', '"', ';', "`r", "`n", [char]0)) -ge 0) {
        throw "The SYSVOL path '$Path' is not a safe relative path below the selected GPO."
    }

    $normalizedPath = ($normalizedPath -split '/+' | Where-Object { $_ }) -join '/'
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -and -not $AllowEmpty) {
        throw 'A relative SYSVOL path is required for this operation.'
    }

    return $normalizedPath
}

function ConvertFrom-MtSysvolByteArray {
    <#
    .SYNOPSIS
    Converts bounded SYSVOL file bytes to text.

    .DESCRIPTION
    Honors UTF-8, UTF-16 little-endian, and UTF-16 big-endian byte order marks.
    Files without a byte order mark are decoded as strict UTF-8, with UTF-16
    little-endian used only when the byte pattern indicates UTF-16 text.

    .PARAMETER Bytes
    Bounded bytes read by a SYSVOL adapter.

    .EXAMPLE
    ConvertFrom-MtSysvolByteArray -Bytes ([Text.Encoding]::UTF8.GetBytes('Version=1'))
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        return [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        return [Text.Encoding]::Unicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        return [Text.Encoding]::BigEndianUnicode.GetString($Bytes, 2, $Bytes.Length - 2)
    }

    $oddNullCount = 0
    for ($index = 1; $index -lt $Bytes.Length; $index += 2) {
        if ($Bytes[$index] -eq 0) {
            $oddNullCount++
        }
    }
    if ($Bytes.Length -ge 4 -and $oddNullCount -gt ([Math]::Floor($Bytes.Length / 8))) {
        return [Text.Encoding]::Unicode.GetString($Bytes)
    }

    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    try {
        return $utf8.GetString($Bytes)
    }
    catch {
        return [Text.Encoding]::GetEncoding(1252).GetString($Bytes)
    }
}

function ConvertFrom-MtSysvolGptIni {
    <#
    .SYNOPSIS
    Parses the version fields in GPT.INI.

    .DESCRIPTION
    Extracts the unsigned 32-bit Version value and separates its high user
    version word from its low computer version word.

    .PARAMETER Content
    Text content of GPT.INI.

    .EXAMPLE
    ConvertFrom-MtSysvolGptIni -Content "[General]`nVersion=65538"
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $versionMatch = [regex]::Match($Content, '(?im)^\s*Version\s*=\s*(?<version>\d+)\s*$')
    if (-not $versionMatch.Success) {
        throw 'GPT.INI does not contain a valid Version value.'
    }

    $version = [uint32]::Parse($versionMatch.Groups['version'].Value, [Globalization.CultureInfo]::InvariantCulture)
    return [PSCustomObject][ordered]@{
        Version         = $version
        UserVersion     = [uint16](($version -shr 16) -band 0xFFFF)
        ComputerVersion = [uint16]($version -band 0xFFFF)
    }
}

function ConvertFrom-MtSysvolGppXml {
    <#
    .SYNOPSIS
    Parses Group Policy Preferences XML for password findings.

    .DESCRIPTION
    Loads XML with DTD processing prohibited, finds cpassword attributes at any
    depth, and detects common weak plaintext defaults only in password-named
    XML attributes or elements. Password values are never returned.

    .PARAMETER Content
    XML text to inspect.

    .PARAMETER RelativePath
    Normalized path used in non-secret finding evidence.

    .EXAMPLE
    ConvertFrom-MtSysvolGppXml -Content '<Groups><User cpassword="x" /></Groups>' -RelativePath 'Groups.xml'
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Content), $settings)
    try {
        $document = [Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($reader)
    }
    finally {
        $reader.Dispose()
    }

    $cpasswordNodes = @($document.SelectNodes('//@*[translate(local-name(), "CPASSWORD", "cpassword")="cpassword"]'))
    $weakPasswords = @('password', 'password1', 'p@ssw0rd', 'admin', 'administrator', 'changeme', 'welcome', 'default', 'letmein', '123456')
    $defaultPasswordFound = $false
    foreach ($attribute in @($document.SelectNodes('//@*'))) {
        if ($attribute.LocalName -match '(?i)^(password|passwd|pwd|defaultpassword)$' -and $weakPasswords -contains $attribute.Value.Trim().ToLowerInvariant()) {
            $defaultPasswordFound = $true
            break
        }
    }
    if (-not $defaultPasswordFound) {
        foreach ($element in @($document.SelectNodes('//*[translate(local-name(), "PASSWORD", "password")="password" or translate(local-name(), "DEFAULTPASSWORD", "defaultpassword")="defaultpassword"]'))) {
            if ($weakPasswords -contains $element.InnerText.Trim().ToLowerInvariant()) {
                $defaultPasswordFound = $true
                break
            }
        }
    }

    return [PSCustomObject][ordered]@{
        RelativePath         = $RelativePath
        CpasswordFound       = $cpasswordNodes.Count -gt 0
        CpasswordCount       = $cpasswordNodes.Count
        DefaultPasswordFound = $defaultPasswordFound
    }
}

function ConvertFrom-MtSysvolSecurityTemplate {
    <#
    .SYNOPSIS
    Parses relevant sections of a GptTmpl.inf security template.

    .DESCRIPTION
    Returns ordered Registry Values and Privilege Rights dictionaries. Other
    INF sections are deliberately ignored because they are not required by the
    GPO state checks.

    .PARAMETER Content
    Text content of GptTmpl.inf.

    .EXAMPLE
    ConvertFrom-MtSysvolSecurityTemplate -Content "[Privilege Rights]`nSeDebugPrivilege=*S-1-5-32-544"
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $registryValues = [ordered]@{}
    $privilegeRights = [ordered]@{}
    $currentSection = $null
    foreach ($line in ($Content -split "`r?`n")) {
        $trimmedLine = $line.Trim()
        if (-not $trimmedLine -or $trimmedLine.StartsWith(';')) {
            continue
        }
        if ($trimmedLine -match '^\[(?<section>[^\]]+)\]$') {
            $currentSection = $Matches['section']
            continue
        }
        if ($trimmedLine -notmatch '^(?<name>[^=]+?)\s*=\s*(?<value>.*)$') {
            continue
        }
        if ($currentSection -eq 'Registry Values') {
            $registryValues[$Matches['name'].Trim()] = $Matches['value'].Trim()
        }
        elseif ($currentSection -eq 'Privilege Rights') {
            $privilegeRights[$Matches['name'].Trim()] = $Matches['value'].Trim()
        }
    }

    $weakPasswords = @('password', 'password1', 'p@ssw0rd', 'admin', 'administrator', 'changeme', 'welcome', 'default', 'letmein', '123456')
    $defaultPasswordFound = $false
    foreach ($entry in $registryValues.GetEnumerator()) {
        if ($entry.Key -match '(?i)(default)?pass(word|wd)?') {
            $candidateValue = ([string]$entry.Value -split ',', 2)[-1].Trim().Trim('"').ToLowerInvariant()
            if ($weakPasswords -contains $candidateValue) {
                $defaultPasswordFound = $true
                break
            }
        }
    }

    return [PSCustomObject][ordered]@{
        RegistryValues       = $registryValues
        PrivilegeRights      = $privilegeRights
        DefaultPasswordFound = $defaultPasswordFound
    }
}

function Invoke-MtSysvolProcess {
    <#
    .SYNOPSIS
    Runs the native smbclient process with a timeout.

    .DESCRIPTION
    Starts smbclient directly without a command shell, captures its output,
    terminates it when the timeout expires, and returns a normalized result.

    .PARAMETER Arguments
    Individual smbclient arguments.

    .PARAMETER TimeoutSeconds
    Maximum process duration.

    .EXAMPLE
    Invoke-MtSysvolProcess -Arguments @('//dc/SYSVOL', '--kerberos', '--command', 'ls') -TimeoutSeconds 60
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds
    )

    $process = $null
    try {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'smbclient'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $Arguments) {
            $startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            throw 'Unable to start smbclient.'
        }
        $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            throw "smbclient exceeded the $TimeoutSeconds second timeout."
        }
        $standardOutput = $standardOutputTask.GetAwaiter().GetResult()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "smbclient failed with exit code $($process.ExitCode): $standardError"
        }

        return [PSCustomObject][ordered]@{
            StandardOutput = $standardOutput
            StandardError  = $standardError
            ExitCode       = $process.ExitCode
        }
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Invoke-MtSysvolSmbClient {
    <#
    .SYNOPSIS
    Invokes smbclient with bounded execution and protected credentials.

    .DESCRIPTION
    Creates a mode-600 smbclient authentication file when explicit credentials
    exist, invokes smbclient without a shell, enforces a timeout, and removes
    the authentication file in a finally block. Kerberos is used when no
    explicit credential is present.

    .PARAMETER Server
    Resolved domain controller DNS name.

    .PARAMETER Domain
    Resolved Active Directory DNS domain.

    .PARAMETER Credential
    Session credential used for SYSVOL access.

    .PARAMETER Arguments
    Non-secret smbclient arguments following the share name.

    .PARAMETER TimeoutSeconds
    Maximum duration of the smbclient process.

    .EXAMPLE
    Invoke-MtSysvolSmbClient -Server 'dc.contoso.com' -Domain 'contoso.com' -Arguments @('--command', 'ls')
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [string]$Domain,

        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 60
    )

    $authFile = $null
    try {
        $processArguments = [Collections.Generic.List[string]]::new()
        $processArguments.Add("//$Server/SYSVOL")
        if ($null -ne $Credential) {
            $authFile = [IO.Path]::GetTempFileName()
            $networkCredential = $Credential.GetNetworkCredential()
            $authDomain = if ($networkCredential.Domain) { $networkCredential.Domain } else { $Domain }
            $authContent = "username = $($networkCredential.UserName)`npassword = $($networkCredential.Password)`ndomain = $authDomain`n"
            [IO.File]::WriteAllText($authFile, $authContent, [Text.UTF8Encoding]::new($false))
            if ([Enum]::GetNames([IO.FileMode]).Count -ge 0 -and $PSVersionTable.PSVersion.Major -ge 7) {
                [IO.File]::SetUnixFileMode($authFile, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
            }
            else {
                & chmod 600 -- $authFile
                if ($LASTEXITCODE -ne 0) {
                    throw 'Failed to protect the temporary smbclient authentication file.'
                }
            }
            $processArguments.Add("--authentication-file=$authFile")
        }
        else {
            $processArguments.Add('--kerberos')
        }
        foreach ($argument in $Arguments) {
            $processArguments.Add($argument)
        }

        return Invoke-MtSysvolProcess -Arguments @($processArguments) -TimeoutSeconds $TimeoutSeconds
    }
    finally {
        if ($authFile -and [IO.File]::Exists($authFile)) {
            [IO.File]::Delete($authFile)
        }
    }
}

function Invoke-MtSysvolWindowsAdapter {
    <#
    .SYNOPSIS
    Executes one bounded SYSVOL operation through a temporary Windows PSDrive.

    .DESCRIPTION
    Maps the resolved server's SYSVOL share with the session credential and
    always removes the temporary drive in a finally block.

    .PARAMETER Operation
    Connect, List, ReadText, or ReadBytes.

    .PARAMETER Server
    Resolved domain controller.

    .PARAMETER Domain
    Resolved domain DNS name.

    .PARAMETER GpoGuid
    Brace-delimited GPO GUID.

    .PARAMETER RelativePath
    Validated relative file path.

    .PARAMETER Credential
    Session credential.

    .PARAMETER MaxFileBytes
    Maximum accepted file size.

    .EXAMPLE
    Invoke-MtSysvolWindowsAdapter -Operation Connect -Server dc -Domain contoso.com -GpoGuid '{00000000-0000-0000-0000-000000000000}'
    #>
    [CmdletBinding()]
    [OutputType([object[]], [bool], [string], [byte[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Connect', 'List', 'ReadText', 'ReadBytes')]
        [string]$Operation,
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][string]$GpoGuid,
        [string]$RelativePath,
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory)][long]$MaxFileBytes
    )

    $driveName = 'MtSysvol' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
    try {
        $driveParameters = @{
            Name       = $driveName
            PSProvider = 'FileSystem'
            Root       = "\\$Server\SYSVOL"
            Scope      = 'Global'
            ErrorAction = 'Stop'
        }
        if ($null -ne $Credential) {
            $driveParameters['Credential'] = $Credential
        }
        New-PSDrive @driveParameters | Out-Null
        $gpoRoot = "$driveName`:\$Domain\Policies\$GpoGuid"
        if (-not (Test-Path -LiteralPath $gpoRoot -PathType Container)) {
            throw "The SYSVOL GPO path is not accessible for GPO '$GpoGuid'."
        }
        if ($Operation -eq 'Connect') {
            return $true
        }
        if ($Operation -eq 'List') {
            return @(Get-ChildItem -LiteralPath $gpoRoot -File -Recurse -Force -ErrorAction Stop | ForEach-Object {
                    $relative = $_.FullName.Substring($gpoRoot.Length).TrimStart('\', '/').Replace('\', '/')
                    [PSCustomObject][ordered]@{ RelativePath = $relative; Name = $_.Name; Length = [long]$_.Length }
                })
        }

        $filePath = Join-Path $gpoRoot ($RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        $fileInfo = Get-Item -LiteralPath $filePath -Force -ErrorAction Stop
        if ($fileInfo.Length -gt $MaxFileBytes) {
            throw "SYSVOL file '$RelativePath' exceeds the maximum single-file size of $MaxFileBytes bytes."
        }
        $bytes = [IO.File]::ReadAllBytes($fileInfo.FullName)
        if ($Operation -eq 'ReadText') {
            return ConvertFrom-MtSysvolByteArray -Bytes $bytes
        }
        return $bytes
    }
    finally {
        Remove-PSDrive -Name $driveName -Scope Global -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-MtSysvolUnixAdapter {
    <#
    .SYNOPSIS
    Executes one bounded SYSVOL operation through smbclient.

    .DESCRIPTION
    Uses smbclient without a shell and downloads files into short-lived local
    temporary files before enforcing size bounds and returning normalized data.

    .PARAMETER Operation
    Connect, List, ReadText, or ReadBytes.

    .PARAMETER Server
    Resolved domain controller.

    .PARAMETER Domain
    Resolved domain DNS name.

    .PARAMETER GpoGuid
    Brace-delimited GPO GUID.

    .PARAMETER RelativePath
    Validated relative file path.

    .PARAMETER Credential
    Session credential.

    .PARAMETER MaxFileBytes
    Maximum accepted file size.

    .PARAMETER TimeoutSeconds
    Maximum smbclient execution duration.

    .EXAMPLE
    Invoke-MtSysvolUnixAdapter -Operation Connect -Server dc -Domain contoso.com -GpoGuid '{00000000-0000-0000-0000-000000000000}'
    #>
    [CmdletBinding()]
    [OutputType([object[]], [bool], [string], [byte[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Connect', 'List', 'ReadText', 'ReadBytes')]
        [string]$Operation,
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter(Mandatory)][string]$GpoGuid,
        [string]$RelativePath,
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory)][long]$MaxFileBytes,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )

    $gpoDirectory = "$Domain/Policies/$GpoGuid"
    if ($Operation -eq 'Connect') {
        Invoke-MtSysvolSmbClient -Server $Server -Domain $Domain -Credential $Credential -Arguments @('--directory', $gpoDirectory, '--command', 'ls') -TimeoutSeconds $TimeoutSeconds | Out-Null
        return $true
    }
    if ($Operation -eq 'List') {
        $response = Invoke-MtSysvolSmbClient -Server $Server -Domain $Domain -Credential $Credential -Arguments @('--directory', $gpoDirectory, '--command', 'recurse;ls') -TimeoutSeconds $TimeoutSeconds
        $currentDirectory = ''
        $files = [Collections.Generic.List[object]]::new()
        foreach ($line in ($response.StandardOutput -split "`r?`n")) {
            if ($line -match '^\\(?<directory>.+)$') {
                $currentDirectory = $Matches['directory'].Replace('\', '/')
                if ($currentDirectory.StartsWith($gpoDirectory, [StringComparison]::OrdinalIgnoreCase)) {
                    $currentDirectory = $currentDirectory.Substring($gpoDirectory.Length).TrimStart('/')
                }
                continue
            }
            if ($line -match '^\s*(?<name>.+?)\s+(?<attributes>[A-Z]+)\s+(?<length>\d+)\s+.+$' -and $Matches['attributes'] -notmatch 'D') {
                $name = $Matches['name'].Trim()
                if ($name -in '.', '..') { continue }
                $relativePath = if ($currentDirectory) { "$currentDirectory/$name" } else { $name }
                $relativePath = Resolve-MtSysvolRelativePath -Path $relativePath
                $files.Add([PSCustomObject][ordered]@{ RelativePath = $relativePath; Name = $name; Length = [long]$Matches['length'] })
            }
        }
        return @($files)
    }

    $temporaryFile = [IO.Path]::GetTempFileName()
    try {
        $remotePath = "$gpoDirectory/$RelativePath"
        $command = 'get "{0}" "{1}"' -f $remotePath, $temporaryFile.Replace('"', '')
        Invoke-MtSysvolSmbClient -Server $Server -Domain $Domain -Credential $Credential -Arguments @('--command', $command) -TimeoutSeconds $TimeoutSeconds | Out-Null
        $fileInfo = [IO.FileInfo]::new($temporaryFile)
        if ($fileInfo.Length -gt $MaxFileBytes) {
            throw "SYSVOL file '$RelativePath' exceeds the maximum single-file size of $MaxFileBytes bytes."
        }
        $bytes = [IO.File]::ReadAllBytes($temporaryFile)
        if ($Operation -eq 'ReadText') {
            return ConvertFrom-MtSysvolByteArray -Bytes $bytes
        }
        return $bytes
    }
    finally {
        if ([IO.File]::Exists($temporaryFile)) {
            [IO.File]::Delete($temporaryFile)
        }
    }
}

function Get-MtSysvolContent {
    <#
    .SYNOPSIS
    Reads and analyzes one Group Policy Object from SYSVOL.

    .DESCRIPTION
    Provides a single private Connect, List, ReadText, and ReadBytes transport
    contract across Windows native SMB and Unix smbclient. It uses the resolved
    Active Directory server, domain, and credential in the Maester session.

    Connect validates access, lists bounded files, and parses GPT.INI, every XML
    file below the GPO, and GptTmpl.inf. No password values are returned. Reads
    reject unsafe paths and throw instead of truncating files over 10 MiB or a
    GPO inventory over 100 MiB.

    .PARAMETER Operation
    Connect returns a complete analysis; List returns normalized file metadata;
    ReadText and ReadBytes return one bounded file.

    .PARAMETER GpoGuid
    GPO identifier, with or without braces.

    .PARAMETER RelativePath
    Relative file path required by ReadText and ReadBytes.

    .PARAMETER MaxFileBytes
    Single-file bound. Defaults to 10 MiB and cannot exceed 10 MiB.

    .PARAMETER MaxGpoBytes
    Aggregate GPO bound. Defaults to 100 MiB and cannot exceed 100 MiB.

    .PARAMETER TimeoutSeconds
    Unix smbclient timeout for each operation.

    .EXAMPLE
    Get-MtSysvolContent -Operation Connect -GpoGuid '{00000000-0000-0000-0000-000000000000}'

    .EXAMPLE
    Get-MtSysvolContent -Operation ReadText -GpoGuid '{00000000-0000-0000-0000-000000000000}' -RelativePath 'GPT.INI'
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Connect', 'List', 'ReadText', 'ReadBytes')]
        [string]$Operation = 'Connect',

        [Parameter(Mandatory)]
        [string]$GpoGuid,

        [string]$RelativePath,

        [ValidateRange(1, 10485760)]
        [long]$MaxFileBytes = 10MB,

        [ValidateRange(1, 104857600)]
        [long]$MaxGpoBytes = 100MB,

        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 60
    )

    if ($null -eq $__MtSession.ADConnection -or -not $__MtSession.ADConnection.ProtocolValidated) {
        throw 'A protocol-validated Active Directory connection is required before accessing SYSVOL.'
    }
    $server = [string]$__MtSession.ADConnection.ResolvedServer
    $domain = [string]$__MtSession.ADConnection.ResolvedDomain
    if ([string]::IsNullOrWhiteSpace($server) -or [string]::IsNullOrWhiteSpace($domain)) {
        throw 'The Active Directory session does not contain a resolved server and domain.'
    }

    $guidValue = [Guid]::Empty
    if (-not [Guid]::TryParse($GpoGuid.Trim('{}'), [ref]$guidValue)) {
        throw "The GPO identifier '$GpoGuid' is not a valid GUID."
    }
    $normalizedGuid = '{' + $guidValue.ToString().ToUpperInvariant() + '}'
    $normalizedPath = Resolve-MtSysvolRelativePath -Path $RelativePath -AllowEmpty:($Operation -in 'Connect', 'List')
    if ($Operation -in 'ReadText', 'ReadBytes' -and [string]::IsNullOrWhiteSpace($normalizedPath)) {
        throw "RelativePath is required for the $Operation operation."
    }

    $adapterParameters = @{
        Server          = $server
        Domain          = $domain
        GpoGuid         = $normalizedGuid
        RelativePath    = $normalizedPath
        Credential      = $__MtSession.ADCredential
        MaxFileBytes    = $MaxFileBytes
    }
    $adapter = if (Test-MtSysvolWindowsPlatform) { 'Windows' } else { 'Unix' }
    $invokeAdapter = {
        param(
            [string]$AdapterOperation,
            [int]$AdapterTimeoutSeconds
        )
        if ($adapter -eq 'Windows') {
            return Invoke-MtSysvolWindowsAdapter -Operation $AdapterOperation @adapterParameters
        }
        return Invoke-MtSysvolUnixAdapter -Operation $AdapterOperation @adapterParameters -TimeoutSeconds $AdapterTimeoutSeconds
    }

    if ($Operation -ne 'Connect') {
        return & $invokeAdapter $Operation $TimeoutSeconds
    }

    Write-Verbose "Connecting to SYSVOL on '$server' for GPO '$normalizedGuid' using the $adapter adapter."
    & $invokeAdapter 'Connect' $TimeoutSeconds | Out-Null
    $files = @(& $invokeAdapter 'List' $TimeoutSeconds)
    $totalBytes = [long]0
    foreach ($file in $files) {
        if ($file.Length -gt $MaxFileBytes) {
            throw "SYSVOL file '$($file.RelativePath)' exceeds the maximum single-file size of $MaxFileBytes bytes."
        }
        $totalBytes += [long]$file.Length
        if ($totalBytes -gt $MaxGpoBytes) {
            throw "SYSVOL content for GPO '$normalizedGuid' exceeds the maximum aggregate size of $MaxGpoBytes bytes."
        }
    }

    $gptIni = $null
    $gppXml = [Collections.Generic.List[object]]::new()
    $securityTemplates = [Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $path = [string]$file.RelativePath
        if ($path -match '(?i)(^|/)GPT\.INI$') {
            $adapterParameters['RelativePath'] = $path
            $gptIni = ConvertFrom-MtSysvolGptIni -Content (& $invokeAdapter 'ReadText' $TimeoutSeconds)
        }
        elseif ($path -match '(?i)\.xml$') {
            $adapterParameters['RelativePath'] = $path
            try {
                $gppXml.Add((ConvertFrom-MtSysvolGppXml -Content (& $invokeAdapter 'ReadText' $TimeoutSeconds) -RelativePath $path))
            }
            catch {
                Write-Verbose "Could not parse SYSVOL XML file '$path': $($_.Exception.Message)"
            }
        }
        elseif ($path -match '(?i)(^|/)GptTmpl\.inf$') {
            $adapterParameters['RelativePath'] = $path
            $parsedTemplate = ConvertFrom-MtSysvolSecurityTemplate -Content (& $invokeAdapter 'ReadText' $TimeoutSeconds)
            $securityTemplates.Add([PSCustomObject][ordered]@{
                    RelativePath    = $path
                    RegistryValues  = $parsedTemplate.RegistryValues
                    PrivilegeRights = $parsedTemplate.PrivilegeRights
                    DefaultPasswordFound = $parsedTemplate.DefaultPasswordFound
                })
        }
    }

    return [PSCustomObject][ordered]@{
        GpoGuid              = $normalizedGuid
        Server               = $server
        Domain               = $domain
        Adapter              = $adapter
        RootPath             = "//$server/SYSVOL/$domain/Policies/$normalizedGuid"
        Files                = $files
        TotalBytes           = $totalBytes
        GptIni               = $gptIni
        GppXml               = @($gppXml)
        SecurityTemplates    = @($securityTemplates)
        CpasswordFound       = [bool]($gppXml | Where-Object CpasswordFound | Select-Object -First 1)
        DefaultPasswordFound = [bool](
            ($gppXml | Where-Object DefaultPasswordFound | Select-Object -First 1) -or
            ($securityTemplates | Where-Object DefaultPasswordFound | Select-Object -First 1)
        )
    }
}
