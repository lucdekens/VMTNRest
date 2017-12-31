Initialize-VMTNRest

Get-VMTNContent -Keyword 'New-OSCustomizationSpec' |
select subject,status,resolved,replycount,viewcount,
    @{N='Author';E={$_.author.displayName}},
    @{N='Location';E={$_.parentPlace.name}},
    @{N='Published';E={([DateTime]$_.published).ToLocalTime()}},
    @{N='LastActivity';E={([DateTime]$_.lastActivityDate).ToLocalTime()}} |
Format-Table -AutoSize
