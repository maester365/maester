# Generated on 10/25/2024 18:13:47 by .\build\orca\Update-OrcaTests.ps1

Function Add-IsPresetValue
{
    Param (
        $CollectionEntity
    )

    # List of preset names
    $PresetNames = @("Standard Preset Security Policy","Strict Preset Security Policy","Built-In Protection Policy")

    foreach($item in $CollectionEntity)
    {
        
        if($null -ne $item.Name)
        {
            $IsPreset = $PresetNames -contains $item.Name

            $item | Add-Member -MemberType NoteProperty -Name IsPreset -Value $IsPreset
        }
        
    }
}
