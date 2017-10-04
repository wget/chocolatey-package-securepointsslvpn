import-module au

$releases = 'https://github.com/Securepoint/openvpn-client/releases'

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url\s*=\s*)('.*')" = "`$1'$($Latest.url32)'"
			"(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.checksum)'"
        }
    }
}

function au_BeforeUpdate {
    # We can't rely on Get-RemoteChecksum as we want to have the files locally
    # as well and this function will download a local copy of the file, just to
    # compute its hashes, then drop it. We can't rely completely on
    # Get-RemoteFiles either as that function is only taking Latest URLs (x64
    # and x32) into account. The signatures are not supported.
    # src.: https://github.com/majkinetor/au/tree/master/AU/Public
    $client = New-Object System.Net.WebClient
    $toolsPath = Resolve-Path tools

    $filePath = "$toolsPath/securepointsslvpnInstall.exe"
    Write-Host "Downloading installer to '$filePath'..."
    $client.DownloadFile($url, $filePath)
    $Latest.checksum = Get-FileHash $filePath -Algorithm sha512 | % Hash
}

function global:au_GetLatest {

    $downloadedPage = Invoke-WebRequest -Uri $releases -UseBasicParsing

    $baseUrl = $([System.Uri]$releases).Authority

    $url32 = $downloadedPage.links | ? href -match '.exe$' | select -First 1 -expand href
    if ($url32.Authority -cnotmatch $baseUrl) {
        $url32 = 'https://' + $baseUrl + $url32
    }
    $url32SegmentSize = $([System.Uri]$url32).Segments.Length
    $filename32 = $([System.Uri]$url32).Segments[$url32SegmentSize - 1]

    $version = [regex]::match($url32,'/[A-Za-z-]+-([0-9]+.[0-9]+.[0-9]+).*exe').Groups[1].Value

    return @{
        version = $version;
        url32 = $url32;
    }
}

update -ChecksumFor none
