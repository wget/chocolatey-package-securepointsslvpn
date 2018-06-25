import-module au

$releases = 'https://github.com/Securepoint/openvpn-client/releases'

function global:au_BeforeUpdate { Get-RemoteFiles -Purge -NoSuffix -Algorithm 'SHA512'}

function global:au_SearchReplace {
    @{
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]package\s*=\s*)('.*')" = "`$1'$($Latest.url32)'"
            "(?i)(^\s*package\s*=\s*`"[$]toolsDir\\).*" = "`${1}$($Latest.filename32)`""
			"(^[$]checksum\s*=\s*)('.*')" = "`$1'$($Latest.checksum32)'"
        }
    }
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
        url32 = $url32;
        filename32 = $filename32;
        version = $version;
    }
}

update -ChecksumFor none
