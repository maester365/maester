# Based on https://github.com/pester/Pester/blob/main/tst/Help.Tests.ps1
BeforeDiscovery {
	$moduleName = 'Maester'
	$exportedCommands = Get-Command -Module $moduleName -CommandType Cmdlet, Function
}

Describe 'Testing module help' -Tag 'Help','Acceptance' -ForEach @{ exportedCommands = $exportedCommands; moduleName = $moduleName } {
	Context '<_.CommandType> <_.Name>' -ForEach $exportedCommands {
		BeforeAll {
			$command = $_
			$help = $_ | Get-Help
		}

		It 'Help is found' {
			$help.Name | Should -Be $command.Name
			$help.Category | Should -Be $command.CommandType
			$help.ModuleName | Should -Be $moduleName
		}

		It 'Synopsis is defined' {
			$help.Synopsis | Should -Not -BeNullOrEmpty
			# Syntax is used as synopsis when none is defined in help.
			$help.Synopsis | Should -Not -Match "^\s*$($command.Name)((\s+\[+?-\w+)|$)"
		}

		It 'Description is defined' {
			# Property is missing if undefined
			$help.description | Should -Not -BeNullOrEmpty
		}

		It 'Has link sections' {
			$help.psobject.properties.name -match 'relatedLinks' | Should -Not -BeNullOrEmpty -Because 'all exported functions should at least have link to online version as first Uri'

			$firstUri = $help.relatedLinks.navigationLink | Where-Object uri | Select-Object -First 1 -ExpandProperty uri
			$firstUri | Should -Be "https://maester.dev/docs/commands/$($help.Name)" -Because 'first uri-link should be to online version of this help topic'
		}

		It 'Has at least one example' {
			$help.Examples | Should -Not -BeNullOrEmpty
			$help.Examples.example | Where-Object { -not $_.Code.Trim() } | ForEach-Object { $_.title.Trim('- ') } | Should -Be @() -Because 'no examples should be empty'
		}

		It 'All static parameters have description' {
			$RiskMitigationParameters = 'Whatif', 'Confirm'

			if ($help.parameters) {
				$parametersMissingHelp = @($help.parameters | ForEach-Object Parameter |
						Where-Object name -NotIn $RiskMitigationParameters |
						Where-Object { $_.psobject.properties.name -notcontains 'description' } |
						ForEach-Object name)

				$parametersMissingHelp | Should -Be @()
			} else {
				# no static parameters to test. pass.
			}
		}
	}
}
