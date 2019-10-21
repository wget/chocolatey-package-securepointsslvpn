import-module au

$releases = 'https://github.com/Securepoint/openvpn-client/releases'

function global:au_BeforeUpdate { Get-RemoteFiles -Purge -NoSuffix -Algorithm 'SHA512'}

function global:au_SearchReplace {
  @{
    ".\legal\VERIFICATION.txt" = @{
      "(?i)(32-Bit.+)\<.*\>" = "`${1}<$($Latest.URL32)>"
      "(?i)(checksum type:\s+).*" = "`${1}$($Latest.ChecksumType32)"
      "(?i)(checksum32:\s+).*" = "`${1}$($Latest.Checksum32)"
    }
    ".\tools\chocolateyInstall.ps1" = @{
      "(?i)(^\s*file\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName32)`""
      "(?i)(^\s*file64\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.FileName32)`""
      "(?i)(^\s*checksum\s*=\s*)('.*')"    = "`$1'$($Latest.Checksum32)'"
      "(?i)(^\s*checksum64\s*=\s*)('.*')"  = "`$1'$($Latest.Checksum32)'"
    }
  }
}

function global:au_GetLatest {

  # Get latest published version
  $jsonAnswer = (Invoke-WebRequest -Uri "https://api.github.com/repos/Securepoint/openvpn-client/releases/latest" -UseBasicParsing).Content | ConvertFrom-Json

  $version = $jsonAnswer.tag_name -Replace '[^0-9.]'

  # Select the msi assets. [0] is just in case they are several ones in the future.
  $msiAsset = $jsonAnswer.assets.where{$_.name -like '*.msi*' }[0]

  $msiUrl = $msiAsset.browser_download_url
  $msiFilename = $msiAsset.name

  return @{
    url32 = $msiUrl;
    filename32 = $msiFilename;
    version = $version;
  }
}

update -ChecksumFor none
