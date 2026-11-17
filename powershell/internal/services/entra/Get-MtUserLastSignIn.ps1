function Get-MtUserLastSignIn {
    <#
    .SYNOPSIS
        Returns the time of a user's most recent sign-in, in UTC, from the signInActivity of a user object.

    .DESCRIPTION
        Reads the signInActivity that a users request returns when it selects that property. By default the latest of
        the interactive and the non-interactive sign-in is returned. With -InteractiveOnly only lastSignInDateTime is
        read, as some audit procedures do.

        Returns $null when the user has no recorded sign-in of the kind asked for.

    .EXAMPLE
        Get-MtUserLastSignIn -User $user

        Returns the latest interactive or non-interactive sign-in of $user, or $null.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param (
        # A user object from Microsoft Graph that includes signInActivity.
        [Parameter(Mandatory)]
        [object] $User,

        # Read only the interactive sign-in (lastSignInDateTime).
        [switch] $InteractiveOnly
    )

    $values = if ($InteractiveOnly) {
        @($User.signInActivity.lastSignInDateTime)
    } else {
        @($User.signInActivity.lastSignInDateTime, $User.signInActivity.lastNonInteractiveSignInDateTime)
    }
    $signIns = @($values | Where-Object { $_ } | ForEach-Object { ([datetime]$_).ToUniversalTime() })
    if ($signIns.Count -eq 0) { return $null }
    return ($signIns | Measure-Object -Maximum).Maximum
}
