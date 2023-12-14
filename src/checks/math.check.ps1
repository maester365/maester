Register-MtCheck -Name Math -Message 'Should not be too large' -Category Math -Tags Math, Example -Config @{ Max = 100 } -Code {
	param ($Param)

	42 | Should -BeLessOrEqual $Param.Max
}
# Explicitly adding a config entry for ease of discovery. -Initialize ensures it does not overwrite user-imported config files
Set-PSFConfig -FullName 'Maester.Checks.Math.Max' -Value 100 -Initialize -Validation integer -Description 'The maximum number the math check accepts.'