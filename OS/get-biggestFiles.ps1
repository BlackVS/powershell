[CmdletBinding()] 
Param(
    [String]$Path = '.', 
    [Int]$Top = 32
)
$verbose=$VerbosePreference -eq 'Continue'

$paramsCount=$args.Count+$PSBoundParameters.Count

if($paramsCount -eq 0) {
    Get-Help $MyInvocation.MyCommand.Definition
    Write-Output "Examples:"
    Write-Output "$($MyInvocation.MyCommand) d:\"
    Write-Output "$($MyInvocation.MyCommand) -Path d:\ -v"
    Write-Output "$($MyInvocation.MyCommand) -Path d:\ -Top 10 -Verbose"
    return
}

$files = Get-ChildItem $Path -recurse | Sort-Object length -descending | select-object FullName, Name, Length -first $Top 

if($verbose) {
 $files | ft @{Label='Size, MB'; Expression={"{0:N0}" -f ($_.Length/1MB)}; align="left"},FullName -wrap –auto
}

$res = $files | measure-object -property length –sum

Write-Output "Total: $([math]::Round($res.Sum/1gb,2)) Gb"