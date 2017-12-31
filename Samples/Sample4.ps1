Initialize-VMTNRest

Get-VMTNAuthor -Author lucd | 
Select displayName,id,
    @{N='Published';E={([DateTime]$_.published).ToLocalTime()}},
    @{N='Updated';E={([DateTime]$_.updated).ToLocalTime()}} 
