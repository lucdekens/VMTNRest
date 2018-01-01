Initialize-VMTNRest

Get-VMTNContent -Start (Get-Date "Jan 1 2018") -MaxSamples 1 |
Select-Object -Property subject,
@{N='Published';E={([DateTime]$_.published).ToLocalTime()}},
    @{N='Author';E={$_.author.displayName}},
    @{N='Community';E={$_.parentPlace.name}}
