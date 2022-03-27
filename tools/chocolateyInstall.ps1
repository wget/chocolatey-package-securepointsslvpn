$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Load custom functions
. "$toolsDir\utils\utils.ps1"

Write-Host "Getting the state of the current Securepoint VPN service (if any)..."
# Needed to reset the state of the service if upgrading from a previous version
try {
  $previousService = GetServiceProperties "Securepoint VPN"
} catch {
  Write-Host "No previous Securepoint VPN service detected."
}

$packageArgs = @{
  packageName            = 'securepointsslvpn'
  fileType               = 'msi'
  file                   = "$toolsDir\openvpn-client-installer-2.0.36.msi"
  file64                 = "$toolsDir\openvpn-client-installer-2.0.36.msi"
  checksum               = '3BAD2C2F06D1E449D5F1A6E9F9F097ACE5E032F1F7DA2B996503929F9E3D1CEE343AEFE96CB29AC3F87639A53CC38812CC648429EFC18356731C5250A1D2ACBA'
  checksum64             = '3BAD2C2F06D1E449D5F1A6E9F9F097ACE5E032F1F7DA2B996503929F9E3D1CEE343AEFE96CB29AC3F87639A53CC38812CC648429EFC18356731C5250A1D2ACBA'
  checksumType           = 'sha256'
  checksumType64         = 'sha256'
  silentArgs             = "/qn /norestart /l*v `"$($env:TEMP)\$($packageName).$($env:chocolateyPackageVersion).MsiInstall.log`" TRANSFORMS=`":en-us.mst`""
  validExitCodes         = @(0, 3010, 1641)
  softwareName           = 'securepoint*ssl*vpn*'
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
