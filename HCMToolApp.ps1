[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$targetEnv,

    [Parameter(Mandatory)]
    [string]$hcmUser,

    [Parameter(Mandatory)]
    [SecureString]$hcmPassword

)

Write-Output "Initializing common configuration"
$env:workingDirectory = Get-Location
$binDir = "$env:workingDirectory/bin"

Write-Output "Run user environment validations"

& "$binDir/Test-EnvironmentSetup.ps1"

& "$binDir/Update-HCMUser.ps1" -targetEnv $targetEnv -hcmUser $hcmUser -hcmPassword $hcmPassword

& "$binDir/ConvertTo-HCMWorkerFile.ps1"

Write-Output "Post-Refresh steps completed"