Initialize-VMTNRest

$origin = Get-Date "10 Jul 2003"
Get-VMTNAuthor -CreatedAfter $origin -CreatedBefore $origin.AddDays(1) | 
Sort-Object -Property {[int]$_.id} |
Select-Object -First 5 -Property displayName,id,
        @{N='Points';E={$_.jive.level.points}},
        @{N='Published';E={([DateTime]$_.published).ToLocalTime()}} |
Format-Table -AutoSize