# Generated on 08/24/2024 20:37:37 by .\build\orca\Update-OrcaTests.ps1

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
