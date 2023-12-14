$categoryHash = @{
	Privilege = 'Checking the assignments of administrative privileges'
}

foreach ($pair in $categoryHash.GetEnumerator()) {
	Register-MtCategory -Name $pair.Key -Description $pair.Value
}