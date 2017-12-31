Initialize-VMTNRest

Get-VMTNCommunity -Community PowerCLI -IncludeBlog -IncludeGroup |
Select-Object -Property name,type,description
