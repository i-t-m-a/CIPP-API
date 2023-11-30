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


# Remove from Azure table

$Excluded = {
    displayName = $displayName
    mail = $userid 
}

$MSA_Exclude_Table = Get-CIPPTable -TableName 'msaExcludedUsers'
Update-AzDataTableEntity @MSA_Exclude_Table -Entity ([pscustomobject]$Excluded)







Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = @($GraphRequest)
    })