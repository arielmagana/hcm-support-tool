[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$targetEnv,

    [Parameter(Mandatory)]
    [string]$hcmUser,

    [Parameter(Mandatory)]
    [SecureString]$hcmPassword

)

function Get-Config {
    [Parameter(Mandatory)]
    [string]$targetEnv
    
    $config = Get-Content "$env:workingDirectory/config/config.json" | Out-String | ConvertFrom-Json

    if ($null -eq $config.$targetEnv) {
        Write-Error "$targetEnv is not configured in this tool, add the necesary configuration in $env:workingDirectory/config/config.json" -ErrorAction Stop
    }
    
    return $config.$targetEnv
}

function Get-UserList {

    return Get-Content "$env:workingDirectory/config/hcm-svc-users.json" | Out-String | ConvertFrom-Json
}

function Initialize-Header {

    [CmdletBinding()]
    param (
        [string]$User,
        [SecureString]$Password
    )
      
    $pair = "$($User):$(ConvertFrom-SecureString -SecureString $Password -AsPlainText)"

    # Generating encoded credentials for REST call
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

    $basicAuthValue = "Basic $encodedCreds"

    $Headers = @{
        Authorization = $basicAuthValue
    }

    return $Headers
}

function Get-UserID {
    # Call REST API for the username
    [CmdletBinding()]
    param (
        [string]$Uri
    )

    $Response = try {
        Invoke-WebRequest -Uri $Uri -Headers $Headers -ErrorAction Stop
    }
    catch [System.Net.WebException] {
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }

    if ($Response.BaseResponse.StatusCode.Value__ -eq 200) {
        $myJson = $Response.Content | ConvertFrom-Json

        $userID = $myJson.Resources.id
    }
    else {
        $userID = "x"
    }

    return $userID
}

function Set-HCMUserPassword {
    [CmdletBinding()]
    param (
        [string]$Uri,
        [string] $secret
    )

    $postParams = @"
{
    "schemas": [
        "urn:scim:schemas:core:2.0:User"
    ],
    "password": "$($secret)"
}
"@
    
    $response = try {
        Invoke-WebRequest -Uri "https://$($targetEnvConfig.podUrl)/hcmCoreSetupApi/scim/Users/$($SvcUer.guid)" -Headers $Headers -ContentType "application/json" -Method PATCH -Body $postParams -ErrorAction Stop
    }
    catch [System.Net.WebException] {
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }

    return $response
}

# Initializing variables
Write-Output "Loading config file for $targetEnv"

$targetEnvConfig = Get-Config $targetEnv

Write-Output "$($targetEnvConfig | ConvertTo-Json)"

try {
    Write-Output "Initializing.... trying to connect to Azure"

    Connect-AzAccount -Subscription $targetEnvConfig.subscription -ErrorAction Stop

    Write-Output "Connected successfully!"
    $Headers = Initialize-Header -User $hcmUser -Password $hcmPassword

    Write-Output "Getting list of HCM users and fetching GUID, if needed..."
    $HCMUsers = Get-UserList


    foreach ($SvcUer in $HCMUsers) {
        if ($SvcUer.guid -eq "" -or $SvcUer.guid -eq "x") {
            Write-Output "$($SvcUer.user) doesn't have GUID in config file, fetching from HCM"
            # We don't have this user's GUID in file, get the information
            $Uri = "https://$($targetEnvConfig.podUrl)/hcmCoreSetupApi/scim/Users?filter=userName%20eq%20%22$($SvcUer.user)%22"

            $SvcUer.guid = Get-UserID -Uri $Uri
        }

        $HCMUsers | Where-Object{$_.name -eq $SvcUer.user} | ForEach-Object{$_.guid = $SvcUer.guid}

        # Get the password from KeyVault
        $replacedUserName = $SvcUer.user -replace '[_\.]', '-'
        $vaultName = "$($targetEnvConfig.vaultSuffix)-$($SvcUer.vaultSuffix)"

        $SecretName = "hcm-$($targetEnvConfig.secretSuffix)---$replacedUserName"

        try {
            $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $SecretName -AsPlainText -ErrorAction Stop
        }
        catch {
            Write-Output "Failed to get Secret from $vaultName for $($SvcUer.user), secret name used: $SecretName"
            $secret = $null
        }

        if ($null -ne $secret -and $secret -ne "") {
            Write-Output "Secret fetched successfully for: $($SvcUer.user)"

            $Uri = "https://$($targetEnvConfig.podUrl)/hcmCoreSetupApi/scim/Users/$($SvcUer.guid)"

            Write-Output "Calling password reset API"

            $patchResponse = Set-HCMUserPassword -Uri $Uri -secret $secret
            
            Write-Output "Response: $($patchResponse.BaseResponse.StatusCode.Value__) - $($patchResponse.BaseResponse.StatusCode)"
        }
    }

    $HCMUsers | ConvertTo-Json -Depth 32 | Set-Content "$env:workingDirectory/config/hcm-svc-users.json"
}
catch {
    Write-Output "Unexpected error:"
    Write-Output "$_"
}