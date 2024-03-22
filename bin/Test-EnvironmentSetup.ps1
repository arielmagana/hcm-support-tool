$errorMessages = @()
$requiredModules = @('Az', 'ImportExcel')

Write-Output "Validating Powershell Version"

if ($PSVersionTable.PSVersion.Major -le 6) {
    $errorMessages += "You are running this in an incompatible PowerShell version, please install PowerShell 7"
}

Write-Output "Validating Installed Modules"
foreach ($currentItemName in $requiredModules) {
    try {
        Get-InstalledModule -Name $currentItemName -ErrorAction Stop
    }
    catch {
        $errorMessages += "`"$currentItemName`" Module is missing, please run the following command: Install-Module -Name $currentItemName -Repository PSGallery -Force"
    }
}

if ($errorMessages.Count -ge 1) {
    Write-Error "There are missing modules in your environment:`n$errorMessages" -ErrorAction Stop
}
else {
    Write-Output "`nAll validations passed"
}