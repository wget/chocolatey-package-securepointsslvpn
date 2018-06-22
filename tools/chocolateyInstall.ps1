$packageName= 'securepointsslvpn'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://github.com/Securepoint/openvpn-client/releases/download/2.0.22/openvpn-client-installer-2.0.22.exe'
$checksum   = 'f030d6d6708f98fae20d07ff87263c76a79650b84f17b55bb1a1e1d69ef1d630cbc3bc5c554a4bb8341777db397f42749f2d4c211469c73fa942beac632df8b3'

# Load custom functions
. "$toolsDir\utils\utils.ps1"

# The installer is bundled with an msi file, with certificates and with C++
# runtimes. We can't get the msi file directly. We have to run the
# installer executable first, then select the language and click OK.
# Just after, the .msi is unpacked to the %temp% directory under the
# following filename: SecurepointSSLVPN.msi

# The msi file provides several controls to customize the installation.
# After the msi file is unpacked. The installer immediately runs cmd which
# runs the msiexec which itself runs the .msi file.

# When this is the first installation, the user can customize the installation
# with the controls mentionned above. However, when the msi file has been
# already installed, the msi installation does not provide any way to control
# the install process anymore. The installation is run again automatically
# without anyway to control the process.

# Our initial purpose was to recover the msi file and execute it silently.
# First, we needed to kill the initial msi file. When the msi returns, the
# cmd and the installer processes quit immediately.

# However, when the msi file has already been installed, this causes several
# issues:
# - First, we cannot kill the msi file properly.
# - Second, reinstalling the msi when it has a filename different than the
#   msi product name, we are running into a 1316 error. "The product code
#   must be changed if any of the following are true for the update: [...]
#   The name of the .msi file has been changed."
#   We thus need to keep the filename securepointsslvpn.msi (not case
#   sensitive). src.: http://stackoverflow.com/a/21987987/3514658

# This is why we will first remove the previous installation to avoid issues.

# But first we need to receover the services state.
Write-Host "Getting the state of the current Securepoint VPN service (if any)..."
# Needed to reset the state of the service if upgrading from a previous version
try {
    $previousService = GetServiceProperties "Securepoint VPN"
} catch {
    Write-Host "No previous Securepoint VPN service detected."
}

Write-Host "Removing the previous installation to avoid issues..."
. "$toolsDir\chocolateyUninstall.ps1"

# To select the language in the installer, we need to use AutoIT scripts.
# Use AU3Info.exe to get Win32 control names. src.: https://goo.gl/Ndytjn
# If installed with chocolatey (autoit.commandline), AutoIT is installed as
# a Chocolatey dependency at:
# C:\ProgramData\Chocolatey\lib\autoit.commandline\tools\install
# In order to get the documentation of the AutoIt PowerShell cmdlets, we need
# to import the module with Import-Module.
# Import-Module C:\ProgramData\chocolatey\lib\autoit.commandline\tools\install\AutoItX\AutoItX.psd1
# The imported modules are only valid for the current script session.
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

Write-Host "Trying to recover the MSI file..."
# Invoke-AU3Run returns an Int32 corresponding to the PID of the process
[Int32]$installerPid = Invoke-AU3Run -Program "$packageFileName"
Wait-AU3Win -Title "SSLVPN Installer" | Out-Null
$winHandle = Get-AU3WinHandle -Title "SSLVPN Installer"
# Get the focus on the window
Show-AU3WinActivate -WinHandle $winHandle | Out-Null
# Even if we could override the language using the parameters to the msi file,
# we needed to detect text in the msi file run just after (we want English).
$controlHandle = Get-AU3ControlHandle -WinHandle $winHandle -Control Button3
Invoke-AU3ControlClick -WinHandle $winHandle -ControlHandle $controlHandle | Out-Null
# Press Enter as the OK button has the focus. 
Send-AU3Key -Key "{ENTER}" | Out-Null

Write-Host "Waiting for the MSI installer to launch..."
Wait-AU3Win -Title "Securepoint SSL VPN Setup" | Out-Null

Write-Host "Copying the MSI installer..."
# Do not use the environment variable, as the latter might get redefined (which
# happens in AppVeyor for example) and some installers might use the default
# TEMP location instead.
#$([Environment]::ExpandEnvironmentVariables('%TEMP%')) 
$msiTempFile = Join-Path `
    $([System.IO.Path]::GetTempPath()) `
    'SecurepointSSLVPN.msi'
$msiPermanentFile = Join-Path `
    $(CreateTempDirPackageVersion) `
    "$($packageName)Install.msi"
# Copy it to C:\Users\<user>\AppData\Local\Temp\chocolatey\securepointsslvpn\<version>
# Prevent to continue if the copy fails. By default every command relies on
# the $ErrorActionPreference. By default the latter is set on Continue (tested).
Copy-Item -Path "$msiTempFile" -Destination "$msiPermanentFile" -ErrorAction Stop

Write-Host "Killing the non silent MSI installer..."
[array]$childPid = GetChildPid -id $installerPid
Write-Debug "installer PID: $installerPid"
if ($childPid.Count -eq 0) {
    throw "Unable to find the pid of the cmd executable run by the installer."
}
Write-Debug "cmd PID: $($childPid[0].ProcessId)"
[array]$childPid = GetChildPid -id $childPid[0].ProcessId
if ($childPid.Count -eq 0) {
    throw "Unable to find the pid of the msiexec executable run by the cmd process."
}
# cmd has several childs PID. The PID of msiexec is usually the second one.
# Just to be sure, we are gonna kill all cmd childs.
$cmdChilds = $($childPid.Count)
Write-Debug "cmd childs number: $cmdChilds"
for ($i = 0; $i -lt $cmdChilds; $i++) {
    Write-Debug "Killing PID: $($childPid[$i].ProcessId)"
    Stop-Process -Id $childPid[$i].ProcessId -Force
}

Write-Host "Installing silently the recovered MSI installer..."
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