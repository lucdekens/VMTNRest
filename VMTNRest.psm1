function Initialize-VMTNRest
{
  param(
#    [Parameter(Mandatory = $True,ValueFromPipeline = $True, ParameterSetName = 'Credential')]
#    [System.Management.Automation.PSCredential]$Credential,
#    [Parameter(Mandatory = $True, ParameterSetName = 'PlainText')]
#    [string]$User,
#    [Parameter(Mandatory = $True, ParameterSetName = 'PlainText')]
#    [string]$Password,
    [string]$Proxy = '',
    [string]$VMTNUri = 'https://communities.vmware.com',
    [string]$JiveRest = 'api/core/v3',
    [int]$MaxCount = 100
  )

  Process
  {
#    if ($PSCmdlet.ParameterSetName -eq 'PlainText'){
#        $sPswd = ConvertTo-SecureString -String $Password -AsPlainText -Force
#        $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList ($User, $sPswd)
#    }
#    
#    $script:AuthHeader = &{
#        $User = $Credential.UserName
#        $Password = $Credential.GetNetworkCredential().password
#        $pair = "$($User):$($Password)"
#        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
#        "Basic $encodedCreds"
#    }

    $script:Proxy = $Proxy
    $script:VMTNUri = $VMTNUri
    $script:JiveRest = $JiveRest
    $Script:MaxCount = $MaxCount
  }
}

function Get-VMTNRest
{
  param(
    [string]$Uri,
    [string]$Method
  )

  Process{
      $sRest = @{
        Uri = $Uri
        Method = $Method
        ContentType = 'application/json'
        Headers = @{
            'Accept' = 'application/json'
            'Authorization' = "$script:AuthHeader"
        }
      }
      if($Script:Proxy){
        $sRest.Add('ProxyUseDefaultCredentials',$true)
        $sRest.Add('Proxy',$Script:Proxy)
      }
      Try{
          $rawResult = Invoke-RestMethod @sRest
          $result = $rawResult.Replace('throw ''allowIllegalResourceCall is false.'';','')
          $result | ConvertFrom-Json
      }
      Catch{
        $Error[0].Exception
      }
    }
}

function Get-VMTNCommunity
{
  [cmdletbinding(SupportsShouldProcess=$true)]
  param(
    [string[]]$Community = '*',
    [switch]$IncludeCommunity = $true,
    [switch]$IncludeBlog = $false,
    [switch]$IncludeGroup = $false,
    [switch]$ExactMatch = $false
  )

  Process{
    $filter = @("count=$($script:maxCount)")
    if($Community){
        $searchAll = $Community -join ','
        $filter += "filter=search($($searchAll))"
    }
    if($IncludeCommunity){
        $types = @('space')
        $typeMatch = @('community/vmtn')
    }
    if($IncludeBlog){
        $types += 'blog'
        $typeMatch += '/blog$' 
    }
    if($IncludeGroup){
        $types += 'group'
        $typeMatch += 'com/groups' 
    }
    $filter += "filter=type($($types -join ','))"
    $filterStr = $filter -join '&'

    $restStr = "search/places"

    $sRest = @{
      Uri = ($script:VMTNUri,$script:JiveRest,$restStr -join '/'),$filterStr -join '?'
      Method = 'Get'
    }

    if($pscmdlet.ShouldProcess($sRest['Uri'], "Search VMTN")){
        $result = @()
        $communities = Get-VMTNRest @sRest
        $result += $communities.list
    
        while($communities.links.next){
          $sRest.Uri = $communities.links.next
          $communities = Get-VMTNRest @sRest
          $result += $communities.list
        }
    
        if($ExactMatch -and $Community){
            $result = $result | where{$_.name -match (($Community | %{"^$($_)$"}) -join '|')}
        }
    
        $result | where{$_.resources.html.ref -match ($typeMatch -join '|')} |
        Sort-Object -Property placeid -Unique 
    }
  }
}

function Get-VMTNContent
{
    [cmdletbinding(SupportsShouldProcess=$true)]
    param(
    [string[]]$Keyword,
    [DateTime]$Start,
    [DateTime]$Finish,
    [PSObject]$Author,
    [switch]$AuthorExact,
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [alias('placeid')]
    [PSObject[]]$Community,
    [switch]$CommunityExact,
    [switch]$SearchCommunityChildren = $false,
    [switch]$SearchSubjectOnly,
    [ValidateSet('discussion','document','post',ignorecase=$False)]
    [string[]]$ContentType = 'discussion',
    [ValidateSet('Relevance','UpdateDescending','UpdateAscending',ignorecase=$False)]
    [string]$SortOrder = 'Relevance',
    [long]$MaxSamples = $script:MaxCount
  )

  Process{
    $ReturnScore = $false
    $filter = @("count=$([math]::Min($script:maxCount,$MaxSamples))")

    if($Keyword){
        $searchAll = ($Keyword | %{[uri]::EscapeDataString($_)}) -join ','
        $filter += "filter=search($($searchAll))"
    }

    if($Author){
        if($Author -is [String]){
            if($AuthorExact){
                $Author = Get-VMTNAuthor -Author $Author -ExactMatch
            }
            else{
                $Author = Get-VMTNAuthor -Author $Author
            }
        }
        $filter += "filter=author(/people/$($Author.id))"
    }

    switch($SortOrder){
        'Relevance' {
            $filter += "sort=relevanceDesc"
            $ReturnScore = $true
        }
        'UpdateDescending' {
            $filter += "sort=updatedDesc"
        }
        'UpdateAscending' {
            $filter += "sort=updatedAsc"
        }
    }

    if($ReturnScore){
        $filter += "returnScore=true"
    }

    if($Community){
        $objCommunity = @()
        $Community | %{
            if($_ -is [String]){
                if($CommunityExact){
                    $objCommunity += (Get-VMTNCommunity -Community $_ -ExactMatch)
                }
                else{
                    $objCommunity += (Get-VMTNCommunity -Community $_)
                }
            }
            else{
                $objCommunity += $_
            }
        }
        $filter += "filter=place($(($objCommunity | %{"/places/$($_.placeID)"}) -join ','))"
    }

    if($SearchCommunityChildren){
        $filter += "filter=depth(CHILDREN)"
    }

    if($SearchSubjectOnly){
        $filter += "filter=subjectonly"
    }

    $filter += "filter=type($($ContentType -join ','))"

    if($Start){
        $aTimeStr = [uri]::EscapeDataString($Start.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
        $filter += "filter=after($aTimeStr)"
    }
    if($Finish){
        $bTimeStr = [uri]::EscapeDataString($Finish.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
        $filter += "filter=before($bTimeStr)"
    }
  
    $filterStr = $filter -join '&'
    $restStr = "search/contents"

    $sRest = @{
      Uri = ($script:VMTNUri,$script:JiveRest,$restStr -join '/'),$filterStr -join '?'
      Method = 'Get'
    }

    if($pscmdlet.ShouldProcess($sRest['Uri'], "Search VMTN")){
        $result = @()
        $content = Get-VMTNRest @sRest
        $result += $content.list

        while($content.links.next -and $result.Count -lt $MaxSamples){
          $sRest.Uri = $content.links.next
          $content = Get-VMTNRest @sRest
          $result += $content.list
        }
    
        $result[0..($MaxSamples-1)]
    }
  }
}

function Get-VMTNAuthor
{
  [cmdletbinding(SupportsShouldProcess=$true)]
  param(
    [string[]]$Author = '*',
    [DateTime]$CreatedAfter,
    [DateTime]$CreatedBefore,
    [DateTime]$UpdatedAfter,
    [DateTime]$UpdateBefore,
    [DateTime]$ProfileUpdatedAfter,
    [DateTime]$ProfileUpdateBefore,
    [switch]$ExactMatch = $false,
    [long]$MaxSamples = $script:MaxCount
  )

  Process{
    $filter = @("count=$([math]::Min($script:maxCount,$MaxSamples))")

    if($CreatedAfter){
        $aTimeStr = [uri]::EscapeDataString($CreatedAfter.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
        if($CreatedBefore){
            $bTimeStr = [uri]::EscapeDataString($CreatedBefore.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
            $filter += "filter=published($($aTimeStr),$($bTimeStr))"    
        }
        else{
            $filter += "filter=published($($aTimeStr))"    
        }
    }
    if($UpdatedAfter){
        $aTimeStr = [uri]::EscapeDataString($UpdatedAfter.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
        if($UpdatedBefore){
            $bTimeStr = [uri]::EscapeDataString($UpdatedBefore.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
            $filter += "filter=updated($($aTimeStr),$($bTimeStr))"    
        }
        else{
            $filter += "filter=updated($($aTimeStr))"    
        }
    }
    if($ProfileUpdatedAfter){
        $aTimeStr = [uri]::EscapeDataString($ProfileUpdatedAfter.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
        if($ProfileUpdatedBefore){
            $bTimeStr = [uri]::EscapeDataString($ProfileUpdatedBefore.ToString('yyyy-MM-ddTHH:mm:ss.fffzz00'))
            $filter += "filter=lastProfileUpdate($($aTimeStr),$($bTimeStr))"    
        }
        else{
            $filter += "filter=lastProfileUpdate($($aTimeStr))"    
        }
    }

    if($ExactMatch){
        $filter += "filter=nameonly"
    }

    $restStr = "search/people"

    foreach($individualAuthor in $Author){
        $filterStr = $filter + "filter=search($([uri]::EscapeDataString($individualAuthor)))" -join '&'
        
        $sRest = @{
          Uri = ($script:VMTNUri,$script:JiveRest,$restStr -join '/'),$filterStr -join '?'
          Method = 'Get'
        }
    
        if($pscmdlet.ShouldProcess($sRest['Uri'], "Search VMTN for Author")){
            $result = @()
            $people = Get-VMTNRest @sRest
            $result += $people.list
        
            while($people.links.next -and $result.Count -lt $MaxSamples){
              $sRest.Uri = $people.links.next
              $people = Get-VMTNRest @sRest
              $result += $people.list
            }
        
            if($ExactMatch -and $Author){
                $result = @($result | where{$_.displayName -match "$(($Author | %{""^$($_)$""}) -join '|')"})
            }
        
            $result[0..($MaxSamples-1)]
        }
    }
  }
}
