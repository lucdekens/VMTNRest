Initialize-VMTNRest

$pcliCommunities = Get-VMTNCommunity -Community powercli -IncludeGroup | select -ExpandProperty name

Get-VMTNContent -Keyword powercli -Start (Get-Date).AddMonths(-1) |
where{$pcliCommunities -notcontains $_.parentPlace.name} |
select subject,status,resolved,
    @{N='Author';E={$_.author.displayName}},
    @{N='Location';E={$_.parentPlace.name}},
    @{N='Published';E={([DateTime]$_.published).ToLocalTime()}}
