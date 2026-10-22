# The typed attributes of [MaesterTest] (docs/proposals/maester-3.0-test-attributes.md): the taxonomy registry,
# the reader's rules, the derived Block, the typed selectors, default exclusions by attribute, selection with
# Maester 2.x tags, the attribute fields of a result row and the Taxonomy of a result, and the migration script.
BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../../..").Path
    $script:manifest = (Resolve-Path "$PSScriptRoot/../../../Maester.psd1").Path
    $script:taxonomyFile = Import-PowerShellDataFile -Path (Join-Path $script:repoRoot 'powershell/assets/MaesterTaxonomy.psd1')

    function New-AttributeTestFile {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Folder, [string] $Id, [string] $Attribute = '', [string] $Body = '$true')
        $null = New-Item -ItemType Directory -Path $Folder -Force
        $name = 'Test-' + ($Id -replace '[^A-Za-z0-9]', '')
        $extra = if ($Attribute) { ", $Attribute" } else { '' }
        @"
function $name {
    [MaesterTest(Id = '$Id', Title = 'Title of $Id', Service = 'None'$extra)]
    [CmdletBinding()]
    param()
    $Body
}
"@ | Set-Content (Join-Path $Folder "Test.$Id.ps1")
        "Description of $Id.`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $Folder "Test.$Id.md")
        Join-Path $Folder "Test.$Id.ps1"
    }

    # The errors of a test other than "property X is required": a fixture sets only the attributes its case is
    # about, and which attributes a test shipped with Maester must have is checked on its own.
    function Get-OtherError {
        param([object] $Test)
        @($Test.Errors | Where-Object { $_.Message -notlike "*property '*' is required." })
    }

    # Reads one test with the given attribute text, as a custom test or as a test shipped with Maester.
    function Read-Attribute {
        param([string] $Attribute, [switch] $BuiltIn)
        $folder = Join-Path $TestDrive ('read' + [guid]::NewGuid().ToString('n'))
        if ($BuiltIn -and $Attribute -notmatch '\bSeverity\b') { $Attribute = "Severity = 'High', $Attribute" }
        if ($BuiltIn -and $Attribute -notmatch '\bAuthor\b') { $Attribute = "$Attribute, Author = 'someone'" }
        $file = New-AttributeTestFile -Folder $folder -Id 'READ.1' -Attribute $Attribute
        InModuleScope Maester -Parameters @{ F = $file; B = $BuiltIn.IsPresent } { Read-MtNativeTest -Path $F -BuiltIn:$B }
    }

    # Reads one test shipped with Maester whose attribute text sets Service itself.
    function Read-BuiltInWithService {
        param([string] $Attribute)
        $folder = Join-Path $TestDrive ('read' + [guid]::NewGuid().ToString('n'))
        $file = New-AttributeTestFile -Folder $folder -Id 'READ.1' -Attribute "Severity = 'High', Author = 'someone', $Attribute"
        (Get-Content $file -Raw).Replace("Service = 'None', ", '') | Set-Content $file
        InModuleScope Maester -Parameters @{ F = $file } { Read-MtNativeTest -Path $F -BuiltIn }
    }
}

Describe 'Taxonomy registry' {
    It 'Loads the products in the order of the file, with their features, the areas and the resource types' {
        $taxonomy = InModuleScope Maester { Get-MtTaxonomy }
        @($taxonomy.Products.Key) | Should -Be @($script:taxonomyFile.Products.Key)
        $taxonomy.Products[0].Key | Should -Be 'entra'
        @($taxonomy.Areas.Key) | Should -Contain 'authentication'
        @($taxonomy.ResourceTypes.Key) | Should -Contain 'Tenant'
        $taxonomy.Lookup.Feature['entra'].ContainsKey('conditional-access') | Should -BeTrue
        $taxonomy.Lookup.Feature['exchange'].ContainsKey('conditional-access') | Should -BeFalse
    }

    It 'Returns the same cached table on every call' {
        InModuleScope Maester { [object]::ReferenceEquals((Get-MtTaxonomy), (Get-MtTaxonomy)) } | Should -BeTrue
    }

    It 'Resolves <Name> to the product <Key>' -ForEach @(
        @{ Name = 'entra'; Key = 'entra' }
        @{ Name = 'ENTRA'; Key = 'entra' }
        @{ Name = 'Entra ID'; Key = 'entra' }
        @{ Name = 'entra id'; Key = 'entra' }
        @{ Name = 'EXO'; Key = 'exchange' }
        @{ Name = 'Exchange Online'; Key = 'exchange' }
        @{ Name = 'Active Directory'; Key = 'ad' }
        @{ Name = 'M365'; Key = 'microsoft-365' }
        @{ Name = 'AzDO'; Key = 'azure-devops' }
    ) {
        InModuleScope Maester -Parameters @{ N = $Name } { Resolve-MtProductKey -Name $N } | Should -BeExactly $Key
    }

    It 'Resolves every key and alias of the file to its own product' {
        foreach ($product in $script:taxonomyFile.Products) {
            foreach ($name in @($product.Key) + @($product.Aliases)) {
                InModuleScope Maester -Parameters @{ N = $name } { Resolve-MtProductKey -Name $N } | Should -BeExactly $product.Key -Because $name
            }
        }
    }

    It 'Does not resolve a name the registry does not know' {
        InModuleScope Maester { Resolve-MtProductKey -Name 'Contoso CRM' } | Should -BeNullOrEmpty
        InModuleScope Maester { Get-MtProductName -Product 'Contoso CRM' } | Should -Be 'Contoso CRM'
        InModuleScope Maester { Get-MtProductName -Product 'entra' } | Should -Be 'Entra ID'
    }

    It 'Reads the ATT&CK release the registry pins' {
        $attack = InModuleScope Maester { Get-MtAttackData }
        $attack.Version | Should -Be $script:taxonomyFile.Attack.Version
        $attack.Techniques['T1110'].Name | Should -Be 'Brute Force'
        $attack.Techniques['t1110.003'].Tactics | Should -Contain 'TA0006'
        $attack.Tactics['TA0006'].Name | Should -Be 'Credential Access'
        $attack.Retired.Count | Should -BeGreaterThan 0
    }
}

Describe 'Reader: classification attributes' {
    It 'Stores a product named by the alias <Alias> as the key <Key>' -ForEach @(
        @{ Alias = 'Entra ID'; Key = 'entra' }
        @{ Alias = 'exchange online'; Key = 'exchange' }
        @{ Alias = 'DEFENDER'; Key = 'defender' }
    ) {
        (Read-Attribute "Product = '$Alias'").Product | Should -BeExactly $Key
        $builtIn = Read-Attribute "Product = '$Alias'" -BuiltIn
        Get-OtherError $builtIn | Should -HaveCount 0
        $builtIn.Product | Should -BeExactly $Key
    }

    It 'Stores registry values as their keys, whatever their case' {
        $t = Read-Attribute "Product = 'ENTRA', RelatedProduct = ('EXO', 'Microsoft Teams'), Feature = 'Conditional-Access', Area = 'AUTHENTICATION', ResourceType = 'tenant', Severity = 'high', UserImpact = 'low', ImplementationCost = 'HIGH', Lifecycle = 'deprecated'"
        $t.Errors | Should -HaveCount 0
        $t.Product | Should -BeExactly 'entra'
        $t.RelatedProduct | Should -BeExactly @('exchange', 'teams')
        $t.Feature | Should -BeExactly 'conditional-access'
        $t.Area | Should -BeExactly 'authentication'
        $t.ResourceType | Should -BeExactly 'Tenant'
        $t.Severity | Should -BeExactly 'High'
        $t.UserImpact | Should -BeExactly 'Low'
        $t.ImplementationCost | Should -BeExactly 'High'
        $t.Lifecycle | Should -BeExactly 'Deprecated'
    }

    It 'Gives a test that sets none of them empty values and Lifecycle Stable' {
        $t = Read-Attribute ''
        $t.Errors | Should -HaveCount 0
        $t.Product | Should -BeNullOrEmpty
        $t.Feature | Should -BeNullOrEmpty
        $t.Lifecycle | Should -Be 'Stable'
        foreach ($name in 'RelatedProduct', 'Mitre', 'Control', 'Permission', 'Platform', 'Cloud', 'TenantType', 'Tag') {
            , $t.$name | Should -BeOfType [array] -Because "$name is a list"
            @($t.$name).Count | Should -Be 0 -Because $name
        }
    }

    It 'Rejects <Case> in a test shipped with Maester' -ForEach @(
        @{ Case = 'a product that is not in the registry'; Attribute = "Product = 'Contoso CRM'"; Message = "*Product 'Contoso CRM' is not a product of the taxonomy registry*" }
        @{ Case = 'a related product that is not in the registry'; Attribute = "Product = 'entra', RelatedProduct = 'Contoso CRM'"; Message = "*RelatedProduct 'Contoso CRM' is not a product*" }
        @{ Case = 'a feature of another product'; Attribute = "Product = 'entra', Feature = 'mail-flow'"; Message = "*Feature 'mail-flow' is not a feature of the product 'entra'*" }
        @{ Case = 'a feature that is not in the registry'; Attribute = "Product = 'entra', Feature = 'Free text'"; Message = "*Feature 'Free text' is not a feature of the product 'entra'*" }
        @{ Case = 'an area that is not in the registry'; Attribute = "Product = 'entra', Area = 'finance'"; Message = "*Area 'finance' is not an area*" }
        @{ Case = 'a resource type that is not in the registry'; Attribute = "Product = 'entra', ResourceType = 'Invoice'"; Message = "*ResourceType 'Invoice' is not a resource type*" }
    ) {
        $t = Read-Attribute $Attribute -BuiltIn
        $t.Errors.Code | Should -Contain 'InvalidMetadata'
        ($t.Errors.Message -join "`n") | Should -BeLike $Message
    }

    It 'Accepts a feature that belongs to the product of a test shipped with Maester' {
        Get-OtherError (Read-Attribute "Product = 'exchange', Feature = 'mail-flow', Area = 'email-protection', ResourceType = 'Policy'" -BuiltIn) | Should -HaveCount 0
    }

    It 'Keeps the free values of a custom test as written' {
        $t = Read-Attribute "Product = 'Contoso CRM', RelatedProduct = ('Contoso ERP', 'entra id'), Feature = 'Billing rules', Area = 'Finance', ResourceType = 'Invoice'"
        $t.Errors | Should -HaveCount 0
        $t.Product | Should -BeExactly 'Contoso CRM'
        $t.RelatedProduct | Should -BeExactly @('Contoso ERP', 'entra')
        $t.Feature | Should -BeExactly 'Billing rules'
        $t.Area | Should -BeExactly 'Finance'
        $t.ResourceType | Should -BeExactly 'Invoice'
    }

    It 'Keeps a custom test''s Feature as written when it is not a feature of its product' {
        # mail-flow is a feature of exchange, not of entra; a custom test may still say so.
        $t = Read-Attribute "Product = 'entra', Feature = 'Mail-Flow'"
        $t.Errors | Should -HaveCount 0
        $t.Feature | Should -BeExactly 'Mail-Flow'
    }

    It 'Rejects <Case>' -ForEach @(
        @{ Case = 'a related product that repeats the product'; Attribute = "Product = 'entra', RelatedProduct = 'Entra ID'"; Message = '*RelatedProduct must not repeat Product*' }
        @{ Case = 'a product longer than 40 characters'; Attribute = "Product = '$('p' * 41)'"; Message = "*'Product' value is longer than 40*" }
        @{ Case = 'a feature longer than 60 characters'; Attribute = "Feature = '$('f' * 61)'"; Message = "*'Feature' value is longer than 60*" }
        @{ Case = 'an area longer than 60 characters'; Attribute = "Area = '$('a' * 61)'"; Message = "*'Area' value is longer than 60*" }
        @{ Case = 'a resource type that is not one word'; Attribute = "ResourceType = 'Access package'"; Message = "*'ResourceType' value 'Access package' is not valid*" }
        @{ Case = 'a user impact outside the list'; Attribute = "UserImpact = 'Huge'"; Message = "*'UserImpact' value 'Huge' is not one of Low, Medium, High*" }
        @{ Case = 'an implementation cost outside the list'; Attribute = "ImplementationCost = 'Free'"; Message = "*'ImplementationCost' value 'Free' is not one of Low, Medium, High*" }
        @{ Case = 'a lifecycle outside the list'; Attribute = "Lifecycle = 'Beta'"; Message = "*'Lifecycle' value 'Beta' is not one of Preview, Stable, Deprecated*" }
        @{ Case = 'a ReplacedBy that is not a test ID'; Attribute = "ReplacedBy = 'the new one'"; Message = "*'ReplacedBy' value 'the new one' is not valid*" }
    ) {
        $t = Read-Attribute $Attribute
        $t.Errors.Code | Should -Contain 'InvalidMetadata'
        ($t.Errors.Message -join "`n") | Should -BeLike $Message
    }

    It 'Lists a related product once' {
        (Read-Attribute "Product = 'entra', RelatedProduct = ('exchange', 'EXO', 'Exchange Online')").RelatedProduct | Should -Be @('exchange')
    }
}

Describe 'Reader: removed properties' {
    It 'Rejects Category with the replacement in the message' {
        $t = Read-Attribute "Category = 'Maester/Entra'"
        $t.Errors | Should -HaveCount 1
        $t.Errors[0].Code | Should -Be 'InvalidMetadata'
        $t.Errors[0].Message | Should -BeExactly '`Category` was removed in Maester 3.0. Use `Product` and `Feature`; the result''s `Block` is derived from them.'
    }

    It 'Rejects Preview written as <Text> with the replacement in the message' -ForEach @(
        @{ Text = 'Preview' }
        @{ Text = 'Preview = $true' }
        @{ Text = 'preview = $false' }
    ) {
        $t = Read-Attribute $Text
        $t.Errors | Should -HaveCount 1
        $t.Errors[0].Code | Should -Be 'InvalidMetadata'
        $t.Errors[0].Message | Should -BeExactly '`Preview` was removed in Maester 3.0. Use `Lifecycle = ''Preview''`.'
    }

    It 'No longer reserves GraphScope and Deprecated, and still rejects them as unknown' {
        foreach ($name in 'GraphScope', 'Deprecated') {
            $t = Read-Attribute "$name = 'x'"
            ($t.Errors.Message -join "`n") | Should -BeLike "*Unknown ``[MaesterTest``] property '$name'*"
            ($t.Errors.Message -join "`n") | Should -Not -BeLike '*reserved*'
        }
        ((Read-Attribute "TimeoutSeconds = 'x'").Errors.Message -join "`n") | Should -BeLike '*reserved for a later Maester version*'
    }

    It 'Fails a run with the message instead of running the test' {
        $folder = Join-Path $TestDrive 'removed'
        $file = New-AttributeTestFile -Folder $folder -Id 'OLD.1' -Attribute "Category = 'Old', Preview"
        $row = Invoke-MtTest -Path $file
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'InvalidMetadata'
        $row.ReasonDetail | Should -Match ([regex]::Escape('`Category` was removed in Maester 3.0. Use `Product` and `Feature`'))
    }
}

Describe 'Reader: Mitre, Control and Permission' {
    It 'Reads technique and sub-technique IDs and writes them in upper case' {
        $t = Read-Attribute "Mitre = ('T1110', 't1078.004', 'T1110')"
        $t.Errors | Should -HaveCount 0
        $t.Mitre | Should -BeExactly @('T1110', 'T1078.004')
    }

    It 'Reads the single value None, whatever its case' {
        $t = Read-Attribute "Mitre = 'none'"
        $t.Errors | Should -HaveCount 0
        $t.Mitre | Should -BeExactly @('None')
    }

    It 'Rejects None together with a technique ID' {
        $t = Read-Attribute "Mitre = ('None', 'T1110')"
        ($t.Errors.Message -join "`n") | Should -BeLike "*'Mitre' is either a list of technique IDs or the single value 'None'*"
    }

    It 'Rejects <Value> as a Mitre value' -ForEach @(
        @{ Value = 'TA0006' }, @{ Value = 'T123' }, @{ Value = 'T1110.3' }, @{ Value = 'T1110.0031' }, @{ Value = 'Brute Force' }, @{ Value = 'M1032' }
    ) {
        (Read-Attribute "Mitre = '$Value'").Errors.Code | Should -Contain 'InvalidMetadata'
    }

    It 'Does not check a technique against the ATT&CK release at run time' {
        # T9999 has the right form. The build and the unit tests reject it for a built-in test.
        (Read-Attribute "Mitre = 'T9999'").Errors | Should -HaveCount 0
        Get-OtherError (Read-Attribute "Product = 'entra', Mitre = 'T9999'" -BuiltIn) | Should -HaveCount 0
    }

    It 'Reports a retired or unknown technique for the build' {
        $retired = (Get-Content (Join-Path $script:repoRoot 'powershell/assets/MaesterAttackTechniques.json') -Raw | ConvertFrom-Json).Retired[0]
        $problems = @(InModuleScope Maester -Parameters @{ M = @('T1110', $retired, 'T9999', 'None') } { Get-MtAttackTechniqueProblem -Mitre $M })
        $problems | Should -HaveCount 2
        $problems[0] | Should -BeLike "*$retired was retired in ATT&CK*"
        $problems[1] | Should -BeLike '*T9999 is not in ATT&CK*'
        @(InModuleScope Maester { Get-MtAttackTechniqueProblem -Mitre @('T1110.003', 'None') }) | Should -HaveCount 0
        @(InModuleScope Maester { Get-MtAttackTechniqueProblem -Mitre @() }) | Should -HaveCount 0
    }

    It 'Reads Control as framework-key:control-id with a lowercase framework key' {
        $t = Read-Attribute "Control = ('nist-800-53-r5:IA-2(1)', 'ISO-27001:A.5.15', 'cis-m365:5.2.2.3')"
        $t.Errors | Should -HaveCount 0
        $t.Control | Should -BeExactly @('nist-800-53-r5:IA-2(1)', 'iso-27001:A.5.15', 'cis-m365:5.2.2.3')
    }

    It 'Rejects <Value> as a Control value' -ForEach @(
        @{ Value = 'IA-2' }, @{ Value = 'nist: IA-2' }, @{ Value = 'nist:IA-2,IA-3' }, @{ Value = ':IA-2' }, @{ Value = 'nist 800:IA-2' }
    ) {
        (Read-Attribute "Control = '$Value'").Errors.Code | Should -Contain 'InvalidMetadata'
    }

    It 'Reads Permission as Service:Kind:Name, one permission per element' {
        $t = Read-Attribute "Permission = ('Graph:Scope:Policy.Read.All', 'ExchangeOnline:Role:View-Only Configuration')"
        $t.Errors | Should -HaveCount 0
        $t.Permission | Should -BeExactly @('Graph:Scope:Policy.Read.All', 'ExchangeOnline:Role:View-Only Configuration')
    }

    It 'Keeps the colons of a permission name: <Value>' -ForEach @(
        @{ Value = 'GitHub:Permission:administration:read' }
        @{ Value = 'ActiveDirectory:Cim:root\MicrosoftDNS:MicrosoftDNS_Zone:Read' }
        @{ Value = 'CNT.GoogleWorkspace:Scope:https://www.googleapis.com/auth/admin.directory.user.readonly' }
    ) {
        $t = Read-Attribute "Permission = '$Value'"
        $t.Errors | Should -HaveCount 0
        $t.Permission | Should -BeExactly @($Value)
    }

    It 'Reads alternatives joined with | and writes them with one space around each |' {
        $t = Read-Attribute "Permission = ('Graph:Scope:Policy.Read.All|Graph:Scope:Directory.Read.All', 'Graph:Scope:AuditLog.Read.All')"
        $t.Errors | Should -HaveCount 0
        $t.Permission | Should -BeExactly @('Graph:Scope:Policy.Read.All | Graph:Scope:Directory.Read.All', 'Graph:Scope:AuditLog.Read.All')
    }

    It 'Writes a registered service and kind in their registry spelling' {
        $t = Read-Attribute "Permission = 'exchange:role:View-Only Configuration | AD:ldap:user:ReadProperty'"
        $t.Permission | Should -BeExactly @('ExchangeOnline:Role:View-Only Configuration | ActiveDirectory:Ldap:user:ReadProperty')
    }

    It 'Splits an element into its alternatives' {
        $parts = @(InModuleScope Maester { ConvertFrom-MtPermission 'Graph:Scope:Policy.Read.All | GitHub:Permission:administration:read' })
        $parts | Should -HaveCount 2
        $parts[0].Service | Should -Be 'Graph'
        $parts[0].Kind | Should -Be 'Scope'
        $parts[0].Name | Should -Be 'Policy.Read.All'
        $parts[1].Name | Should -Be 'administration:read'
    }

    It 'Rejects <Case> as a Permission value' -ForEach @(
        @{ Case = 'a name without a service and a kind'; Value = 'Policy.Read.All' }
        @{ Case = 'a name without a kind'; Value = 'Graph:Policy.Read.All' }
        @{ Case = 'two permissions in one element'; Value = 'Graph:Scope:Policy.Read.All, Graph:Scope:User.Read.All' }
        @{ Case = 'an empty alternative'; Value = 'Graph:Scope:Policy.Read.All |' }
        @{ Case = 'an alternative without a service'; Value = 'Graph:Scope:Policy.Read.All | Directory.Read.All' }
        @{ Case = 'a blank'; Value = ' ' }
    ) {
        $t = Read-Attribute "Permission = '$Value'"
        $t.Errors.Code | Should -Contain 'InvalidMetadata'
        ($t.Errors.Message -join "`n") | Should -BeLike '*<Service>:<Kind>:<Name>*'
    }

    It 'Rejects the same alternative twice in an element, and the same element twice' {
        (Read-Attribute "Permission = 'Graph:Scope:Policy.Read.All | Graph:Scope:Policy.Read.All'").Errors.Message | Should -BeLike "*lists 'Graph:Scope:Policy.Read.All' twice*"
        (Read-Attribute "Permission = ('Graph:Scope:Policy.Read.All', 'graph:scope:Policy.Read.All')").Errors.Message | Should -BeLike '*is listed twice*'
    }

    It 'Rejects <Case> in a test shipped with Maester' -ForEach @(
        @{ Case = 'a service that is not in the registry'; Attribute = "Service = 'Graph', Permission = 'Okta:Scope:okta.users.read'"; Message = "*'Okta' is not in the service registry*" }
        @{ Case = 'a kind the registry does not list for the service'; Attribute = "Service = 'Graph', Permission = 'Graph:Cmdlet:Get-MgUser'"; Message = "*'Cmdlet' is not a kind of permission of Graph (Scope, DelegatedScope, ApplicationScope, Role)*" }
        @{ Case = 'a service the test does not list'; Attribute = "Service = 'Graph', Permission = 'Graph:Scope:Policy.Read.All | ExchangeOnline:Role:View-Only Configuration'"; Message = '*ExchangeOnline is not one of the services of the test*' }
    ) {
        $t = Read-BuiltInWithService -Attribute $Attribute
        ($t.Errors.Message -join "`n") | Should -BeLike $Message
    }

    It 'Accepts the permissions of the services a test shipped with Maester lists' {
        $t = Read-BuiltInWithService -Attribute "Service = ('Graph', 'ExchangeOnline'), Permission = ('Graph:Scope:Policy.Read.All', 'ExchangeOnline:Role:View-Only Configuration | Graph:Role:Global Reader')"
        @($t.Errors | Where-Object { $_.Message -like '*Permission*' }) | Should -HaveCount 0
        $t.Permission | Should -BeExactly @('Graph:Scope:Policy.Read.All', 'ExchangeOnline:Role:View-Only Configuration | Graph:Role:Global Reader')
    }

    It 'Keeps a service and a kind the registry does not know in a custom test' {
        $t = Read-Attribute "Permission = ('CNT.Okta:Scope:okta.users.read', 'Graph:Cmdlet:Get-MgUser')"
        $t.Errors | Should -HaveCount 0
        $t.Permission | Should -BeExactly @('CNT.Okta:Scope:okta.users.read', 'Graph:Cmdlet:Get-MgUser')
    }
}

Describe 'Service registry: permission kinds' {
    BeforeDiscovery {
        $registryServices = @((Import-PowerShellDataFile -Path "$PSScriptRoot/../../../assets/MaesterServiceRegistry.psd1").Services.Keys | Sort-Object)
    }
    BeforeAll {
        $script:registryFile = Import-PowerShellDataFile -Path (Join-Path $script:repoRoot 'powershell/assets/MaesterServiceRegistry.psd1')
        $script:permissionPattern = (Import-PowerShellDataFile -Path (Join-Path $script:repoRoot 'powershell/assets/MaesterTestSchema.psd1')).Properties.Permission.Pattern
    }

    It 'Lists the permission kinds of <_>, each with an example that is a valid value and a description' -ForEach $registryServices {
        $kinds = @($script:registryFile.Services[$_].PermissionKinds)
        $kinds.Count | Should -BeGreaterThan 0
        foreach ($k in $kinds) {
            $k.Kind | Should -Match '^[A-Z][A-Za-z]+$'
            $k.Description | Should -Not -BeNullOrEmpty
            "${_}:$($k.Kind):$($k.Example)" | Should -Match $script:permissionPattern -Because "the example of $($k.Kind) must be a valid value"
        }
        @($kinds.Kind | Select-Object -Unique).Count | Should -Be $kinds.Count
    }
}

Describe 'Required attributes' {
    It 'Requires Product, Severity, Service and Author of a test shipped with Maester, and only Id and Title of a custom test' {
        $folder = Join-Path $TestDrive 'required'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "function Test-Req1 {`n    [MaesterTest(Id = 'REQ.1', Title = 'x')]`n    [CmdletBinding()]`n    param()`n    `$true`n}" | Set-Content (Join-Path $folder 'Test.REQ.1.ps1')
        'd' | Set-Content (Join-Path $folder 'Test.REQ.1.md')
        $file = Join-Path $folder 'Test.REQ.1.ps1'
        (InModuleScope Maester -Parameters @{ F = $file } { Read-MtNativeTest -Path $F }).Errors | Should -HaveCount 0
        $messages = (InModuleScope Maester -Parameters @{ F = $file } { Read-MtNativeTest -Path $F -BuiltIn }).Errors.Message
        foreach ($name in 'Product', 'Severity', 'Service', 'Author') { $messages | Should -Contain "[MaesterTest] property '$name' is required." }
    }

    It 'Waives UserImpact and ImplementationCost for an Info test once they are required' {
        # The two are Required = 'No' until every built-in test has its values. This proves the rule that
        # applies when the schema table marks them BuiltIn: required unless Severity is Info.
        $file = New-AttributeTestFile -Folder (Join-Path $TestDrive 'waiver') -Id 'WAIVE.1' -Attribute "Product = 'entra', Severity = 'High', Author = 'someone'"
        $info = New-AttributeTestFile -Folder (Join-Path $TestDrive 'waiver') -Id 'WAIVE.2' -Attribute "Product = 'entra', Severity = 'Info', Author = 'someone'"
        $result = InModuleScope Maester -Parameters @{ High = $file; Info = $info } {
            $saved = $script:__MtTestSchema
            try {
                $schema = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterTestSchema.psd1')
                foreach ($name in 'UserImpact', 'ImplementationCost') { $schema.Properties[$name].Required = 'BuiltIn' }
                $script:__MtTestSchema = $schema
                [pscustomobject]@{
                    High   = (Read-MtNativeTest -Path $High -BuiltIn).Errors.Message
                    Info   = (Read-MtNativeTest -Path $Info -BuiltIn).Errors.Message
                    Custom = (Read-MtNativeTest -Path $High).Errors.Message
                }
            } finally { $script:__MtTestSchema = $saved }
        }
        $result.High | Should -Contain "[MaesterTest] property 'UserImpact' is required."
        $result.High | Should -Contain "[MaesterTest] property 'ImplementationCost' is required."
        @($result.Info | Where-Object { $_ -like "*'UserImpact'*" -or $_ -like "*'ImplementationCost'*" }) | Should -HaveCount 0
        $result.Custom | Should -BeNullOrEmpty
    }
}

Describe 'Block' {
    BeforeAll {
        function Get-Block {
            param([string] $Attribute, [hashtable] $Suite)
            $folder = Join-Path $TestDrive ('block' + [guid]::NewGuid().ToString('n'))
            $null = New-AttributeTestFile -Folder $folder -Id 'BLOCK.1' -Attribute $Attribute
            if ($Suite) { $Suite | ConvertTo-Json | Set-Content (Join-Path $folder 'suite.json') }
            (Get-MtTest -Path $folder).Block
        }
    }

    It 'Is the display name of the product when the registry knows it' {
        Get-Block "Product = 'entra', Feature = 'conditional-access'" | Should -Be 'Entra ID'
        Get-Block "Product = 'EXO'" -Suite @{ Id = 'CONTOSO'; Name = 'Contoso checks' } | Should -Be 'Exchange Online'
    }

    It 'Is the product as written when the registry does not know it' {
        Get-Block "Product = 'Contoso CRM', Feature = 'Billing'" | Should -Be 'Contoso CRM'
    }

    It 'Is the feature when the test has no product' {
        Get-Block "Feature = 'Billing'" -Suite @{ Id = 'CONTOSO'; Name = 'Contoso checks' } | Should -Be 'Billing'
    }

    It 'Is the name of the suite when the test has neither' {
        Get-Block '' -Suite @{ Id = 'CONTOSO'; Name = 'Contoso checks' } | Should -Be 'Contoso checks'
    }

    It 'Is Custom when there is nothing else' {
        Get-Block '' | Should -Be 'Custom'
        Get-Block '' -Suite @{ Id = 'CONTOSO' } | Should -Be 'Custom'
    }

    It 'Is the name of the product for every test shipped with Maester' {
        $names = @{}
        foreach ($product in $script:taxonomyFile.Products) { $names[$product.Key] = $product.Name }
        $offenders = @(Get-MtTest | Where-Object { $_.Block -cne $names[$_.Product] } | ForEach-Object { "$($_.Id): '$($_.Block)'" })
        $offenders | Should -BeNullOrEmpty
    }

    It 'Stays the Describe name for a test converted from the Pester format, on the test and on its row' {
        $folder = Join-Path $TestDrive 'converted'
        $null = New-Item -ItemType Directory -Path $folder -Force
        @'
Describe "Contoso baseline" -Tag "Contoso", "Preview" {
    It "CONTOSO.2001: Something holds" {
        $true | Should -Be $true
    }
}
'@ | Set-Content (Join-Path $folder 'Contoso.Tests.ps1')
        $report = @(Convert-MtTest -Path $folder -Confirm:$false 3>$null)
        $report[0].Output | Should -Exist
        $code = Get-Content $report[0].Output -Raw
        $code | Should -Match "Feature = 'Contoso baseline'"
        $code | Should -Match "Lifecycle = 'Preview'"
        $code | Should -Not -Match '(?m)^\s*(Category|Preview) = '
        $test = Get-MtTest -Path $report[0].Output
        $test.IsValid | Should -BeTrue
        $test.Block | Should -Be 'Contoso baseline'
        $test.Lifecycle | Should -Be 'Preview'
        (Invoke-MtTest -Path $report[0].Output).Block | Should -Be 'Contoso baseline'
    }

    It 'Is not written by Convert-MtTest when the Describe name does not fit Feature, and the report says so' {
        $folder = Join-Path $TestDrive 'converted-long'
        $null = New-Item -ItemType Directory -Path $folder -Force
        "Describe '$('D' * 61)' { It 'CONTOSO.2002: Something holds' { `$true | Should -Be `$true } }" | Set-Content (Join-Path $folder 'Long.Tests.ps1')
        $report = @(Convert-MtTest -Path $folder -Confirm:$false 3>$null)
        $report[0].Notes | Should -BeLike '*was not written to Feature*'
        (Get-MtTest -Path $report[0].Output).IsValid | Should -BeTrue
        (Get-MtTest -Path $report[0].Output).Block | Should -Be 'Custom'
    }
}

Describe 'Typed selectors and default exclusions' {
    BeforeAll {
        $script:selectFolder = Join-Path $TestDrive 'select'
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.1' -Attribute "Product = 'entra', Feature = 'conditional-access', Area = 'authentication', ResourceType = 'Tenant', Severity = 'High', UserImpact = 'Medium', ImplementationCost = 'Low', Mitre = ('T1110', 'T1078.004'), Control = 'nist-800-53-r5:IA-2', Permission = 'Graph:Scope:Policy.Read.All', Tag = 'baseline'"
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.2' -Attribute "Product = 'exchange', RelatedProduct = 'entra', Feature = 'mail-flow', Area = 'email-protection', Severity = 'Low'"
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.3' -Attribute "Product = 'Contoso CRM', Feature = 'Billing', Severity = 'Medium', Tag = 'finance'"
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.4' -Attribute "Severity = 'High', Lifecycle = 'Preview', Tag = 'finance'"
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.5' -Attribute "Product = 'entra', Severity = 'Info', LongRunning"
        $null = New-AttributeTestFile -Folder $script:selectFolder -Id 'SEL.6' -Attribute "Severity = 'Low', Tag = ('Preview', 'LongRunning'), Lifecycle = 'Deprecated', ReplacedBy = 'SEL.1'"
        @{ Id = 'CONTOSO'; Name = 'Contoso checks'; Source = 'Custom'; Tags = @('contoso-suite') } | ConvertTo-Json | Set-Content (Join-Path $script:selectFolder 'suite.json')

        # Resolves the plan for the tests above the way Invoke-Maester does, and returns the plan rows.
        function Get-Plan {
            param([hashtable] $Parameters = @{}, [hashtable] $Config = @{}, [string[]] $AutoExcluded = @(), [object] $TenantContext, [object[]] $Test)
            InModuleScope Maester -Parameters @{ P = $Parameters; C = $Config; A = $AutoExcluded; F = $script:selectFolder; T = $TenantContext; Tests = $Test } {
                $tests = if ($Tests) { $Tests } else { @(Get-MtNativeTestInventory -Path $F -Root $F) }
                $runConfig = Resolve-MtRunConfig -Config $C
                $selection = Resolve-MtSelection -RunConfig $runConfig @P
                Resolve-MtNativePlan -Test $tests -Selection $selection -RunConfig $runConfig -TenantContext $T `
                    -IncludeTag @($selection.Tag | Where-Object { $_ }) -ExcludeTag (@($selection.ExcludeTag) + @($A) | Where-Object { $_ }) -AutoExcludedTag $A
            }
        }
        function Get-Selected {
            param([hashtable] $Parameters = @{}, [hashtable] $Config = @{}, [string[]] $AutoExcluded = @())
            @(Get-Plan -Parameters $Parameters -Config $Config -AutoExcluded $AutoExcluded | Where-Object Disposition -EQ 'Run' | ForEach-Object { $_.Test.Id } | Sort-Object)
        }
    }

    It 'Reads the six fixture tests without errors' {
        @(Get-MtTest -Path $script:selectFolder | Where-Object IsValid).Count | Should -Be 6
    }

    It '-<Name> <Value> selects <Expected>' -ForEach @(
        @{ Name = 'Product'; Value = 'entra'; Expected = 'SEL.1,SEL.2,SEL.5' }
        @{ Name = 'Product'; Value = 'Entra ID'; Expected = 'SEL.1,SEL.2,SEL.5' }
        @{ Name = 'Product'; Value = 'ENT*'; Expected = 'SEL.1,SEL.2,SEL.5' }
        @{ Name = 'Product'; Value = 'exchange'; Expected = 'SEL.2' }
        @{ Name = 'Product'; Value = @('EXO', 'contoso*'); Expected = 'SEL.2,SEL.3' }
        @{ Name = 'Product'; Value = 'Contoso CRM'; Expected = 'SEL.3' }
        @{ Name = 'Product'; Value = 'teams'; Expected = '' }
        @{ Name = 'Feature'; Value = 'conditional-access'; Expected = 'SEL.1' }
        @{ Name = 'Feature'; Value = @('Conditional-Access', 'bill*'); Expected = 'SEL.1,SEL.3' }
        @{ Name = 'Area'; Value = @('authentication', 'email-protection'); Expected = 'SEL.1,SEL.2' }
        @{ Name = 'Severity'; Value = 'high'; Expected = 'SEL.1,SEL.4' }
        @{ Name = 'Severity'; Value = @('Low', 'Info'); Expected = 'SEL.2,SEL.5,SEL.6' }
        @{ Name = 'Suite'; Value = 'contoso'; Expected = 'SEL.1,SEL.2,SEL.3,SEL.4,SEL.5,SEL.6' }
        @{ Name = 'Suite'; Value = 'Maester'; Expected = '' }
    ) {
        (Get-Selected @{ $Name = $Value }) -join ',' | Should -Be $Expected
    }

    It 'Needs every selector in use to match' {
        (Get-Selected @{ Product = 'entra'; Severity = 'High' }) -join ',' | Should -Be 'SEL.1'
        (Get-Selected @{ Product = 'entra'; Area = 'email-protection' }) -join ',' | Should -Be 'SEL.2'
        (Get-Selected @{ Product = 'entra'; Feature = 'conditional-access'; Area = 'email-protection' }) | Should -BeNullOrEmpty
    }

    It 'Combines the selectors with -Tag and -TestId' {
        (Get-Selected @{ Tag = 'finance' }) -join ',' | Should -Be 'SEL.3,SEL.4'
        (Get-Selected @{ Tag = 'finance'; Product = 'Contoso CRM' }) -join ',' | Should -Be 'SEL.3'
        (Get-Selected @{ Tag = 'finance'; Product = 'entra' }) | Should -BeNullOrEmpty
        (Get-Selected @{ TestId = 'SEL.1', 'SEL.2', 'SEL.3'; Product = 'entra' }) -join ',' | Should -Be 'SEL.1,SEL.2'
        (Get-Selected @{ Product = 'entra'; ExcludeTag = 'baseline' }) -join ',' | Should -Be 'SEL.2,SEL.5'
    }

    It 'Says which selector left a test out' {
        $row = Get-Plan @{ Product = 'entra'; Severity = 'Critical', 'High' } | Where-Object { $_.Test.Id -eq 'SEL.5' }
        $row.Disposition | Should -Be 'NotRun'
        $row.ReasonCode | Should -Be 'NotSelected'
        $row.ReasonDetail | Should -Be 'Not selected by -Severity (Critical, High).'
        (Get-Plan @{ Product = 'teams' } | Where-Object { $_.Test.Id -eq 'SEL.1' }).ReasonDetail | Should -Be 'Not selected by -Product (teams).'
    }

    It 'Matches -Severity against the severity the run configuration sets for a test' {
        $config = @{ TestSettings = @(@{ Id = 'SEL.2'; Severity = 'High' }, @{ Id = 'SEL.1'; Severity = 'Low' }) }
        (Get-Selected @{ Severity = 'High' } -Config $config) -join ',' | Should -Be 'SEL.2,SEL.4'
    }

    It 'Takes the selectors from the Selection section of the run configuration, and a parameter replaces its list' {
        $config = @{ Selection = @{ Product = @('Entra ID'); Severity = @('High') } }
        (Get-Selected -Config $config) -join ',' | Should -Be 'SEL.1'
        (Get-Selected @{ Severity = 'Info' } -Config $config) -join ',' | Should -Be 'SEL.5'
        $resolved = InModuleScope Maester { (Resolve-MtRunConfig -Config @{}).Selection }
        foreach ($name in 'Product', 'Feature', 'Area', 'Severity', 'Suite') { , $resolved.$name | Should -BeOfType [array] -Because $name; @($resolved.$name).Count | Should -Be 0 }
    }

    It 'Matches -Tag against the tags of the suite.json, and not against the ID of a custom test' {
        (Get-Selected @{ Tag = 'contoso-suite' }).Count | Should -Be 6
        (Get-Selected @{ Tag = 'SEL.1' }) | Should -BeNullOrEmpty
        (Get-Selected @{ ExcludeTag = 'contoso-suite' }) | Should -BeNullOrEmpty
    }

    It 'Leaves a Lifecycle = Preview test out by default, with the reason Preview' {
        $row = Get-Plan -AutoExcluded 'Preview' | Where-Object { $_.Test.Id -eq 'SEL.4' }
        $row.Disposition | Should -Be 'NotRun'
        $row.ReasonCode | Should -Be 'Preview'
        # Neither a selector nor a wildcard ID lifts the exclusion.
        (Get-Plan @{ Severity = 'High' } -AutoExcluded 'Preview' | Where-Object { $_.Test.Id -eq 'SEL.4' }).ReasonCode | Should -Be 'Preview'
        (Get-Plan @{ TestId = 'SEL.*' } -AutoExcluded 'Preview' | Where-Object { $_.Test.Id -eq 'SEL.4' }).ReasonCode | Should -Be 'Preview'
    }

    It 'Runs a Lifecycle = Preview test when previews are included or its exact ID is named' {
        Get-Selected | Should -Contain 'SEL.4'
        Get-Selected @{ TestId = 'SEL.4' } -AutoExcluded 'Preview' | Should -Be @('SEL.4')
    }

    It 'Decides by Lifecycle and LongRunning, not by a tag of that name' {
        # SEL.6 carries the tags Preview and LongRunning but is neither.
        Get-Selected -AutoExcluded 'Preview', 'LongRunning' | Should -Contain 'SEL.6'
        (Get-Plan -AutoExcluded 'Preview', 'LongRunning' | Where-Object { $_.Test.Id -eq 'SEL.5' }).ReasonCode | Should -Be 'LongRunning'
        Get-Selected @{ TestId = 'SEL.5' } -AutoExcluded 'LongRunning' | Should -Be @('SEL.5')
        # A tag the caller excludes still excludes.
        (Get-Plan @{ ExcludeTag = 'LongRunning' } | Where-Object { $_.Test.Id -eq 'SEL.6' }).ReasonCode | Should -Be 'ExcludedByTag'
    }

    It 'Runs a Lifecycle = Deprecated test' {
        Get-Selected -AutoExcluded 'Preview', 'LongRunning' | Should -Contain 'SEL.6'
    }

    It 'Leaves a test of an opt-in service out when the service is not connected, whatever its tags' {
        $test = [pscustomobject]@{
            Id = 'OPT.1'; Title = 'x'; File = $null; Errors = @(); InstanceSource = $null; Product = 'ad'; RelatedProduct = @(); Feature = $null; Area = $null; Severity = 'High'
            Suite = 'Custom'; Tag = @(); SuiteTag = @(); BuiltIn = $false; Lifecycle = 'Stable'; LongRunning = $false; Service = @('ActiveDirectory')
            Platform = @(); TenantType = @(); Cloud = @(); License = @(); UnregisteredServices = @(); Parameters = @()
        }
        $context = [pscustomobject]@{
            Platform = 'Windows'; TenantType = 'Workforce'; Cloud = 'Commercial'
            Services = [pscustomobject]@{ ActiveDirectory = $false }
            Licenses = [pscustomobject]@{ State = 'Unknown'; ServicePlanIds = @(); SkuIds = @(); ServicePlanNames = @() }
        }
        $row = Get-Plan -Test @($test) -TenantContext $context
        $row.Disposition | Should -Be 'NotRun'
        $row.ReasonCode | Should -Be 'OptInServiceNotConnected'
        $context.Services.ActiveDirectory = $true
        (Get-Plan -Test @($test) -TenantContext $context).Disposition | Should -Be 'Run'
    }

    It 'Invoke-MtTest runs the tests it is given, whatever the selectors of the configuration' {
        $rows = @(Invoke-MtTest -Path $script:selectFolder -Id 'SEL.1', 'SEL.3' -Config @{ Selection = @{ Product = @('teams'); Severity = @('Critical'); Suite = @('Maester') } })
        ($rows | Sort-Object Id | ForEach-Object { "$($_.Id)=$($_.Result)" }) -join ',' | Should -Be 'SEL.1=Passed,SEL.3=Passed'
    }

    It 'Get-MtTest takes the same five selectors' {
        (Get-MtTest -Path $script:selectFolder -Product 'Entra ID').Id | Sort-Object | Should -Be @('SEL.1', 'SEL.2', 'SEL.5')
        (Get-MtTest -Path $script:selectFolder -Product entra -Severity High).Id | Should -Be @('SEL.1')
        (Get-MtTest -Path $script:selectFolder -Feature 'bill*').Id | Should -Be @('SEL.3')
        (Get-MtTest -Path $script:selectFolder -Area authentication).Id | Should -Be @('SEL.1')
        @(Get-MtTest -Path $script:selectFolder -Suite contoso).Count | Should -Be 6
        @(Get-MtTest -Suite cisa).Count | Should -BeGreaterThan 50
        @(Get-MtTest -Product ad | Where-Object { $_.Product -ne 'ad' -and $_.RelatedProduct -notcontains 'ad' }) | Should -HaveCount 0
        (Get-Command Invoke-Maester).Parameters.Keys | Should -Contain 'Product'
        foreach ($name in 'Product', 'Feature', 'Area', 'Severity', 'Suite') {
            (Get-Command Invoke-Maester).Parameters[$name].ParameterType | Should -Be ([string[]]) -Because $name
            (Get-Command Get-MtTest).Parameters[$name].ParameterType | Should -Be ([string[]]) -Because $name
        }
    }
}

Describe 'Selecting with Maester 2.x tags' {
    BeforeAll {
        # The plan of the built-in catalog for the given tags, with the warnings it wrote.
        function Get-TagPlan {
            param([string[]] $Tag = @(), [string[]] $ExcludeTag = @())
            InModuleScope Maester -Parameters @{ Tag = $Tag; ExcludeTag = $ExcludeTag } {
                $config = Resolve-MtRunConfig -Config @{}
                $selection = Resolve-MtSelection -RunConfig $config -Tag $Tag -ExcludeTag $ExcludeTag
                $warnings = $null
                $plan = @(Resolve-MtNativePlan -Test @(Get-MtTestCatalog) -Selection $selection -RunConfig $config -IncludeTag $Tag -ExcludeTag $ExcludeTag -WarningVariable warnings -WarningAction SilentlyContinue)
                [pscustomobject]@{ Plan = $plan; Warnings = @($warnings | ForEach-Object { $_.Message }) }
            }
        }
    }

    It 'Selects the Conditional Access tests with -Tag CA and warns once, with the typed selector' {
        $r = Get-TagPlan -Tag 'CA'
        @($r.Plan | Where-Object ReasonCode -NE 'NotSelected').Count | Should -Be 38
        $r.Warnings | Should -HaveCount 1
        $r.Warnings[0] | Should -BeLike "*'CA' (now -Feature conditional-access) is a Maester 2.x tag*"
    }

    It 'Names every 2.x tag of the run in the one warning, with a selector only where the table gives one' {
        # CAWhatIf is on two of the Conditional Access tests, so the exclusion is used too.
        $r = Get-TagPlan -Tag 'ca', 'EXO', 'MS.AAD.3.5' -ExcludeTag 'CAWhatIf'
        $r.Warnings | Should -HaveCount 1
        $r.Warnings[0] | Should -BeLike "These tags are Maester 2.x tags:*"
        $r.Warnings[0] | Should -BeLike "*'ca' (now -Feature conditional-access)*"
        $r.Warnings[0] | Should -BeLike "*'EXO' (now -Product exchange)*"
        $r.Warnings[0] | Should -BeLike "*'MS.AAD.3.5'[,.]*"
        $r.Warnings[0] | Should -BeLike "*'CAWhatIf'[,.]*"
        @($r.Plan | Where-Object ReasonCode -EQ 'ExcludedByTag').Count | Should -Be 2
    }

    It 'Excludes with a 2.x tag' {
        $r = Get-TagPlan -ExcludeTag 'EIDSCA'
        @($r.Plan | Where-Object ReasonCode -EQ 'ExcludedByTag').Count | Should -Be 44
        @($r.Plan | Where-Object ReasonCode -EQ 'ExcludedByTag' | Where-Object { $_.Test.Suite -ne 'EIDSCA' }) | Should -HaveCount 0
        $r.Warnings[0] | Should -BeLike "*'EIDSCA' (now -Suite eidsca)*"
    }

    It 'Selects a built-in test by its own ID without a warning' {
        $r = Get-TagPlan -Tag 'MT.1001'
        @($r.Plan | Where-Object ReasonCode -NE 'NotSelected' | ForEach-Object { $_.Test.Id }) | Should -Be @('MT.1001')
        $r.Warnings | Should -HaveCount 0
    }

    It 'Writes no warning for a run without tags' {
        (Get-TagPlan).Warnings | Should -HaveCount 0
    }

    It 'Gives a custom test no 2.x tags and no ID tag, even when its tags are in the table' {
        $folder = Join-Path $TestDrive 'legacy-custom'
        $null = New-AttributeTestFile -Folder $folder -Id 'CUS.1' -Attribute "Product = 'entra', Tag = 'mine'"
        $tags = InModuleScope Maester -Parameters @{ F = $folder } { Get-MtSelectionTag -Test (Get-MtNativeTestInventory -Path $F -Root $F) }
        $tags.Own | Should -Be @('mine')
        $tags.Legacy | Should -HaveCount 0
        $builtIn = InModuleScope Maester { Get-MtSelectionTag -Test (Get-MtTestCatalog | Where-Object Id -EQ 'MT.1012') }
        $builtIn.Own | Should -Be @('MT.1012')
        $builtIn.Legacy | Should -Contain 'CA'
    }

    It 'Get-MtTest -Tag lists what a run with that tag selects' {
        @(Get-MtTest -Tag CA).Count | Should -Be 38
        (Get-MtTest -Tag 'MS.AAD.3.5').Id | Should -Be @('CISA.MS.AAD.3.5')
        @(Get-MtTest -Tag CA | Where-Object { @($_.Tag).Count -gt 0 }) | Should -HaveCount 0 -Because 'the tests themselves carry no tags'
    }
}

Describe 'Rows, Taxonomy and warnings of a run' {
    BeforeAll {
        $script:runFolder = Join-Path $TestDrive 'run/Custom'
        $null = New-AttributeTestFile -Folder $script:runFolder -Id 'ROW.1' -Attribute "Product = 'Entra ID', RelatedProduct = 'EXO', Feature = 'conditional-access', Area = 'authentication', ResourceType = 'Tenant', Severity = 'High', UserImpact = 'Medium', ImplementationCost = 'Low', Mitre = ('T1110', 'T1078.004'), Control = 'nist-800-53-r5:IA-2', Permission = 'Graph:Scope:Policy.Read.All', Lifecycle = 'Deprecated', ReplacedBy = 'ROW.2', Tag = ('baseline', 'ROW.1')"
        $null = New-AttributeTestFile -Folder $script:runFolder -Id 'ROW.2' -Attribute "Product = 'Contoso CRM', Feature = 'Billing', Area = 'finance', ResourceType = 'Invoice', Severity = 'Low', Mitre = 'None'"
        $null = New-AttributeTestFile -Folder $script:runFolder -Id 'ROW.3' -Attribute "Severity = 'Low', Lifecycle = 'Preview'"
        @{ Id = 'CONTOSO'; Name = 'Contoso checks'; Source = 'Custom'; Tags = @('contoso-suite') } | ConvertTo-Json | Set-Content (Join-Path $script:runFolder 'suite.json')
        "Describe 'Pester block' -Tag 'pester-tag' { It 'PES.1: pester test' { `$true | Should -BeTrue } }" | Set-Content (Join-Path $script:runFolder 'Pester.Tests.ps1')

        # Invoke-Maester calls Invoke-Pester, so the runs happen in a child process: all of them in one, for speed.
        $scenarios = [ordered]@{
            Default        = '-SkipBuiltIn'
            IncludePreview = '-SkipBuiltIn -IncludePreview'
            AnyTag         = '-SkipBuiltIn -Tag contoso-suite'
            Product        = '-SkipBuiltIn -Product entra -DryRun'
            SuiteSelector  = '-SkipBuiltIn -Suite contoso -DryRun'
            ConfigSelector = "-SkipBuiltIn -DryRun -Config @{ Selection = @{ Feature = @('Billing') } }"
            LegacyTag      = '-Tag CA, EXO -ExcludeTag MS.EXO -DryRun'
            TypedBuiltIn   = '-Product entra -Suite cisa -DryRun'
        }
        # A test that reads variables it never set must not see the selector parameters of Invoke-Maester. Only a
        # built-in test shares a scope chain with Invoke-Maester (a custom test has its own module), so the probe
        # is defined in the module and added to the catalog of the child process, after the other runs.
        $script:probeFolder = Join-Path $TestDrive 'probe'
        $probeFile = New-AttributeTestFile -Folder $script:probeFolder -Id 'PROBE.1' -Attribute "Product = 'entra', Feature = 'conditional-access', Area = 'authentication', ResourceType = 'Tenant', Severity = 'High', UserImpact = 'Low', ImplementationCost = 'Low', Mitre = 'None', Author = 'someone'" `
            -Body 'return ($null -eq $Product -and $null -eq $Feature -and $null -eq $Area -and $null -eq $Severity -and $null -eq $Suite)'

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("`$ErrorActionPreference = 'Continue'")
        $lines.Add("Import-Module '$script:manifest' -WarningAction SilentlyContinue")
        foreach ($name in $scenarios.Keys) {
            $out = Join-Path $TestDrive "$name.json"
            $warn = Join-Path $TestDrive "$name.warnings.json"
            $xml = if ($name -eq 'Default') { "-Config @{ Output = @{ TestResult = @{ Path = '$(Join-Path $TestDrive 'Default.xml')'; Format = 'JUnitXml' } } }" } else { '' }
            $lines.Add("`$w = `$null; try { `$null = Invoke-Maester -Path '$script:runFolder' -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$out' -WarningVariable w -WarningAction SilentlyContinue -ErrorAction SilentlyContinue $($scenarios[$name]) $xml } catch { }")
            $lines.Add("ConvertTo-Json -InputObject @(`$w | ForEach-Object { `$_.Message }) | Set-Content '$warn'")
        }
        $lines.Add(". (Get-Module Maester) { . `$args[0]; `$script:__MtTestCatalog = @(Get-MtTestCatalog) + (Complete-MtNativeTest -Test (Read-MtNativeTest -Path `$args[0] -BuiltIn) -Suite `$null -BuiltIn) } '$probeFile'")
        $lines.Add("`$null = Invoke-Maester -Path '$script:runFolder' -TestId PROBE.1 -Product entra, exchange -Feature conditional-access -Area authentication -Severity High, Critical -Suite Maester -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -OutputJsonFile '$(Join-Path $TestDrive 'Scope.json')' -WarningAction SilentlyContinue")
        $null = pwsh -NoProfile -NonInteractive -Command ($lines -join [Environment]::NewLine) 2>&1

        function Get-Run { param([string] $Scenario) Get-Content (Join-Path $TestDrive "$Scenario.json") -Raw | ConvertFrom-Json }
        function Get-RunWarning { param([string] $Scenario) @(Get-Content (Join-Path $TestDrive "$Scenario.warnings.json") -Raw | ConvertFrom-Json) }
        $script:attributeFields = 'Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'UserImpact', 'ImplementationCost', 'Mitre', 'Control', 'Lifecycle', 'ReplacedBy', 'Service', 'License', 'Permission'
    }

    It 'Writes every attribute field on a native row, with the product as its key' {
        $row = (Get-Run 'Default').Tests | Where-Object Id -EQ 'ROW.1'
        $row.Result | Should -Be 'Passed'
        foreach ($name in $script:attributeFields) { $row.PSObject.Properties[$name] | Should -Not -BeNullOrEmpty -Because "$name is never left out" }
        $row.Product | Should -BeExactly 'entra'
        $row.RelatedProduct | Should -Be @('exchange')
        $row.Feature | Should -Be 'conditional-access'
        $row.Area | Should -Be 'authentication'
        $row.ResourceType | Should -Be 'Tenant'
        $row.UserImpact | Should -Be 'Medium'
        $row.ImplementationCost | Should -Be 'Low'
        $row.Mitre | Should -Be @('T1110', 'T1078.004')
        $row.Control | Should -Be @('nist-800-53-r5:IA-2')
        $row.Lifecycle | Should -Be 'Deprecated'
        $row.ReplacedBy | Should -Be 'ROW.2'
        $row.Permission | Should -Be @('Graph:Scope:Policy.Read.All')
        $row.Block | Should -Be 'Entra ID'
        $row.Suite | Should -Be 'CONTOSO'
    }

    It 'Writes an attribute a test does not declare as null or an empty list' {
        $json = Get-Content (Join-Path $TestDrive 'Default.json') -Raw
        $row = ($json | ConvertFrom-Json).Tests | Where-Object Id -EQ 'ROW.2'
        foreach ($name in 'UserImpact', 'ImplementationCost', 'ReplacedBy') { $row.$name | Should -BeNullOrEmpty -Because $name }
        foreach ($name in 'RelatedProduct', 'Control', 'License', 'Permission', 'Service') { @($row.$name).Count | Should -Be 0 -Because $name }
        $row.Lifecycle | Should -Be 'Stable'
        $row.Product | Should -Be 'Contoso CRM'
        $row.Mitre | Should -Be @('None')
        # In the file an empty list is [], not null.
        $json | Should -Match '"RelatedProduct":\s*\[\]'
    }

    It 'Puts only the tags the author wrote on a row' {
        $row = (Get-Run 'Default').Tests | Where-Object Id -EQ 'ROW.1'
        $row.Tag | Should -Be @('baseline', 'ROW.1')
        @(((Get-Run 'IncludePreview').Tests | Where-Object Id -EQ 'ROW.3').Tag).Count | Should -Be 0 -Because 'neither the suite tag, the ID nor a Preview flag is written'
    }

    It 'Carries the attribute fields of a Pester-format row as null' {
        $row = (Get-Run 'Default').Tests | Where-Object Id -EQ 'PES.1'
        $row.Format | Should -Be 'Pester'
        $row.Result | Should -Be 'Passed'
        foreach ($name in $script:attributeFields) {
            $row.PSObject.Properties[$name] | Should -Not -BeNullOrEmpty -Because "$name is never left out"
            $row.$name | Should -BeNullOrEmpty -Because $name
        }
        $row.Block | Should -Be 'Pester block'
        $row.Tag | Should -Contain 'pester-tag'
    }

    It 'Adds a Taxonomy with the names of what the rows use, and nothing else' {
        $taxonomy = (Get-Run 'Default').Taxonomy
        @($taxonomy.Products.Key) | Should -Be @('entra', 'exchange')
        ($taxonomy.Products | Where-Object Key -EQ 'entra').Name | Should -Be 'Entra ID'
        @($taxonomy.Features).Count | Should -Be 1
        $taxonomy.Features[0].Product | Should -Be 'entra'
        $taxonomy.Features[0].Key | Should -Be 'conditional-access'
        $taxonomy.Features[0].Name | Should -Be 'Conditional Access'
        @($taxonomy.Areas.Key) | Should -Be @('authentication')
        $taxonomy.Areas[0].Name | Should -Be 'Authentication'
        @($taxonomy.ResourceTypes.Key) | Should -Be @('Tenant')
        @($taxonomy.ResourceTypes[0].PSObject.Properties.Name) | Should -Be @('Key')
        $taxonomy.Attack.Version | Should -Be $script:taxonomyFile.Attack.Version
        @($taxonomy.Attack.Techniques.Id | Sort-Object) | Should -Be @('T1078.004', 'T1110')
        ($taxonomy.Attack.Techniques | Where-Object Id -EQ 'T1110').Name | Should -Be 'Brute Force'
        ($taxonomy.Attack.Techniques | Where-Object Id -EQ 'T1110').Tactics | Should -Be @('TA0006')
        $used = @($taxonomy.Attack.Techniques | ForEach-Object { $_.Tactics } | Sort-Object -Unique)
        @($taxonomy.Attack.Tactics.Id | Sort-Object) | Should -Be $used
        ($taxonomy.Attack.Tactics | Where-Object Id -EQ 'TA0006').Name | Should -Be 'Credential Access'
    }

    It 'Names the XML test case of a native test after its Block' {
        [xml]$doc = Get-Content (Join-Path $TestDrive 'Default.xml') -Raw
        @($doc.testsuites.testsuite.testcase.name) | Should -Contain 'Entra ID.ROW.1: Title of ROW.1'
        @($doc.testsuites.testsuite.name) | Should -Contain 'Contoso CRM'
    }

    It 'Leaves the preview test out by default and runs it with -IncludePreview or any -Tag' {
        $default = (Get-Run 'Default').Tests | Where-Object Id -EQ 'ROW.3'
        $default.Result | Should -Be 'NotRun'
        $default.ReasonCode | Should -Be 'Preview'
        ((Get-Run 'IncludePreview').Tests | Where-Object Id -EQ 'ROW.3').Result | Should -Be 'Passed'
        ((Get-Run 'AnyTag').Tests | Where-Object Id -EQ 'ROW.3').Result | Should -Be 'Passed'
    }

    It 'Leaves a Pester-format test out of a run that selects by product, and keeps it in a run that selects by its suite' {
        $r = Get-Run 'Product'
        $pester = $r.Tests | Where-Object Id -EQ 'PES.1'
        $pester.Result | Should -Be 'NotRun'
        $pester.ReasonCode | Should -Be 'NotSelected'
        $pester.ReasonDetail | Should -Be 'Not selected by -Product (entra).'
        ($r.Tests | Where-Object Id -EQ 'ROW.1').ReasonCode | Should -Be 'DryRun'
        ($r.Tests | Where-Object Id -EQ 'ROW.2').ReasonCode | Should -Be 'NotSelected'
        ((Get-Run 'SuiteSelector').Tests | Where-Object Id -EQ 'PES.1').ReasonCode | Should -Be 'DryRun'
        @((Get-Run 'ConfigSelector').Tests | Where-Object ReasonCode -EQ 'DryRun' | ForEach-Object Id) | Should -Be @('ROW.2')
    }

    It 'Warns once in a run that selects with 2.x tags' {
        $r = Get-Run 'LegacyTag'
        @($r.Tests | Where-Object { $_.ReasonCode -notin 'NotSelected', 'ExcludedByTag' -and $_.Source -ne 'Custom' }).Count | Should -Be 105
        $warnings = @(Get-RunWarning 'LegacyTag' | Where-Object { $_ -like '*Maester 2.x tag*' })
        $warnings | Should -HaveCount 1
        $warnings[0] | Should -BeLike "*'CA' (now -Feature conditional-access)*'EXO' (now -Product exchange)*"
    }

    It 'Selects built-in tests with the typed selectors without a warning about tags' {
        $r = Get-Run 'TypedBuiltIn'
        $selected = @($r.Tests | Where-Object { $_.ReasonCode -ne 'NotSelected' })
        $selected.Count | Should -Be 30
        @($selected | Where-Object { $_.Suite -ne 'CISA' -or $_.Product -ne 'entra' }) | Should -HaveCount 0
        @(Get-RunWarning 'TypedBuiltIn' | Where-Object { $_ -like '*Maester 2.x tag*' }) | Should -HaveCount 0
        @($r.Taxonomy.Products.Key) | Should -Contain 'entra'
    }

    It 'Does not leak the selector parameters of Invoke-Maester into a test' {
        # A test function runs in a child scope of Invoke-Maester. Several built-in tests read a $Severity
        # they only set on some paths, and must keep seeing nothing when the run was started with -Severity.
        $row = (Get-Run 'Scope').Tests | Where-Object Id -EQ 'PROBE.1'
        $row.Source | Should -Be 'Maester' -Because 'the probe has to run as a built-in test'
        $row.ReasonCode | Should -BeNullOrEmpty
        $row.Result | Should -Be 'Passed'
    }

    It 'Builds the full Taxonomy for the catalog' {
        $taxonomy = InModuleScope Maester { Get-MtResultTaxonomy -All }
        @($taxonomy.Products.Key) | Should -Be @($script:taxonomyFile.Products.Key)
        @($taxonomy.Features).Count | Should -Be @($script:taxonomyFile.Products | ForEach-Object { $_.Features }).Count
        @($taxonomy.Areas.Key) | Should -Be @($script:taxonomyFile.Areas.Key)
        @($taxonomy.ResourceTypes.Key) | Should -Be @($script:taxonomyFile.ResourceTypes.Key)
        @($taxonomy.Attack.Techniques).Count | Should -BeGreaterThan 500
        @($taxonomy.Attack.Tactics).Count | Should -BeGreaterThan 10
    }

    It 'Recomputes the Taxonomy when the parts of one run are merged' {
        $default = Get-Run 'Default'
        $partA = $default.PSObject.Copy(); $partA.Tests = @($default.Tests | Where-Object Id -EQ 'ROW.1')
        $partA.Taxonomy = InModuleScope Maester -Parameters @{ R = $partA.Tests } { Get-MtResultTaxonomy -InputObject $R }
        $partB = $default.PSObject.Copy(); $partB.Tests = @([pscustomobject]@{ Id = 'X.1'; Name = 'X.1: x'; Result = 'Passed'; Block = 'Teams'; Product = 'teams'; RelatedProduct = @(); Feature = 'meetings'; Area = 'external-access'; ResourceType = 'Policy'; Mitre = @('T1566'); Tag = @() })
        $partB.Taxonomy = InModuleScope Maester -Parameters @{ R = $partB.Tests } { Get-MtResultTaxonomy -InputObject $R }
        $merged = Merge-MtMaesterResult -MaesterResults $partA, $partB -SameRun
        @($merged.Taxonomy.Products.Key) | Should -Be @('entra', 'exchange', 'teams')
        @($merged.Taxonomy.Features.Key) | Should -Be @('conditional-access', 'meetings')
        @($merged.Taxonomy.Attack.Techniques.Id) | Should -Contain 'T1566'
    }

    It 'Titles the console lane of a test with the name of its product' {
        InModuleScope Maester { Get-MtProductLane -Product 'entra' } | Should -Be 'Entra ID'
        InModuleScope Maester { Get-MtProductLane -Product 'Contoso CRM' } | Should -Be 'Contoso CRM'
        InModuleScope Maester { Get-MtProductLane -Product $null } | Should -Be 'Other'
    }
}

Describe 'Catalog build' {
    BeforeAll {
        # The build only writes inside the repository, so the fixture lives there (ignored by git) and is removed afterwards.
        $script:buildFixture = Join-Path $script:repoRoot ".tmp-maester-build-tests-$([guid]::NewGuid())"
    }
    AfterAll {
        if (Test-Path -LiteralPath $script:buildFixture) { Remove-Item -LiteralPath $script:buildFixture -Recurse -Force }
    }

    It 'Fails when a built-in test names a retired or unknown ATT&CK technique' {
        $tests = Join-Path $script:buildFixture 'tests/maester/entra'
        $null = New-Item -ItemType Directory -Path $tests -Force
        foreach ($case in @(@{ Id = 'BUILD.1'; Mitre = 'T1002' }, @{ Id = 'BUILD.2'; Mitre = 'T9999' }, @{ Id = 'BUILD.3'; Mitre = 'T1110' })) {
            @"
function Test-$($case.Id -replace '\.', '') {
    [MaesterTest(Id = '$($case.Id)', Title = 'x', Product = 'entra', Severity = 'High', Mitre = '$($case.Mitre)', Service = 'None', Author = 'someone')]
    [CmdletBinding()]
    param()
    `$true
}
"@ | Set-Content (Join-Path $tests "Test.$($case.Id).ps1")
            'd' | Set-Content (Join-Path $tests "Test.$($case.Id).md")
        }
        $pwsh = (Get-Process -Id $PID).Path
        $output = & $pwsh -NoProfile -NonInteractive -File (Join-Path $script:repoRoot 'build/Build-MaesterModule.ps1') -TestsRoot (Join-Path $script:buildFixture 'tests') -OutputRoot (Join-Path $script:buildFixture 'module') 2>&1 | Out-String
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match 'T1002 was retired in ATT&CK'
        $output | Should -Match 'T9999 is not in ATT&CK'
        $output | Should -Not -Match 'T1110 (was|is not)'
    }
}

Describe 'Convert-MtTestAttributes.ps1 (migration)' {
    BeforeAll {
        $script:migration = Join-Path $script:repoRoot 'build/migration/Convert-MtTestAttributes.ps1'
        $script:migrationRoot = Join-Path $TestDrive 'migration'
        $script:migrationTests = Join-Path $script:migrationRoot 'tests'
        $script:migrationValues = Join-Path $script:migrationRoot 'attributes'
        $null = New-Item -ItemType Directory -Path (Join-Path $script:migrationTests 'maester/entra'), $script:migrationValues -Force

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $utf8Bom = [System.Text.UTF8Encoding]::new($true)
        # A 3.0-preview test: byte order mark, LF, Category, an alias as Product, tags and the Preview flag.
        $script:previewForm = @'
function Test-Mig1 {
    <#
    .SYNOPSIS
    Text before the attribute stays as it is: Category = 'not an attribute'.
    #>
    [MaesterTest(
        Id = 'MIG.1',
        Title = 'A test with ''quotes''',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('CA', 'Maester'),
        Preview,
        LongRunning,
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'someone',
        HelpUrl = 'https://example.com/x'
    )]
    [CmdletBinding()]
    param()

    # Text after the attribute stays as it is: Tag = ('CA').
    return $true
}
'@ -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Join-Path $script:migrationTests 'maester/entra/Test.MIG.1.ps1'), $script:previewForm, $utf8Bom)
        # CRLF, no byte order mark, the 2.x tag Deprecated.
        $deprecated = @'
function Test-Mig2 {
    [MaesterTest(
        Id = 'MIG.2',
        Title = 'Deprecated by its tag',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('Deprecated', 'MS.EXO'),
        Service = 'Graph',
        Author = 'someone'
    )]
    [CmdletBinding()]
    param()
    return $null
}
'@ -replace "`r`n", "`n" -replace "`n", "`r`n"
        [System.IO.File]::WriteAllText((Join-Path $script:migrationTests 'maester/entra/Test.MIG.2.ps1'), $deprecated, $utf8)
        # Already in the new form, but not in the order of the design.
        $newForm = @'
function Test-Mig3 {
    [MaesterTest(
        Id = 'MIG.3',
        Title = 'Already converted',
        Author = 'someone',
        Severity = 'Low',
        Service = 'Graph',
        Product = 'entra'
    )]
    [CmdletBinding()]
    param()
    return $true
}
'@ -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Join-Path $script:migrationTests 'maester/entra/Test.MIG.3.ps1'), $newForm, $utf8)
        '{ "Id": "Maester", "Name": "Maester", "Source": "Maester", "Tags": [ "Maester" ] }' | Set-Content (Join-Path $script:migrationTests 'maester/suite.json')
        @'
{ "Comment": "other keys are ignored",
  "Tests": [
    { "Id": "MIG.1", "RelatedProduct": ["EXO"], "Feature": "Conditional-Access", "Area": "authentication", "ResourceType": "tenant",
      "UserImpact": "medium", "ImplementationCost": "Low", "Mitre": ["T1110", "T1078.004"], "Rationale": "ignored" },
    { "Id": "MIG.3", "RelatedProduct": [], "Feature": null, "Area": "", "ResourceType": "User", "Mitre": ["None"] },
    { "Id": "NOPE.1", "Feature": "x" }
  ] }
'@ | Set-Content (Join-Path $script:migrationValues '01-values.json')

        function Invoke-Migration {
            param([switch] $Simulate)
            $pwsh = (Get-Process -Id $PID).Path
            $arguments = @('-NoProfile', '-NonInteractive', '-File', $script:migration, '-Path', $script:migrationTests, '-AttributesPath', $script:migrationValues, '-SkipGenerators', '-SkipValidation')
            if ($Simulate) { $arguments += '-WhatIf' }
            $output = & $pwsh @arguments 2>&1 | ForEach-Object { "$_" }
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output; Summary = ($output | Where-Object { $_ -like 'Summary:*' } | Select-Object -Last 1) }
        }
        function Get-FileContent { param([string] $Name) , [System.IO.File]::ReadAllBytes((Join-Path $script:migrationTests "maester/entra/$Name")) }
        function Get-AttributeText {
            param([string] $Name)
            $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:migrationTests "maester/entra/$Name"), [ref] $null, [ref] $null)
            $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -eq 'MaesterTest' }, $true).Extent.Text -replace "`r`n", "`n"
        }

        $script:before = @{}
        foreach ($name in 'Test.MIG.1.ps1', 'Test.MIG.2.ps1', 'Test.MIG.3.ps1') { $script:before[$name] = Get-FileContent $name }
        $script:whatIf = Invoke-Migration -Simulate
        $script:afterWhatIf = @{}
        foreach ($name in $script:before.Keys) { $script:afterWhatIf[$name] = Get-FileContent $name }
        $script:first = Invoke-Migration
        $script:afterFirst = @{}
        foreach ($name in $script:before.Keys) { $script:afterFirst[$name] = Get-FileContent $name }
        $script:second = Invoke-Migration
        $script:afterSecond = @{}
        foreach ($name in $script:before.Keys) { $script:afterSecond[$name] = Get-FileContent $name }
    }

    It 'Writes nothing with -WhatIf and still reports what it would do' {
        $script:whatIf.ExitCode | Should -Be 0 -Because ($script:whatIf.Output -join "`n")
        foreach ($name in $script:before.Keys) { [System.Convert]::ToBase64String($script:afterWhatIf[$name]) | Should -Be ([System.Convert]::ToBase64String($script:before[$name])) -Because $name }
        $script:whatIf.Summary | Should -BeLike 'Summary: Files=3 Changed=3 *(WhatIf: nothing was written)'
    }

    It 'Converts the attribute: no Category, Preview and Deprecated as Lifecycle, the product key, no Tag, values merged, in the order of the design' {
        $script:first.ExitCode | Should -Be 0 -Because ($script:first.Output -join "`n")
        Get-AttributeText 'Test.MIG.1.ps1' | Should -BeExactly (@'
[MaesterTest(
        Id = 'MIG.1',
        Title = 'A test with ''quotes''',
        Product = 'entra',
        RelatedProduct = 'exchange',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1110', 'T1078.004'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Lifecycle = 'Preview',
        LongRunning,
        Author = 'someone',
        HelpUrl = 'https://example.com/x'
    )]
'@ -replace "`r`n", "`n")
        Get-AttributeText 'Test.MIG.2.ps1' | Should -BeExactly (@'
[MaesterTest(
        Id = 'MIG.2',
        Title = 'Deprecated by its tag',
        Product = 'exchange',
        Severity = 'Medium',
        Service = 'Graph',
        Lifecycle = 'Deprecated',
        Author = 'someone'
    )]
'@ -replace "`r`n", "`n")
    }

    It 'Leaves a property alone when its value is null or empty, and puts an out-of-order attribute in order' {
        Get-AttributeText 'Test.MIG.3.ps1' | Should -BeExactly (@'
[MaesterTest(
        Id = 'MIG.3',
        Title = 'Already converted',
        Product = 'entra',
        ResourceType = 'User',
        Severity = 'Low',
        Mitre = 'None',
        Service = 'Graph',
        Author = 'someone'
    )]
'@ -replace "`r`n", "`n")
    }

    It 'Changes nothing outside the attribute and keeps the encoding and line endings' {
        $text = [System.IO.File]::ReadAllText((Join-Path $script:migrationTests 'maester/entra/Test.MIG.1.ps1'))
        $start = $script:previewForm.IndexOf('[MaesterTest(')
        $text.Substring(0, $start) | Should -BeExactly $script:previewForm.Substring(0, $start)
        $tail = $script:previewForm.Substring($script:previewForm.IndexOf("`n    [CmdletBinding()]"))
        $text.EndsWith($tail) | Should -BeTrue
        $script:afterFirst['Test.MIG.1.ps1'][0..2] | Should -Be @(0xEF, 0xBB, 0xBF) -Because 'the byte order mark is kept'
        $text | Should -Not -Match "`r"
        $second = [System.IO.File]::ReadAllText((Join-Path $script:migrationTests 'maester/entra/Test.MIG.2.ps1'))
        $script:afterFirst['Test.MIG.2.ps1'][0] | Should -Not -Be 0xEF -Because 'no byte order mark is added'
        ($second -replace "`r`n", '') | Should -Not -Match "[`r`n]" -Because 'every line still ends with CRLF'
    }

    It 'Reads the converted tests as valid tests shipped with Maester' {
        foreach ($name in $script:before.Keys) {
            $file = Join-Path $script:migrationTests "maester/entra/$name"
            $errors = @(Get-OtherError (InModuleScope Maester -Parameters @{ F = $file } { Read-MtNativeTest -Path $F -BuiltIn }))
            $errors | Should -HaveCount 0 -Because "$name $($errors.Message -join '; ')"
        }
    }

    It 'Removes the Tags of the suite.json' {
        $suite = Get-Content (Join-Path $script:migrationTests 'maester/suite.json') -Raw | ConvertFrom-Json
        $suite.PSObject.Properties['Tags'] | Should -BeNullOrEmpty
        $suite.Id | Should -Be 'Maester'
    }

    It 'Counts every kind of change in one summary line and names the IDs it does not know' {
        $script:first.Summary | Should -Be 'Summary: Files=3 Changed=3 Category=2 Preview=1 Deprecated=1 Product=2 Tag=2 Reordered=0 Values=2 Eidsca=0 Orca=0 Generated=0 Suites=1 UnknownIds=1 Invalid=0'
        ($script:first.Output -join "`n") | Should -Match 'NOPE\.1'
    }

    It 'Is idempotent: a second run changes no file and counts no change' {
        $script:second.ExitCode | Should -Be 0 -Because ($script:second.Output -join "`n")
        foreach ($name in $script:before.Keys) { [System.Convert]::ToBase64String($script:afterSecond[$name]) | Should -Be ([System.Convert]::ToBase64String($script:afterFirst[$name])) -Because $name }
        $script:second.Summary | Should -Be 'Summary: Files=3 Changed=0 Category=0 Preview=0 Deprecated=0 Product=0 Tag=0 Reordered=0 Values=0 Eidsca=0 Orca=0 Generated=0 Suites=0 UnknownIds=1 Invalid=0'
    }

    It 'Finds no Category, Preview or product alias left in the built-in tests' {
        $pwsh = (Get-Process -Id $PID).Path
        $output = & $pwsh -NoProfile -NonInteractive -File $script:migration -WhatIf -AttributesPath (Join-Path $TestDrive 'no-values') 2>&1 | ForEach-Object { "$_" }
        $summary = $output | Where-Object { $_ -like 'Summary:*' } | Select-Object -Last 1
        $summary | Should -Match 'Category=0 Preview=0 Deprecated=0 Product=0 ' -Because 'the built-in tests are kept in the converted form'
    }
}
