$packageName= 'securepointsslvpn'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://github.com/Securepoint/openvpn-client/releases/download/2.0.18/openvpn-client-installer-2.0.18.exe'
$checksum   = '11c89ae60ebff7aeb847f1b18418ceae38c6651504cd8334a51c6a28c71712e41393a33962c68879802386eeedbceff8fe400eba8a5355a200d8e201bd479ceb'

# Load custom functions
. "$toolsDir\utils\utils.ps1"

Import-Module "$toolsDir\..\..\autoit.commandline\tools\install\AutoItX\AutoItX.psd1"
if (!(Get-Command 'Invoke-AU3Run' -ErrorAction SilentlyContinue)) {
    throw "The AutoItX PowerShell module was not imported properly."
}

Write-Host "Downloading package installer..."
$packageFileName = Get-ChocolateyWebFile `
    -PackageName $packageName `
    -FileFullPath $(Join-Path $(CreateTempDirPackageVersion) "$($packageName)Install.exe")`
    -Url $url `
    -Checksum $checksum `
    -ChecksumType 'sha512'

# Invoke-AU3Run returns an Int32 corresponding to the PID of the process
[Int32]$installerPid = Invoke-AU3Run -Program "$packageFileName"
Wait-AU3Win -Title "SSLVPN Installer" | Out-Null
$winHandle = Get-AU3WinHandle -Title "SSLVPN Installer"

# Activate the window
Show-AU3WinActivate -WinHandle $winHandle | Out-Null

# Press Enter as the OK button has the focus. Do not care if the German language
# is used, we will anyway override it when we will get the .msi file.
Send-AU3Key -Key "{ENTER}" | Out-Null

Write-Host "Recovering the msi file from the installer..."
# The msi file is located at %TEMP%\SecurepointSSLVPN.msi
$msiTempFile = Join-Path `
    $([Environment]::ExpandEnvironmentVariables('%TEMP%')) `
    'SecurepointSSLVPN.msi'
$msiPermanentFile = Join-Path `
    $(CreateTempDirPackageVersion) `
    "$($packageName)Install.msi"
Copy-Item $msiTempFile $msiPermanentFile

# The installer runs cmd which itself runs the msiexec which runs the .msi.
# The purpose here is to kill the msiexec process. When the latter willl return,
# the cmd and the installer process will quit immediately.
[array]$childPid = GetChildPid -id $installerPid
if ($childPid.Count -eq 0) {
    throw "Unable to find the pid of the cmd executable run by the installer."
}
[array]$childPid = GetChildPid -id $childPid[0].ProcessId
if ($childPid.Count -eq 0) {
    throw "Unable to find the pid of the msiexec executable run by the cmd process."
}

# Kill the msi
Stop-Process -Id $childPid[0].ProcessId -Force

Write-Host "Getting the state of the current Securepoint VPN service (if any)..."
# Needed to reset the state of the service if upgrading from a previous version
try {
    $previousService = GetServiceProperties "Securepoint VPN"
} catch {
    Write-Host "No previous Securepoint VPN service detected."
}

$packageArgs = @{
    packageName   = $packageName
    fileType      = 'msi'
    file          = $msiPermanentFile

    #MSI
    silentArgs    = "TRANSFORMS=`":en-us.mst`" /qn /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`"" # ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1 ADDDESKTOPICON=0 ADDSTARTMENU=0
    validExitCodes= @(0, 3010, 1641)
    softwareName  = $packageName
}

Install-ChocolateyInstallPackage @packageArgs

if ($previousService) {
    Write-Host "Resetting previous Securepoint VPN service to " `
        "'$($previousService.status)' and " `
        "'$($previousService.startupType)'..."
    SetServiceProperties `
        -name "Securepoint VPN" `
        -status "$($previousService.status)" `
        -startupType "$($previousService.startupType)"
}