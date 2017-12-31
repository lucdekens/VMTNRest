Initialize-VMTNRest

$now = Get-Date

Get-VMTNContent -Keyword 'VSAN' -ContentType post -SearchSubjectOnly -Start $now.AddMonths(-1) | 
select subject,status,resolved,replycount,viewcount,
    @{N='Author';E={$_.author.displayName}},
    @{N='Location';E={$_.parentPlace.name}},
    @{N='Published';E={([DateTime]$_.published).ToLocalTime()}},
    @{N='LastActivity';E={([DateTime]$_.lastActivityDate).ToLocalTime()}} |
Format-Table -AutoSize
