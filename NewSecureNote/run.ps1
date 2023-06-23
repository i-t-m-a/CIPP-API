using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$APIName = $TriggerMetadata.FunctionName
Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Accessed this API" -Sev "Debug"
$Results = [System.Collections.ArrayList]@()
$noteObj = $Request.body
# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."
$FunctionName = 'NewSecureNote'
$ModuleName = 'NoteShred'
# Import AzureAD PS module
$PSModulePath = "D:\home\site\wwwroot\$FunctionName\$ModuleName\PS.NoteShred.psd1"
Import-module $PSModulePath

try {

    $req = `
    New-SecureNote  -Title $noteObj.Title `
                    -Hint $noteObj.Hint `
                    -Password $noteObj.Password  `
                    -Content $noteObj.Content `
                    -Recipient $noteObj.Recipient  `
                    -API_Key $env:NoteShredAPI

    $noteId = ($req.Content|ConvertFrom-Json).result.token
    $note = Get-SecureNote -NoteId $noteId -API_Key $env:NoteShredAPI
    $noteURL = ($note.Content|ConvertFrom-Json).result.url
    $body = $results.add("Your note has been created. URL: $noteURL" )

}
catch {
    $body = $results.add("Failed to create user. $($_.Exception.Message)" )
}

$body = @{"Results" = @($results) }
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $Body
    })
