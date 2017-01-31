$packageName = 'keeweb'
$softwareName = 'keeweb*'
$installerType = 'exe'  

$silentArgs = '/S'
# Seems weird, but actually the uninstaller always returns 2 as exit code 
$validExitCodes = @(2)

[array]$key = Get-UninstallRegistryKey -SoftwareName $softwareName

if ($key.Count -eq 1) {
    $key | % { 
        # The chocolatey uninstaller function when used in combination of a
        # registry key has issues with NSIS and InnoSetup installers.
        # Circumvent the problem until this bug gets fixed:
        # https://github.com/chocolatey/choco/issues/1039
        $file = "$($_.UninstallString.Trim('"'))"

        Uninstall-ChocolateyPackage -PackageName $packageName `
                                    -FileType $installerType `
                                    -SilentArgs "$silentArgs" `
                                    -ValidExitCodes $validExitCodes `
                                    -File "$file"
    }
} elseif ($key.Count -eq 0) {
    Write-Warning "$packageName has already been uninstalled by other means."
} elseif ($key.Count -gt 1) {
    Write-Warning "$key.Count matches found!"
    Write-Warning "To prevent accidental data loss, no programs will be uninstalled."
    Write-Warning "Please alert package maintainer the following keys were matched:"
    $key | % {Write-Warning "- $_.DisplayName"}
}
