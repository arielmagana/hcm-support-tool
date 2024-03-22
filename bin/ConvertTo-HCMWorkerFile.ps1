$tempDir = "$env:workingDirectory/temp"
$excelFileName = "$tempDir/Email Update_Email Update.xlsx"
$flatFileName = "$tempDir/Worker.dat"
$zipFile = "$tempDir/EmailUpdate.zip"
$dummyEmail = "ePopleTestEmailNotification@constellation.com"

Write-Output "Starting Worker file conversion from Excel to CSV"

$workersData = Import-Excel -Path $excelFileName

Write-Output "Import completed, cleaning up data"

# We need to remove/mask the user's email and instead use a dummy one
$workersData | ForEach-Object {$_.EmailAddress = $dummyEmail}

# The export is creating some records with DateTo dates that will cause the import to fail and need to be corrected
$workersData | Where-Object { $_.DateTo -like "*4713/*" } | ForEach-Object { $_.DateTo = $_.DateTo -replace '4713/','4712/' }
$workersData | Where-Object { $_.DateTo -like "*4729/*" } | ForEach-Object { $_.DateTo = $_.DateTo -replace '4729/','4712/' }

Write-Output "Cleanup completed, exporting to flat file"

# Export all records but the last one to pipe delmited flat file
$workersData | Select-Object -SkipLast 1 | Export-Csv -Path "$flatFileName" -Delimiter '|' -NoTypeInformation -UseQuotes Never

Compress-Archive -Path $flatFileName -DestinationPath $zipFile -Force

Write-Output "Export completed"