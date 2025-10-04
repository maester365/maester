Describe "TestBlock1" {
	It "id.1.0: Error, SkippedBecause error" {
		Add-MtTestResultDetail -SkippedBecause Error
	}

	It "id.2.0: Error, SkippedBecause SkippedError" {
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError "STRING_SKIPPEDERROR"
	}

	It "id.3.0: Error, SkippedBecause Error Exception"  {
		try {
			# Simulate some code that throws an exception
			1+1
			throw "ThisIsException"
		} catch {
			Add-MtTestResultDetail -SkippedBecause Error -SkippedError "$_"
		}
	}

	It "id.4.0: Success, Setting Success" -Tag "Success" {
		Add-MtTestResultDetail -Result "All Good"
	}

	It "id.5.0: Skipped, Setting SkippedBecause NotConnectedAzure" {
		Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
	}

	It "id.6.0: Skipped, Setting SkippedBecause ParameterBindingException" {
		# DELIBERATE: Missing parameter value to test parameter binding exception
		Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason
	}

	It "id.7.0: Skipped, Setting SkippedBecause Custom with Reason" {
		Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Custom Reason For Skipped"
	}

	It "id.8.0: Error, Throwing exception, not catching "  {
		throw "Uncaught exception"
	}

	It "id.9.0: Failed, Pure Pester failure"  {
		$false | Should -Be $true
	}
}

Describe "TestBlock2" {
	It "id.20.0: NotRun, Tag not selected" -Tag 'Severity:High','testtag' {
		# DELIBERATE: Missing parameter value to test parameter binding behavior
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError
	}
}
Describe "TestBlock3" {
	It "id.30.0: Error, Bad Parameter" -Tag 'Severity:High' {
		# DELIBERATE: Typo in parameter value to test error handling
		Add-MtTestResultDetail -SkippedBecause Erro
	}

	It "id.31.0:Error, Setting Skipped Error false" -Tag 'Severity:Medium' {
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError "Testing error setting"
		return $false 
	}
}
