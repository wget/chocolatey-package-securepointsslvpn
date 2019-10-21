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
  file                   = "$toolsDir\"
  file64                 = "$toolsDir\"
  checksum               = ''
  checksum64             = ''
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