Initialize-VMTNRest

Get-VMTNCommunity -Community 'VMware PowerCLI' -ExactMatch  |
Select-Object -Property name,description,type
