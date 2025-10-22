# Smoke test for basic failure scenarios
# It is used to validate that the maester framework and reporting works as expected
# The tests here are deliberately designed to cover various Errors, arise from different exceptions.
#
# The string in TestNames Smoke_{Error, Skipped,Failed, Success, NotRun}
# are used in the Invoke-Maester.Tests.ps1 to validate the results.

Describe "Error and Skip Scenarios" {
	It "id.1.0: Smoke_Error, SkippedBecause error" {
		Add-MtTestResultDetail -SkippedBecause Error
	}

	It "id.2.0: Smoke_Error, SkippedBecause SkippedError" {
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError "STRING_SKIPPEDERROR"
	}

	It "id.3.0: Smoke_Error, SkippedBecause Error Exception" {
		try {
			# Simulate some code that throws an exception
			1 + 1
			throw "ThisIsException"
		} catch {
			Add-MtTestResultDetail -SkippedBecause Error -SkippedError "$_"
		}
	}

	It "id.4.0: Smoke_Success, Setting Success" -Tag "Success" {
		Add-MtTestResultDetail -Result "All Good"
	}

	It "id.5.0: Smoke_Skipped, Setting SkippedBecause NotConnectedAzure" {
		Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
	}

	It "id.6.0: Smoke_Error, Setting SkippedBecause ParameterBindingException" {
		# DELIBERATE: Missing parameter value to test parameter binding exception.
		# EXPECTED: This will cause a ParameterBindingException, which is intentional for testing error handling.
		Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason
	}

	It "id.7.0: Smoke_Skipped, Setting SkippedBecause Custom with Reason" {
		Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Custom Reason For Skipped"
	}

	It "id.8.0: Smoke_Error, Throwing exception, not catching" {
		throw "Uncaught exception"
	}

	It "id.9.0: Smoke_Failed, Pure Pester failure" {
		$false | Should -Be $true
	}
}

Describe "Tag Filtering Tests" {
	It "id.20.0: Smoke_NotRun, Tag not selected" -Tag 'Severity:High', 'testtag' {
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError "Never reached. We exclude tag, so count as NotRun"
	}
}

Describe "Parameter Validation Tests" {
	It "id.30.0: Smoke_Error, Bad Parameter" -Tag 'Severity:High' {
		# DELIBERATE: Invalid parameter value to test error handling
		Add-MtTestResultDetail -SkippedBecause "InvalidEnumValue"
	}

	It "id.31.0: Smoke_Error, Setting Skipped Error false" -Tag 'Severity:Medium' {
		Add-MtTestResultDetail -SkippedBecause Error -SkippedError "Testing error setting"
		return $false
	}
}
