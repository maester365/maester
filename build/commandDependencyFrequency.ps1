$dependencies = @()
$files = gci ..\powershell\public\ -File *.ps1 -Recurse
foreach($file in $files){
    $content  = gc $file -Raw
    $parse    = [System.Management.Automation.Language.Parser]::ParseInput($content,[ref]$null,[ref]$null)
    $commands = $parse.FindAll({
        $args|?{$_ -is [System.Management.Automation.Language.CommandAst]}
    },$true)|%{($_.CommandElements|Select -First 1).Value}`
    |group|sort @{e={$_.Count};Descending=$true},Name

    foreach($command in $commands){
        $dependencies += @{
            file    = $file
            command = $command.Name
            count   = $command.Count
        }
    }
}

$dependencies|group command|sort @{e={$_.Count};Descending=$true},Name|select count,name
#Show modules
#($dependencies.Name|%{Get-Command $_}).Source|sort -Unique