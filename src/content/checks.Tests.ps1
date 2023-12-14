Describe "Executing Maester Checks" {
	$byCategory = Get-MtCheck | Group-Object Category | Sort-Object Name
	$categories = Get-MtCategory -AsHashtable

	foreach ($checkGroup in $byCategory) {
		$message = $categories[$checkGroup.Name]
		if (-not $message) { $message = "Executing category: $($checkGroup.Name)" }

		Describe $message -ForEach $checkGroup {
			$checkGroup = $_

			foreach ($check in $checkGroup.Group) {
				$set = @{
					Check      = $check
					Parameters = Resolve-MtCheckParameter -Name $check.Name
				}
				It $check.Message -Tag $check.Tags -ForEach $set {
					& $check.Code $parameters
				}
			}
		}
	}
}