Set-StrictMode -Version 2.0

<#
.SYNOPSIS
    Get path relative to working directory.
.EXAMPLE
    PS C:\>Get-RelativePath 'C:\DirectoryA\File1.txt'
    Get path relative to current directory.
.EXAMPLE
    PS C:\>Get-RelativePath 'C:\DirectoryA\File1.txt' -WorkingDirectory 'C:\DirectoryB' -CompareCase
    Get path relative to specified working directory with case-sensitive directory comparison.
.INPUTS
    System.String
#>
function Get-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Input paths
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]] $InputObjects,
        # Working directory for relative paths. Default is current directory.
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $WorkingDirectory = (Get-Location).ProviderPath,
        # Compare directory names as case-sensitive.
        [Parameter(Mandatory = $false)]
        [switch] $CompareCase,
        # Directory separator used in paths.
        [Parameter(Mandatory = $false)]
        [char] $DirectorySeparator = [System.IO.Path]::DirectorySeparatorChar
    )

    begin {
        ## Adapted From:
        ##  https://github.com/dotnet/runtime/blob/6072e4d3a7a2a1493f514cdf4be75a3d56580e84/src/libraries/System.Private.Uri/src/System/Uri.cs#L5037
        function PathDifference([string] $path1, [string] $path2, [bool] $compareCase, [char] $directorySeparator = [System.IO.Path]::DirectorySeparatorChar) {
            [int] $i = 0
            [int] $si = -1

            for ($i = 0; ($i -lt $path1.Length) -and ($i -lt $path2.Length); $i++) {
                if (($path1[$i] -cne $path2[$i]) -and ($compareCase -or ([char]::ToLowerInvariant($path1[$i]) -cne [char]::ToLowerInvariant($path2[$i])))) {
                    break
                }
                elseif ($path1[$i] -ceq $directorySeparator) {
                    $si = $i
                }
            }

            if ($i -ceq 0) {
                return $path2
            }
            if (($i -ceq $path1.Length) -and ($i -ceq $path2.Length)) {
                return [string]::Empty
            }

            [System.Text.StringBuilder] $relPath = New-Object System.Text.StringBuilder
            ## Walk down several dirs
            for (; $i -lt $path1.Length; $i++) {
                if ($path1[$i] -ceq $directorySeparator) {
                    [void] $relPath.Append("..$directorySeparator")
                }
            }
            ## Same path except that path1 ended with a file name and path2 didn't
            if ($relPath.Length -ceq 0 -and $path2.Length - 1 -ceq $si) {
                return ".$directorySeparator" ## Truncate the file name
            }
            return $relPath.Append($path2.Substring($si + 1)).ToString()
        }
    }

    process {
        foreach ($InputObject in $InputObjects) {
            if (!$WorkingDirectory.EndsWith($DirectorySeparator)) { $WorkingDirectory += $DirectorySeparator }
            [string] $RelativePath = '.{0}{1}' -f $DirectorySeparator, (PathDifference $WorkingDirectory $InputObject $CompareCase $DirectorySeparator)
            Write-Output $RelativePath
        }
    }
}

function Get-FullPath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        # Input Paths
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [string[]] $Paths,
        # Directory to base relative paths. Default is current directory.
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $BaseDirectory = (Get-Location).ProviderPath
    )

    process {
        foreach ($Path in $Paths) {
            [string] $AbsolutePath = $Path
            if (![System.IO.Path]::IsPathRooted($AbsolutePath)) {
                $AbsolutePath = (Join-Path $BaseDirectory $AbsolutePath)
            }
            [string] $AbsolutePath = [System.IO.Path]::GetFullPath($AbsolutePath)
            Write-Output $AbsolutePath
        }
    }
}

function Resolve-FullPath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        # Input Paths
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [string[]] $Paths,
        # Directory to base relative paths. Default is current directory.
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $BaseDirectory = (Get-Location).ProviderPath,
        # Resolves items in all child directories of the specified locations.
        [Parameter(Mandatory = $false)]
        [switch] $Recurse,
        # Resolves items in all parent directories of the specified locations.
        [Parameter(Mandatory = $false)]
        [switch] $RecurseUp
    )

    process {
        foreach ($Path in $Paths) {
            [string] $AbsolutePath = $Path
            if (![System.IO.Path]::IsPathRooted($AbsolutePath)) {
                $AbsolutePath = (Join-Path $BaseDirectory $AbsolutePath)
            }
            [string[]] $AbsoluteOutputPaths = Resolve-Path $AbsolutePath
            if ($Recurse) {
                $RecurseBaseDirectory = Join-Path (Split-Path $AbsolutePath -Parent) "**"
                $RecurseFilename = Split-Path $AbsolutePath -Leaf
                $RecursePath = Join-Path $RecurseBaseDirectory $RecurseFilename
                $AbsoluteOutputPaths += Resolve-Path $RecursePath
            }
            if ($RecurseUp) {
                $RecurseBaseDirectory = Split-Path $AbsolutePath -Parent
                $RecurseFilename = Split-Path $AbsolutePath -Leaf
                while ($RecurseBaseDirectory -match "[\\/]") {
                    $RecurseBaseDirectory = Split-Path $RecurseBaseDirectory -Parent
                    if ($RecurseBaseDirectory) {
                        $RecursePath = Join-Path $RecurseBaseDirectory $RecurseFilename
                        $AbsoluteOutputPaths += Resolve-Path $RecursePath
                    }
                }
            }
            Write-Output $AbsoluteOutputPaths
        }
    }
}

function Get-PathInfo {
    [CmdletBinding()]
    param (
        # Input Paths
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [AllowEmptyString()]
        [string[]] $Paths,
        # Specifies the type of output path when the path does not exist. By default, it will guess path type. If path exists, this parameter is ignored.
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet("Directory", "File")]
        [string] $InputPathType,
        # Root directory to base relative paths. Default is current directory.
        [Parameter(Mandatory = $false, Position = 3)]
        [string] $DefaultDirectory = (Get-Location).ProviderPath,
        # Filename to append to path if no filename is present.
        [Parameter(Mandatory = $false, Position = 4)]
        [string] $DefaultFilename,
        #
        [Parameter(Mandatory = $false)]
        [switch] $SkipEmptyPaths
    )

    process {
        foreach ($Path in $Paths) {

            if (!$SkipEmptyPaths -and !$Path) { $Path = $DefaultDirectory }
            $OutputPath = $null

            if ($Path) {
                ## Look for existing path
                try {
                    $ResolvePath = Resolve-FullPath $Path -BaseDirectory $DefaultDirectory -ErrorAction Ignore
                    if ($ResolvePath) {
                        $OutputPath = Get-Item $ResolvePath -ErrorAction Ignore
                    }
                }
                catch { }
                if ($OutputPath -is [array]) {
                    $paramGetPathInfo = Select-PsBoundParameters $PSBoundParameters -CommandName Get-PathInfo -ExcludeParameters Paths
                    Get-PathInfo $OutputPath @paramGetPathInfo
                    return
                }

                [string] $AbsolutePath = $null
                ## If path could not be found and there are no wildcards, then create a FileSystemInfo object for the path.
                if (!$OutputPath -and $Path -notmatch '[*?]') {
                    ## Get Absolute Path
                    [string] $AbsolutePath = Get-FullPath $Path -BaseDirectory $DefaultDirectory
                    ## Guess if path is File or Directory
                    if ($InputPathType -eq "File" -or (!$InputPathType -and $AbsolutePath -match '[\\/](?!.*[\\/]).+\.(?!\.*$).*[^\\/]$')) {
                        $OutputPath = New-Object System.IO.FileInfo -ArgumentList $AbsolutePath
                    }
                    else {
                        $OutputPath = New-Object System.IO.DirectoryInfo -ArgumentList $AbsolutePath
                    }
                }
                ## If a DefaultFilename was provided and no filename was present in path, then add the default.
                if ($DefaultFilename -and $OutputPath -is [System.IO.DirectoryInfo]) {
                    [string] $AbsolutePath = (Join-Path $OutputPath.FullName $DefaultFileName)
                    $OutputPath = $null
                    try {
                        $ResolvePath = Resolve-FullPath $AbsolutePath -BaseDirectory $DefaultDirectory -ErrorAction Ignore
                        if ($ResolvePath) {
                            $OutputPath = Get-Item $ResolvePath -ErrorAction Ignore
                        }
                    }
                    catch { }
                    if (!$OutputPath -and $AbsolutePath -notmatch '[*?]') {
                        $OutputPath = New-Object System.IO.FileInfo -ArgumentList $AbsolutePath
                    }
                }

                if (!$OutputPath -or !$OutputPath.Exists) {
                    if ($OutputPath) { Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList ('Cannot find path ''{0}'' because it does not exist.' -f $OutputPath.FullName)) -TargetObject $OutputPath.FullName -ErrorId 'PathNotFound' -Category ObjectNotFound -ErrorAction $ErrorActionPreference }
                    elseif ($AbsolutePath) { Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList ('Cannot find path ''{0}'' because it does not exist.' -f $AbsolutePath)) -TargetObject $AbsolutePath -ErrorId 'PathNotFound' -Category ObjectNotFound -ErrorAction $ErrorActionPreference }
                    else { Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList ('Cannot find path ''{0}'' because it does not exist.' -f $Path)) -TargetObject $Path -ErrorId 'PathNotFound' -Category ObjectNotFound -ErrorAction $ErrorActionPreference }
                }
            }

            ## Return Path Info
            Write-Output $OutputPath
        }
    }
}


function Assert-DirectoryExists {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        # Directories
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [object[]] $InputObjects,
        # Directory to base relative paths. Default is current directory.
        [Parameter(Mandatory = $false, Position = 2)]
        [string] $BaseDirectory = (Get-Location).ProviderPath
    )
    process {
        foreach ($InputObject in $InputObjects) {
            ## InputObject Casting
            if ($InputObject -is [System.IO.DirectoryInfo]) {
                [System.IO.DirectoryInfo] $DirectoryInfo = $InputObject
            }
            elseif ($InputObject -is [System.IO.FileInfo]) {
                [System.IO.DirectoryInfo] $DirectoryInfo = $InputObject.Directory
            }
            elseif ($InputObject -is [string]) {
                [System.IO.DirectoryInfo] $DirectoryInfo = $InputObject
            }

            if (!$DirectoryInfo.Exists) {
                Write-Output (New-Item $DirectoryInfo.FullName -ItemType Container)
            }
        }
    }
}

function New-LogFilename ([string] $Path) { return ('{0}.{1}.log' -f $Path, (Get-Date -Format "yyyyMMddThhmmss")) }
function Get-ExtractionFolder ([System.IO.FileInfo] $Path) { return Join-Path $Path.DirectoryName $Path.BaseName }

function Use-StartBitsTransfer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Specifies the source location and the names of the files that you want to transfer.
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Source,
        # Specifies the destination location and the names of the files that you want to transfer.
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Destination,
        # Specifies the proxy usage settings
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateSet('SystemDefault', 'NoProxy', 'AutoDetect', 'Override')]
        [string] $ProxyUsage,
        # Specifies a list of proxies to use
        [Parameter(Mandatory = $false, Position = 4)]
        [uri[]] $ProxyList,
        # Specifies the authentication mechanism to use at the Web proxy
        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateSet('Basic', 'Digest', 'NTLM', 'Negotiate', 'Passport')]
        [string] $ProxyAuthentication,
        # Specifies the credentials to use to authenticate the user at the proxy
        [Parameter(Mandatory = $false, Position = 6)]
        [pscredential] $ProxyCredential,
        # Returns an object representing transfered item.
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )
    [hashtable] $paramStartBitsTransfer = $PSBoundParameters
    foreach ($Parameter in $PSBoundParameters.Keys) {
        if ($Parameter -notin 'ProxyUsage', 'ProxyList', 'ProxyAuthentication', 'ProxyCredential') {
            $paramStartBitsTransfer.Remove($Parameter)
        }
    }

    if (!$Destination) { $Destination = (Get-Location).ProviderPath }
    if (![System.IO.Path]::HasExtension($Destination)) { $Destination = Join-Path $Destination (Split-Path $Source -Leaf) }
    if (Test-Path $Destination) { Write-Verbose ('The Source [{0}] was not transfered to Destination [{0}] because it already exists.' -f $Source, $Destination) }
    else {
        Write-Verbose ('Downloading Source [{0}] to Destination [{1}]' -f $Source, $Destination);
        Start-BitsTransfer $Source $Destination @paramStartBitsTransfer
    }
    if ($PassThru) { return Get-Item $Destination }
}

function Use-StartProcess {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        # Specifies the path (optional) and file name of the program that runs in the process.
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $FilePath,
        # Specifies parameters or parameter values to use when starting the process.
        [Parameter(Mandatory = $false)]
        [string[]] $ArgumentList,
        # Specifies the working directory for the process.
        [Parameter(Mandatory = $false)]
        [string] $WorkingDirectory,
        # Specifies a user account that has permission to perform this action.
        [Parameter(Mandatory = $false)]
        [pscredential] $Credential,
        # Regex pattern in cmdline to replace with '**********'
        [Parameter(Mandatory = $false)]
        [string[]] $SensitiveDataFilters
    )
    [hashtable] $paramStartProcess = $PSBoundParameters
    foreach ($Parameter in $PSBoundParameters.Keys) {
        if ($Parameter -in 'SensitiveDataFilters') {
            $paramStartProcess.Remove($Parameter)
        }
    }
    [string] $cmd = '"{0}" {1}' -f $FilePath, ($ArgumentList -join ' ')
    foreach ($Filter in $SensitiveDataFilters) {
        $cmd = $cmd -replace $Filter, '**********'
    }
    if ($PSCmdlet.ShouldProcess([System.Environment]::MachineName, $cmd)) {
        [System.Diagnostics.Process] $process = Start-Process -PassThru -Wait -NoNewWindow @paramStartProcess
        if ($process.ExitCode -ne 0) { Write-Error -Category FromStdErr -CategoryTargetName (Split-Path $FilePath -Leaf) -CategoryTargetType "Process" -TargetObject $cmd -CategoryReason "Exit Code not equal to 0" -Message ('Process [{0}] with Id [{1}] terminated with Exit Code [{2}]' -f $FilePath, $process.Id, $process.ExitCode) }
    }
}

<#
.SYNOPSIS
    Convert Byte Array or Plain Text String to Base64 String.
.DESCRIPTION

.EXAMPLE
    PS C:\>ConvertTo-Base64String "A string with base64 encoding"
    Convert String with Default Encoding to Base64 String.
.EXAMPLE
    PS C:\>"ASCII string with base64url encoding" | ConvertTo-Base64String -Base64Url -Encoding Ascii
    Convert String with Ascii Encoding to Base64Url String.
.EXAMPLE
    PS C:\>ConvertTo-Base64String ([guid]::NewGuid())
    Convert GUID to Base64 String.
.INPUTS
    System.Object
#>
function ConvertTo-Base64String {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObject,
        # Use base64url variant
        [Parameter (Mandatory = $false)]
        [switch] $Base64Url,
        # Output encoding to use for text strings
        [Parameter (Mandatory = $false)]
        [ValidateSet("Ascii", "UTF32", "UTF7", "UTF8", "BigEndianUnicode", "Unicode")]
        [string] $Encoding = "Default"
    )

    process {
        [byte[]] $inputBytes = $null
        if ($InputObject -is [byte[]] -or $InputObject -is [byte]) {
            $inputBytes = $InputObject
        }
        elseif ($InputObject -is [string]) {
            $inputBytes = [Text.Encoding]::$Encoding.GetBytes($InputObject)
        }
        elseif ($InputObject -is [bool] -or $InputObject -is [char] -or $InputObject -is [single] -or $InputObject -is [double] -or $InputObject -is [int16] -or $InputObject -is [int32] -or $InputObject -is [int64] -or $InputObject -is [uint16] -or $InputObject -is [uint32] -or $InputObject -is [uint64]) {
            $inputBytes = [System.BitConverter]::GetBytes($InputObject)
        }
        elseif ($InputObject -is [guid]) {
            $inputBytes = $InputObject.ToByteArray()
        }
        elseif ($InputObject -is [System.IO.FileSystemInfo]) {
            $inputBytes = Get-Content $InputObject.FullName -Raw -Encoding Byte
        }
        else {
            # Otherwise, write a non-terminating error message indicating that input object type is not supported.
            $errorMessage = "Cannot convert input of type {0} to Base64 string." -f $InputObject.GetType()
            Write-Error -Message $errorMessage -Category ([System.Management.Automation.ErrorCategory]::ParserError) -ErrorId "ConvertBase64StringFailureTypeNotSupported"
        }

        if ($inputBytes) {
            [string] $outBase64String = [System.Convert]::ToBase64String($inputBytes)
            if ($Base64Url) { $outBase64String = $outBase64String.Replace('+', '-').Replace('/', '_').Replace('=', '') }
            return $outBase64String
        }
    }
}

<#
.SYNOPSIS
    Convert Base64 String to Byte Array or Plain Text String.
.DESCRIPTION

.EXAMPLE
    PS C:\>ConvertFrom-Base64String "QSBzdHJpbmcgd2l0aCBiYXNlNjQgZW5jb2Rpbmc="
    Convert Base64 String to String with Default Encoding.
.EXAMPLE
    PS C:\>"QVNDSUkgc3RyaW5nIHdpdGggYmFzZTY0dXJsIGVuY29kaW5n" | ConvertFrom-Base64String -Base64Url -Encoding Ascii
    Convert Base64Url String to String with Ascii Encoding.
.EXAMPLE
    PS C:\>[guid](ConvertFrom-Base64String "5oIhNbCaFUGAe8NsiAKfpA==" -RawBytes)
    Convert Base64 String to GUID.
.INPUTS
    System.String
#>
function ConvertFrom-Base64String {
    [CmdletBinding()]
    [OutputType([byte[]], [string])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputObject,
        # Use base64url variant
        [Parameter (Mandatory = $false)]
        [switch] $Base64Url,
        # Output raw byte array
        [Parameter (Mandatory = $false)]
        [switch] $RawBytes,
        # Encoding to use for text strings
        [Parameter (Mandatory = $false)]
        [ValidateSet("Ascii", "UTF32", "UTF7", "UTF8", "BigEndianUnicode", "Unicode")]
        [string] $Encoding = "Default"
    )

    process {
        $listBytes = New-Object object[] $InputObject.Count
        for ($iString = 0; $iString -lt $InputObject.Count; $iString++) {
            [string] $strBase64 = $InputObject[$iString]
            if ($Base64Url) { $strBase64 = $strBase64.Replace('-', '+').Replace('_', '/').PadRight($strBase64.Length + (4 - $strBase64.Length % 4) % 4, '=') }
            [byte[]] $outBytes = [System.Convert]::FromBase64String($strBase64)
            if ($RawBytes) { $listBytes[$iString] = $outBytes }
            else {
                $outString = ([Text.Encoding]::$Encoding.GetString($outBytes))
                Write-Output $outString
            }
        }
        if ($RawBytes) {
            return $listBytes
        }
    }
}

<#
.SYNOPSIS
    Convert PowerShell data types to PowerShell string syntax.
.DESCRIPTION

.EXAMPLE
    PS C:\>ConvertTo-PsString @{ key1='value1'; key2='value2' }
    Convert hashtable to PowerShell string.
.INPUTS
    System.String
#>
function ConvertTo-PsString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        #
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [AllowNull()]
        [object] $InputObjects,
        #
        [Parameter(Mandatory = $false)]
        [switch] $Compact,
        #
        [Parameter(Mandatory = $false, Position = 1)]
        [type[]] $RemoveTypes = ([string], [bool], [int], [long]),
        #
        [Parameter(Mandatory = $false)]
        [switch] $NoEnumerate
    )

    begin {
        if ($Compact) {
            [System.Collections.Generic.Dictionary[string, type]] $TypeAccelerators = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::get
            [System.Collections.Generic.Dictionary[type, string]] $TypeAcceleratorsLookup = New-Object 'System.Collections.Generic.Dictionary[type,string]'
            foreach ($TypeAcceleratorKey in $TypeAccelerators.Keys) {
                if (!$TypeAcceleratorsLookup.ContainsKey($TypeAccelerators[$TypeAcceleratorKey])) {
                    $TypeAcceleratorsLookup.Add($TypeAccelerators[$TypeAcceleratorKey], $TypeAcceleratorKey)
                }
            }
        }

        function Resolve-Type {
            param (
                #
                [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
                [type] $ObjectType,
                #
                [Parameter(Mandatory = $false, Position = 1)]
                [switch] $Compact,
                #
                [Parameter(Mandatory = $false, Position = 1)]
                [type[]] $RemoveTypes
            )

            [string] $OutputString = ''
            if ($ObjectType.IsGenericType) {
                if ($ObjectType.FullName.StartsWith('System.Collections.Generic.Dictionary')) {
                    #$OutputString += '[hashtable]'
                    if ($Compact) {
                        $OutputString += '(Invoke-Command { $D = New-Object ''Collections.Generic.Dictionary['
                    }
                    else {
                        $OutputString += '(Invoke-Command { $D = New-Object ''System.Collections.Generic.Dictionary['
                    }
                    $iInput = 0
                    foreach ($GenericTypeArgument in $ObjectType.GenericTypeArguments) {
                        if ($iInput -gt 0) { $OutputString += ',' }
                        $OutputString += Resolve-Type $GenericTypeArgument -Compact:$Compact -RemoveTypes @()
                        $iInput++
                    }
                    $OutputString += ']'''
                }
                elseif ($InputObject.GetType().FullName -match '^(System.(Collections.Generic.[a-zA-Z]+))`[0-9]\[(?:\[(.+?), .+?, Version=.+?, Culture=.+?, PublicKeyToken=.+?\],?)+?\]$') {
                    if ($Compact) {
                        $OutputString += '[{0}[' -f $Matches[2]
                    }
                    else {
                        $OutputString += '[{0}[' -f $Matches[1]
                    }
                    $iInput = 0
                    foreach ($GenericTypeArgument in $ObjectType.GenericTypeArguments) {
                        if ($iInput -gt 0) { $OutputString += ',' }
                        $OutputString += Resolve-Type $GenericTypeArgument -Compact:$Compact -RemoveTypes @()
                        $iInput++
                    }
                    $OutputString += ']]'
                }
            }
            elseif ($ObjectType -eq [System.Collections.Specialized.OrderedDictionary]) {
                $OutputString += '[ordered]'  # Explicit cast does not work with full name. Only [ordered] works.
            }
            elseif ($Compact) {
                if ($ObjectType -notin $RemoveTypes) {
                    if ($TypeAcceleratorsLookup.ContainsKey($ObjectType)) {
                        $OutputString += '[{0}]' -f $TypeAcceleratorsLookup[$ObjectType]
                    }
                    elseif ($ObjectType.FullName.StartsWith('System.')) {
                        $OutputString += '[{0}]' -f $ObjectType.FullName.Substring(7)
                    }
                    else {
                        $OutputString += '[{0}]' -f $ObjectType.FullName
                    }
                }
            }
            else {
                $OutputString += '[{0}]' -f $ObjectType.FullName
            }
            return $OutputString
        }

        function GetPSString ($InputObject) {
            $OutputString = New-Object System.Text.StringBuilder

            if ($null -eq $InputObject) { [void]$OutputString.Append('$null') }
            else {
                ## Add Casting
                [void]$OutputString.Append((Resolve-Type $InputObject.GetType() -Compact:$Compact -RemoveTypes $RemoveTypes))

                ## Add Value
                switch ($InputObject.GetType()) {
                    { $_.Equals([String]) } {
                        [void]$OutputString.AppendFormat("'{0}'", $InputObject.Replace("'", "''")) #.Replace('"','`"')
                        break
                    }
                    { $_.Equals([Char]) } {
                        [void]$OutputString.AppendFormat("'{0}'", ([string]$InputObject).Replace("'", "''"))
                        break
                    }
                    { $_.Equals([Boolean]) -or $_.Equals([switch]) } {
                        [void]$OutputString.AppendFormat('${0}', $InputObject)
                        break
                    }
                    { $_.Equals([DateTime]) } {
                        [void]$OutputString.AppendFormat("'{0}'", $InputObject.ToString('O'))
                        break
                    }
                    { $_.BaseType.Equals([Enum]) } {
                        [void]$OutputString.AppendFormat('::{0}', $InputObject)
                        break
                    }
                    { $_.BaseType.Equals([ValueType]) } {
                        [void]$OutputString.AppendFormat('{0}', $InputObject)
                        break
                    }
                    { $_.Equals([System.Xml.XmlDocument]) } {
                        [void]$OutputString.AppendFormat("'{0}'", $InputObject.OuterXml.Replace("'", "''")) #.Replace('"','""')
                        break
                    }
                    { $_.Equals([Hashtable]) -or $_.Equals([System.Collections.Specialized.OrderedDictionary]) } {
                        [void]$OutputString.Append('@{')
                        $iInput = 0
                        foreach ($enumHashtable in $InputObject.GetEnumerator()) {
                            if ($iInput -gt 0) { [void]$OutputString.Append(';') }
                            [void]$OutputString.AppendFormat('{0}={1}', (ConvertTo-PsString $enumHashtable.Key -Compact:$Compact -NoEnumerate), (ConvertTo-PsString $enumHashtable.Value -Compact:$Compact -NoEnumerate))
                            $iInput++
                        }
                        [void]$OutputString.Append('}')
                        break
                    }
                    { $_.FullName.StartsWith('System.Collections.Generic.Dictionary') } {
                        $iInput = 0
                        foreach ($enumHashtable in $InputObject.GetEnumerator()) {
                            [void]$OutputString.AppendFormat('; $D.Add({0},{1})', (ConvertTo-PsString $enumHashtable.Key -Compact:$Compact -NoEnumerate), (ConvertTo-PsString $enumHashtable.Value -Compact:$Compact -NoEnumerate))
                            $iInput++
                        }
                        [void]$OutputString.Append('; $D })')
                        break
                    }
                    { $_.BaseType.Equals([Array]) } {
                        [void]$OutputString.Append('(Write-Output @(')
                        $iInput = 0
                        for ($iInput = 0; $iInput -lt $InputObject.Count; $iInput++) {
                            if ($iInput -gt 0) { [void]$OutputString.Append(',') }
                            [void]$OutputString.Append((ConvertTo-PsString $InputObject[$iInput] -Compact:$Compact -RemoveTypes $InputObject.GetType().DeclaredMembers.Where( { $_.Name -eq 'Set' })[0].GetParameters()[1].ParameterType -NoEnumerate))
                        }
                        [void]$OutputString.Append(') -NoEnumerate)')
                        break
                    }
                    { $_.Equals([System.Collections.ArrayList]) } {
                        [void]$OutputString.Append('@(')
                        $iInput = 0
                        for ($iInput = 0; $iInput -lt $InputObject.Count; $iInput++) {
                            if ($iInput -gt 0) { [void]$OutputString.Append(',') }
                            [void]$OutputString.Append((ConvertTo-PsString $InputObject[$iInput] -Compact:$Compact -NoEnumerate))
                        }
                        [void]$OutputString.Append(')')
                        break
                    }
                    { $_.FullName.StartsWith('System.Collections.Generic.List') } {
                        [void]$OutputString.Append('@(')
                        $iInput = 0
                        for ($iInput = 0; $iInput -lt $InputObject.Count; $iInput++) {
                            if ($iInput -gt 0) { [void]$OutputString.Append(',') }
                            [void]$OutputString.Append((ConvertTo-PsString $InputObject[$iInput] -Compact:$Compact -RemoveTypes $_.GenericTypeArguments -NoEnumerate))
                        }
                        [void]$OutputString.Append(')')
                        break
                    }
                    ## Convert objects with object initializers
                    { $_ -is [object] -and ($_.GetConstructors() | ForEach-Object { if ($_.IsPublic -and !$_.GetParameters()) { $true } }) } {
                        [void]$OutputString.Append('@{')
                        $iInput = 0
                        foreach ($Item in ($InputObject | Get-Member -MemberType Property, NoteProperty)) {
                            if ($iInput -gt 0) { [void]$OutputString.Append(';') }
                            $PropertyName = $Item.Name
                            [void]$OutputString.AppendFormat('{0}={1}', (ConvertTo-PsString $PropertyName -Compact:$Compact -NoEnumerate), (ConvertTo-PsString $InputObject.$PropertyName -Compact:$Compact -NoEnumerate))
                            $iInput++
                        }
                        [void]$OutputString.Append('}')
                        break
                    }
                    Default {
                        $Exception = New-Object ArgumentException -ArgumentList ('Cannot convert input of type {0} to PowerShell string.' -f $InputObject.GetType())
                        Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::ParserError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConvertPowerShellStringFailureTypeNotSupported' -TargetObject $InputObject
                    }
                }
            }

            if ($NoEnumerate) {
                $listOutputString.Add($OutputString.ToString())
            }
            else {
                Write-Output $OutputString.ToString()
            }
        }

        if ($NoEnumerate) {
            $listOutputString = New-Object System.Collections.Generic.List[string]
        }
    }

    process {
        if ($PSCmdlet.MyInvocation.ExpectingInput -or $NoEnumerate -or $null -eq $InputObjects) {
            GetPSString $InputObjects
        }
        else {
            foreach ($InputObject in $InputObjects) {
                GetPSString $InputObject
            }
        }
    }

    end {
        if ($NoEnumerate) {
            if (($null -eq $InputObjects -and $listOutputString.Count -eq 0) -or $listOutputString.Count -gt 1) {
                Write-Warning ('To avoid losing strong type on outermost enumerable type when piping, use "Write-Output $Array -NoEnumerate | {0}".' -f $MyInvocation.MyCommand)
                $OutputArray = New-Object System.Text.StringBuilder
                [void]$OutputArray.Append('(Write-Output @(')
                if ($PSVersionTable.PSVersion -ge [version]'6.0') {
                    [void]$OutputArray.AppendJoin(',', $listOutputString)
                }
                else {
                    [void]$OutputArray.Append(($listOutputString -join ','))
                }
                [void]$OutputArray.Append(') -NoEnumerate)')
                Write-Output $OutputArray.ToString()
            }
            else {
                Write-Output $listOutputString[0]
            }

        }
    }
}

<#
.SYNOPSIS
    Filters a hashtable or PSBoundParameters containing PowerShell command parameters to only those valid for specified command.
.EXAMPLE
    PS C:\>Select-PsBoundParameters @{Name='Valid'; Verbose=$true; NotAParameter='Remove'} -CommandName Get-Process -ExcludeParameters 'Verbose'
    Filters the parameter hashtable to only include valid parameters for the Get-Process command and exclude the Verbose parameter.
.EXAMPLE
    PS C:\>Select-PsBoundParameters @{Name='Valid'; Verbose=$true; NotAParameter='Remove'} -CommandName Get-Process -CommandParameterSets NameWithUserName
    Filters the parameter hashtable to only include valid parameters for the Get-Process command in the "NameWithUserName" ParameterSet.
.INPUTS
    System.String
#>
function Select-PsBoundParameters {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        # Specifies the parameter key pairs to be filtered.
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [hashtable] $NamedParameters,

        # Specifies the parameter names to remove from the output.
        [Parameter(Mandatory = $false)]
        [ArgumentCompleter( {
                param ( $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters )
                if ($fakeBoundParameters.ContainsKey('NamedParameters')) {
                    [string[]]$fakeBoundParameters.NamedParameters.Keys | Where-Object { $_ -Like "$wordToComplete*" }
                }
            })]
        [string[]] $ExcludeParameters,

        # Specifies the name of a PowerShell command to further filter valid parameters.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter( {
                param ( $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters )
                [array] $CommandInfo = Get-Command "$wordToComplete*"
                if ($CommandInfo) {
                    $CommandInfo.Name #| ForEach-Object {$_}
                }
            })]
        [Alias('Name')]
        [string] $CommandName,

        # Specifies parameter sets of the PowerShell command to further filter valid parameters.
        [Parameter(Mandatory = $false)]
        [ArgumentCompleter( {
                param ( $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters )
                if ($fakeBoundParameters.ContainsKey('CommandName')) {
                    [array] $CommandInfo = Get-Command $fakeBoundParameters.CommandName
                    if ($CommandInfo) {
                        $CommandInfo[0].ParameterSets.Name | Where-Object { $_ -Like "$wordToComplete*" }
                    }
                }
            })]
        [string[]] $CommandParameterSets
    )

    process {
        [hashtable] $SelectedParameters = $NamedParameters.Clone()

        [string[]] $CommandParameters = $null
        if ($CommandName) {
            $CommandInfo = Get-Command $CommandName
            if ($CommandParameterSets) {
                [System.Collections.Generic.List[string]] $listCommandParameters = New-Object System.Collections.Generic.List[string]
                foreach ($CommandParameterSet in $CommandParameterSets) {
                    $listCommandParameters.AddRange([string[]]($CommandInfo.ParameterSets | Where-Object Name -EQ $CommandParameterSet | Select-Object -ExpandProperty Parameters | Select-Object -ExpandProperty Name))
                }
                $CommandParameters = $listCommandParameters | Select-Object -Unique
            }
            else {
                $CommandParameters = $CommandInfo.Parameters.Keys
            }
        }

        [string[]] $ParameterKeys = $SelectedParameters.Keys
        foreach ($ParameterKey in $ParameterKeys) {
            if ($ExcludeParameters -contains $ParameterKey -or ($CommandParameters -and $CommandParameters -notcontains $ParameterKey)) {
                $SelectedParameters.Remove($ParameterKey)
            }
        }

        return $SelectedParameters
    }
}

<#
.SYNOPSIS
    Get certificate object for X509 certificate.
.DESCRIPTION
    Get certificate object for X509 certificate.
.EXAMPLE
    PS C:\>[byte[]] $DERCert = @(48,130,4,18,48,130,2,250,160,3,2,1,2,2,15,0,193,0,139,60,60,136,17,209,62,246,99,236,223,64,48,13,6,9,42,134,72,134,247,13,1,1,4,5,0,48,112,49,43,48,41,6,3,85,4,11,19,34,67,111,112,121,114,105,103,104,116,32,40,99,41,32,49,57,57,55,32,77,105,99,114,111,115,111,102,116,32,67,111,114,112,46,49,30,48,28,6,3,85,4,11,19,21,77,105,99,114,111,115,111,102,116,32,67,111,114,112,111,114,97,116,105,111,110,49,33,48,31,6,3,85,4,3,19,24,77,105,99,114,111,115,111,102,116,32,82,111,111,116,32,65,117,116,104,111,114,105,116,121,48,30,23,13,57,55,48,49,49,48,48,55,48,48,48,48,90,23,13,50,48,49,50,51,49,48,55,48,48,48,48,90,48,112,49,43,48,41,6,3,85,4,11,19,34,67,111,112,121,114,105,103,104,116,32,40,99,41,32,49,57,57,55,32,77,105,99,114,111,115,111,102,116,32,67,111,114,112,46,49,30,48,28,6,3,85,4,11,19,21,77,105,99,114,111,115,111,102,116,32,67,111,114,112,111,114,97,116,105,111,110,49,33,48,31,6,3,85,4,3,19,24,77,105,99,114,111,115,111,102,116,32,82,111,111,116,32,65,117,116,104,111,114,105,116,121,48,130,1,34,48,13,6,9,42,134,72,134,247,13,1,1,1,5,0,3,130,1,15,0,48,130,1,10,2,130,1,1,0,169,2,189,193,112,230,59,242,78,27,40,159,151,120,94,48,234,162,169,141,37,95,248,254,149,76,163,183,254,157,162,32,62,124,81,162,155,162,143,96,50,107,209,66,100,121,238,172,118,201,84,218,242,235,156,134,28,143,159,132,102,179,197,107,122,98,35,214,29,60,222,15,1,146,232,150,196,191,45,102,154,154,104,38,153,208,58,44,191,12,181,88,38,193,70,231,10,62,56,150,44,169,40,57,168,236,73,131,66,227,132,15,187,154,108,85,97,172,130,124,161,96,45,119,76,233,153,180,100,59,154,80,28,49,8,36,20,159,169,231,145,43,24,230,61,152,99,20,96,88,5,101,159,29,55,82,135,247,167,239,148,2,198,27,211,191,85,69,179,137,128,191,58,236,84,148,78,174,253,167,122,109,116,78,175,24,204,150,9,40,33,0,87,144,96,105,55,187,75,18,7,60,86,255,91,251,164,102,10,8,166,210,129,86,87,239,182,59,94,22,129,119,4,218,246,190,174,128,149,254,176,205,127,214,167,26,114,92,60,202,188,240,8,163,34,48,179,6,133,201,179,32,119,19,133,223,2,3,1,0,1,163,129,168,48,129,165,48,129,162,6,3,85,29,1,4,129,154,48,129,151,128,16,91,208,112,239,105,114,158,35,81,126,20,178,77,142,255,203,161,114,48,112,49,43,48,41,6,3,85,4,11,19,34,67,111,112,121,114,105,103,104,116,32,40,99,41,32,49,57,57,55,32,77,105,99,114,111,115,111,102,116,32,67,111,114,112,46,49,30,48,28,6,3,85,4,11,19,21,77,105,99,114,111,115,111,102,116,32,67,111,114,112,111,114,97,116,105,111,110,49,33,48,31,6,3,85,4,3,19,24,77,105,99,114,111,115,111,102,116,32,82,111,111,116,32,65,117,116,104,111,114,105,116,121,130,15,0,193,0,139,60,60,136,17,209,62,246,99,236,223,64,48,13,6,9,42,134,72,134,247,13,1,1,4,5,0,3,130,1,1,0,149,232,11,192,141,243,151,24,53,237,184,1,36,216,119,17,243,92,96,50,159,158,11,203,62,5,145,136,143,201,58,230,33,242,240,87,147,44,181,160,71,200,98,239,252,215,204,59,59,90,169,54,84,105,254,36,109,63,201,204,170,222,5,124,221,49,141,61,159,16,112,106,187,254,18,79,24,105,192,252,208,67,227,17,90,32,79,234,98,123,175,170,25,200,43,55,37,45,190,101,161,18,138,37,15,99,163,247,84,28,249,33,201,214,21,243,82,172,110,67,50,7,253,130,23,248,229,103,108,13,81,246,189,241,82,199,189,231,196,48,252,32,49,9,136,29,149,41,26,77,213,29,2,165,241,128,224,3,180,91,244,177,221,200,87,238,101,73,199,82,84,182,180,3,40,18,255,144,214,240,8,143,126,184,151,197,171,55,44,228,122,228,168,119,227,118,160,0,208,106,63,193,210,54,138,224,65,18,168,53,106,27,106,219,53,225,212,28,4,228,168,69,4,200,90,51,56,110,77,28,13,98,183,10,162,140,211,213,84,63,70,205,28,85,166,112,219,18,58,135,147,117,159,167,210,160)
    PS C:\>Get-X509Certificate $DERCert -Verbose
    Get certificate details from binary (DER) encoded X509 certificate.
.EXAMPLE
    PS C:\>[string] $Base64Cert = 'MIIEEjCCAvqgAwIBAgIPAMEAizw8iBHRPvZj7N9AMA0GCSqGSIb3DQEBBAUAMHAxKzApBgNVBAsTIkNvcHlyaWdodCAoYykgMTk5NyBNaWNyb3NvZnQgQ29ycC4xHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFJvb3QgQXV0aG9yaXR5MB4XDTk3MDExMDA3MDAwMFoXDTIwMTIzMTA3MDAwMFowcDErMCkGA1UECxMiQ29weXJpZ2h0IChjKSAxOTk3IE1pY3Jvc29mdCBDb3JwLjEeMBwGA1UECxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgUm9vdCBBdXRob3JpdHkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCpAr3BcOY78k4bKJ+XeF4w6qKpjSVf+P6VTKO3/p2iID58UaKboo9gMmvRQmR57qx2yVTa8uuchhyPn4Rms8VremIj1h083g8BkuiWxL8tZpqaaCaZ0Dosvwy1WCbBRucKPjiWLKkoOajsSYNC44QPu5psVWGsgnyhYC13TOmZtGQ7mlAcMQgkFJ+p55ErGOY9mGMUYFgFZZ8dN1KH96fvlALGG9O/VUWziYC/OuxUlE6u/ad6bXROrxjMlgkoIQBXkGBpN7tLEgc8Vv9b+6RmCgim0oFWV++2O14WgXcE2va+roCV/rDNf9anGnJcPMq88AijIjCzBoXJsyB3E4XfAgMBAAGjgagwgaUwgaIGA1UdAQSBmjCBl4AQW9Bw72lyniNRfhSyTY7/y6FyMHAxKzApBgNVBAsTIkNvcHlyaWdodCAoYykgMTk5NyBNaWNyb3NvZnQgQ29ycC4xHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWljcm9zb2Z0IFJvb3QgQXV0aG9yaXR5gg8AwQCLPDyIEdE+9mPs30AwDQYJKoZIhvcNAQEEBQADggEBAJXoC8CN85cYNe24ASTYdxHzXGAyn54Lyz4FkYiPyTrmIfLwV5MstaBHyGLv/NfMOztaqTZUaf4kbT/JzKreBXzdMY09nxBwarv+Ek8YacD80EPjEVogT+pie6+qGcgrNyUtvmWhEoolD2Oj91Qc+SHJ1hXzUqxuQzIH/YIX+OVnbA1R9r3xUse958Qw/CAxCYgdlSkaTdUdAqXxgOADtFv0sd3IV+5lScdSVLa0AygS/5DW8AiPfriXxas3LOR65Kh343agANBqP8HSNorgQRKoNWobats14dQcBOSoRQTIWjM4bk0cDWK3CqKM09VUP0bNHFWmcNsSOoeTdZ+n0qA='
    PS C:\>$Base64Cert | Get-X509Certificate -Verbose
    Get certificate details from Base64 encoded X509 certificate.
.EXAMPLE
    PS C:\>Get-Item "certificateFile.cer" | Get-X509Certificate
    Get certificate details from .cer file.
.INPUTS
    System.Object
#>
function Get-X509Certificate {
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2], [System.Security.Cryptography.X509Certificates.X509Certificate2Collection])]
    param (
        # X.509 certificate that is binary (DER) encoded or Base64-encoded
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [object] $InputObjects,
        # Only return the end-entity certificate
        [Parameter(Mandatory = $false)]
        [switch] $EndEntityCertificateOnly
    )

    begin {
        ## Create list to capture byte stream from piped input.
        [System.Collections.Generic.List[byte]] $listBytes = New-Object System.Collections.Generic.List[byte]

        function Transform ([byte[]]$InputBytes) {
            $X509CertificateCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
            $X509CertificateCollection.Import($InputBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet)
            Write-Output $X509CertificateCollection -NoEnumerate
        }
    }

    process {
        if ($InputObjects -is [byte[]]) {
            $X509CertificateCollection = Transform $InputObjects
            if ($EndEntityCertificateOnly) { Write-Output $X509CertificateCollection[-1] }
            else { Write-Output $X509CertificateCollection }
        }
        else {
            foreach ($InputObject in $InputObjects) {
                [byte[]] $inputBytes = $null
                if ($InputObject -is [byte]) {
                    ## Populate list with byte stream from piped input.
                    if ($listBytes.Count -eq 0) {
                        Write-Verbose 'Creating byte array from byte stream.'
                        Write-Warning ('For better performance when piping a single byte array, use "Write-Output $byteArray -NoEnumerate | {0}".' -f $MyInvocation.MyCommand)
                    }
                    $listBytes.Add($InputObject)
                }
                elseif ($InputObject -is [byte[]]) {
                    $inputBytes = $InputObject
                }
                elseif ($InputObject -is [SecureString]) {
                    Write-Verbose 'Decrypting SecureString and decoding Base64 string to byte array.'
                    if ($PSVersionTable.PSVersion -ge [version]'7.0') {
                        $inputBytes = [System.Convert]::FromBase64String((ConvertFrom-SecureString $InputObject -AsPlainText))
                    }
                    else {
                        $inputBytes = [System.Convert]::FromBase64String((ConvertFrom-SecureStringAsPlainText $InputObject -Force))
                    }
                }
                elseif ($InputObject -is [string]) {
                    Write-Verbose 'Decoding Base64 string to byte array.'
                    $inputBytes = [System.Convert]::FromBase64String($InputObject)
                }
                elseif ($InputObject -is [System.IO.FileSystemInfo]) {
                    Write-Verbose 'Decoding file content to byte array.'
                    if ($PSVersionTable.PSVersion -ge [version]'6.0') {
                        $inputBytes = Get-Content $InputObject.FullName -Raw -AsByteStream
                    }
                    else {
                        $inputBytes = Get-Content $InputObject.FullName -Raw -Encoding Byte
                    }
                }
                else {
                    # Otherwise, write a terminating error message indicating that input object type is not supported.
                    $errorMessage = 'Cannot convert input of type {0} to X.509 certificate.' -f $InputObject.GetType()
                    Write-Error -Message $errorMessage -Category ([System.Management.Automation.ErrorCategory]::ParserError) -ErrorId 'GetX509CertificateFailureTypeNotSupported' -ErrorAction Stop
                }

                ## Only write output if the input is not a byte stream.
                if ($listBytes.Count -eq 0) {
                    $X509CertificateCollection = Transform $inputBytes
                    if ($EndEntityCertificateOnly) { Write-Output $X509CertificateCollection[-1] }
                    else { Write-Output $X509CertificateCollection }
                }
            }
        }
    }

    end {
        ## Output captured byte stream from piped input.
        if ($listBytes.Count -gt 0) {
            $X509CertificateCollection = Transform $listBytes
            if ($EndEntityCertificateOnly) { Write-Output $X509CertificateCollection[-1] }
            else { Write-Output $X509CertificateCollection }
        }
    }
}
