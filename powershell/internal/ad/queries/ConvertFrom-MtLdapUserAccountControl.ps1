function ConvertFrom-MtLdapUserAccountControl {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [int] $UserAccountControl
    )

    try {
        return [PSCustomObject]@{
            AccountDisabled              = [bool]($UserAccountControl -band 0x00000002)
            HomeDirRequired               = [bool]($UserAccountControl -band 0x00000008)
            Lockout                       = [bool]($UserAccountControl -band 0x00000010)
            PasswordNotRequired           = [bool]($UserAccountControl -band 0x00000020)
            PasswordCannotChange          = [bool]($UserAccountControl -band 0x00000040)
            EncryptedTextPasswordAllowed  = [bool]($UserAccountControl -band 0x00000080)
            TempDuplicateAccount          = [bool]($UserAccountControl -band 0x00000100)
            NormalAccount                 = [bool]($UserAccountControl -band 0x00000200)
            InterdomainTrustAccount       = [bool]($UserAccountControl -band 0x00000800)
            WorkstationTrustAccount       = [bool]($UserAccountControl -band 0x00001000)
            ServerTrustAccount            = [bool]($UserAccountControl -band 0x00002000)
            DontExpirePassword            = [bool]($UserAccountControl -band 0x00010000)
            MnsLogonAccount               = [bool]($UserAccountControl -band 0x00020000)
            SmartcardRequired             = [bool]($UserAccountControl -band 0x00040000)
            TrustedForDelegation          = [bool]($UserAccountControl -band 0x00080000)
            NotDelegated                  = [bool]($UserAccountControl -band 0x00100000)
            UseDesKeyOnly                 = [bool]($UserAccountControl -band 0x00200000)
            DontRequirePreauth            = [bool]($UserAccountControl -band 0x00400000)
            PasswordExpired               = [bool]($UserAccountControl -band 0x00800000)
            TrustedToAuthForDelegation    = [bool]($UserAccountControl -band 0x01000000)
            PartialSecretsAccount         = [bool]($UserAccountControl -band 0x04000000)
        }
    }
    catch {
        Write-Verbose "Could not convert userAccountControl value '$UserAccountControl': $($_.Exception.Message)"
        throw
    }
}
