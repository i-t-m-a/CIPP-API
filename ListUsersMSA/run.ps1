using namespace System.Net
# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

$selectlist = 'id', 'accountEnabled', 'businessPhones', 'city', 'createdDateTime', 'companyName', 'country', 'department', 'displayName', 'faxNumber', 'givenName', 'isResourceAccount', 'jobTitle', 'mail', 'mailNickname', 'mobilePhone', 'onPremisesDistinguishedName', 'officeLocation', 'onPremisesLastSyncDateTime', 'otherMails', 'postalCode', 'preferredDataLocation', 'preferredLanguage', 'proxyAddresses', 'showInAddressList', 'state', 'streetAddress', 'surname', 'usageLocation', 'userPrincipalName', 'userType', 'assignedLicenses', 'onPremisesSyncEnabled', 'LicJoined', 'Aliases', 'primDomain', 'Tenant', 'CippStatus'
# Write to the Azure Functions log stream.
Write-Host 'PowerShell HTTP trigger function processed a request.'
$ConvertTable = Import-Csv Conversiontable.csv | Sort-Object -Property 'guid' -Unique

Set-Location (Get-Item $PSScriptRoot).Parent.FullName
# Interact with query parameters or the body of the request.
$TenantFilter = $Request.Query.TenantFilter
$GraphFilter = $Request.Query.graphFilter
$userid = $Request.Query.UserID

$GraphRequest = if ($TenantFilter -ne 'AllTenants') {
    New-GraphGetRequest -uri "https://graph.microsoft.com/beta/users/$($userid)?`$top=999&`$select=$($selectlist -join ',')&`$filter=$GraphFilter&`$count=true" -tenantid $TenantFilter -ComplexFilter | Select-Object $selectlist | ForEach-Object {
        $_.onPremisesSyncEnabled = [bool]($_.onPremisesSyncEnabled)
        $_.Aliases = $_.Proxyaddresses -join ', '
        $SkuID = $_.AssignedLicenses.skuid
        $_.LicJoined = ($ConvertTable | Where-Object { $_.guid -in $skuid }).'Product_Display_Name' -join ', '
        $_.primDomain = ($_.userPrincipalName -split '@' | Select-Object -Last 1)
        $_
    }
}
else {
    $Table = Get-CIPPTable -TableName 'cacheusers'
    $Rows = Get-AzDataTableEntity @Table | Where-Object -Property Timestamp -GT (Get-Date).AddHours(-1)
    $Rows = $Rows.Data | ConvertFrom-Json  | 
    Where-Object { 
    
        foreach ($o in $MSAOUs.OU)
        {
            $ouToMatch = $o.Split(',')[0]
            $OU = $_.onPremisesDistinguishedName -replace '^.+?(?<!\\),',''
            $indx = $OU.Split(',').IndexOf($ouToMatch)
            if ($indx -gt 0)
            {
                $OU.Replace( "$([string]$OU.Split(',')[$indx-1]),",'') -in $MSAOUs.OU
            }
            elseif ($OU -like "*$o*")
            {
                $true
            }
        }
    }

    if (!$Rows) {
        $Queue = New-CippQueueEntry -Name 'Users' -Link '/identity/administration/users?customerId=AllTenants'
        Push-OutputBinding -Name Msg -Value "users/$($userid)?`$top=999&`$select=$($selectlist -join ',')&`$filter=$GraphFilter&`$count=true"
        [PSCustomObject]@{
            Tenant  = 'Loading data for all tenants. Please check back after the job completes'
            QueueId = $Queue.RowKey
        }
    }         
    else {
        $Rows.Data | ConvertFrom-Json | Select-Object $selectlist | ForEach-Object {
            $_.onPremisesSyncEnabled = [bool]($_.onPremisesSyncEnabled)
            $_.Aliases = $_.Proxyaddresses -join ', '
            $SkuID = $_.AssignedLicenses.skuid
            $_.LicJoined = ($ConvertTable | Where-Object { $_.guid -in $skuid }).'Product_Display_Name' -join ', '
            $_.primDomain = ($_.userPrincipalName -split '@' | Select-Object -Last 1)
            $_
        }
    }
}

# MSA Org Units
#$MSA = Get-Content msa
$MSATable = Get-CIPPTable -TableName 'msaOrgUnits'
$MSAOUs = (Get-AzDataTableEntity @MSATable | Select-Object 'OU','Tenant','TenantId','UPNSuffix') 
if ($TenantFilter -ne 'AllTenants') { $MSAOUs = $MSAOUs | Where-Object {$_.Tenant -eq $TenantFilter} }

$MSAExcludedTable = Get-CIPPTable -TableName 'msaExcludedUsers'
$MSAExclusions = (Get-AzDataTableEntity @MSAExcludedTable | Select-Object 'mail','displayName') 

# Associate values to output bindings by calling 'Push-OutputBinding'.
$GraphRequest = $GraphRequest | Where-Object { ($_.accountEnabled -eq $true) } 
$GraphRequest = $GraphRequest | Where-Object { ( $_.mail -notin ($MSAExclusions.mail) ) }  
$GraphRequest = $GraphRequest | Where-Object { ( $_.userPrincipalName -notlike "*#EXT#*" ) } 

$GraphRequest = $GraphRequest | 
Where-Object { 

    foreach ($o in $MSAOUs.OU)
    {
        $ouToMatch = $o.Split(',')[0]
        $OU = $_.onPremisesDistinguishedName -replace '^.+?(?<!\\),',''
        $indx = $OU.Split(',').IndexOf($ouToMatch)
        if ($indx -gt 0)
        {
            $OU.Replace( "$([string]$OU.Split(',')[$indx-1]),",'') -in $MSAOUs.OU
        }
        elseif ($OU -like "*$o*")
        {
            $true
        }
    }
}

#$MSAUserCache = Get-CIPPTable -TableName 'msaUserCache'
#$MSAUserCache += ($GraphRequest | Select-Object 'LicJoined','displayName','mail')
#Update-AzDataTableEntity @TenantsTable -Entity $GraphRequest

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($GraphRequest)
    })