Function Get-OneTimeCode
{
    #define parameters
    param([int]$PasswordLength = 20)
 
    #ASCII Character set for Password
    $CharacterSet = @{
            Uppercase   = (97..122) | Get-Random -Count 10 | % {[char]$_}
            Lowercase   = (65..90)  | Get-Random -Count 10 | % {[char]$_}
            Numeric     = (48..57)  | Get-Random -Count 10 | % {[char]$_}
            SpecialChar = (33..38)+(40..46)+(58..64)+(91..96)+(123..126) | Get-Random -Count 10 | % {[char]$_}
    }
 
    #Frame Random Password from given character set
    $StringSet = $CharacterSet.Uppercase + $CharacterSet.Lowercase + $CharacterSet.Numeric + $CharacterSet.SpecialChar
 
    -join(Get-Random -Count $PasswordLength -InputObject $StringSet)
}
function New-SecureNote 
{
    param
    (
        [string]$Title,
        [string]$ShredMethod=1,
        [string]$Hint,
        [string]$OneTimeCode = (Get-OneTimeCode),
        [string]$Content,
        [string[]]$Recipient,
        [string]$API_Key
    )

    $uri = "https://www.noteshred.com/api/v2/notes" 
    $head = @{Authorization = "Token token=$API_Key"}
    $note = @{
      title = $Title
      shred_method = $ShredMethod
      hint = $Hint
      password = $Password
      content = $Content
      recipients = $Recipient
    }

    Invoke-WebRequest -Uri $uri -Headers $head -Method Post -Body ($note|ConvertTo-Json) -ContentType "application/json" -UseBasicParsing
}

function Get-SecureNote 
{
    param
    (
        [string]$NoteId,
        [string]$API_Key
    )

    $uri = "https://www.noteshred.com/api/v2/notes/" + $NoteId
    $head = @{Authorization = "Token token=$API_Key"}
    
    Invoke-WebRequest -Uri $uri -Headers $head -Method Get -ContentType "application/json" -UseBasicParsing
}
