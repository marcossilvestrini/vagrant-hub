[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PublicationFile,

    [Parameter()]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
    [string] $IpAddress = '192.168.0.140',

    [Parameter()]
    [string] $Bridge
)

$ErrorActionPreference = 'Stop'
$publicationPath = (Resolve-Path -LiteralPath $PublicationFile -ErrorAction Stop).Path
$publication = Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json
if ($publication.url -notmatch '^https://') { throw 'O JSON não contém uma URL HTTPS pública.' }
if ($publication.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { throw 'O JSON não contém um SHA-256 válido.' }
$boxPath = (Resolve-Path -LiteralPath $publication.local_path -ErrorAction Stop).Path

$vagrant = Get-Command vagrant -ErrorAction SilentlyContinue
if (-not $vagrant) { throw 'Vagrant não foi encontrado no PATH.' }

$testDirectory = Join-Path $PSScriptRoot 'onedrive-test'
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
$downloadUrl = [string] $publication.url
if ($downloadUrl.Contains('?')) { $downloadUrl += '&download=1' } else { $downloadUrl += '?download=1' }
$escapedUrl = ConvertTo-Json -InputObject $downloadUrl -Compress
$escapedHash = ConvertTo-Json -InputObject ([string] $publication.sha256) -Compress
$escapedGuestIp = ConvertTo-Json -InputObject $IpAddress -Compress
$escapedBoxName = ConvertTo-Json -InputObject ("onedrive-test/$($publication.name)") -Compress
$escapedIp = ConvertTo-Json -InputObject $IpAddress -Compress
$escapedLocalBoxUrl = ConvertTo-Json -InputObject ([uri]::new($boxPath).AbsoluteUri) -Compress
$bridgeLine = if ($Bridge) {
    $escapedBridge = ConvertTo-Json -InputObject $Bridge -Compress
    "  config.vm.network `"public_network`", ip: $escapedIp, bridge: $escapedBridge"
}
else {
    "  config.vm.network `"public_network`", ip: $escapedIp"
}

$vagrantfile = @"
Vagrant.configure("2") do |config|
  config.vm.box = $escapedBoxName
  config.vm.box_url = $escapedLocalBoxUrl
  config.vm.box_check_update = false
$bridgeLine
  config.vm.provision "shell", inline: <<-'SHELL'
set -eu
url=$escapedUrl
expected=$escapedHash
ip_expected=$escapedGuestIp
actual_ips=`$(ip -4 -o addr show scope global)
printf 'Guest IPv4: %s\n' "`$actual_ips"
if ! printf '%s\n' "`$actual_ips" | grep -Fq "`$ip_expected/"; then
  echo "Interface IP `$ip_expected was not assigned" >&2
  exit 1
fi
if command -v curl >/dev/null 2>&1; then
  curl --fail --location --retry 3 --retry-all-errors --progress-bar --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36' --cookie-jar /tmp/onedrive.cookies --cookie /tmp/onedrive.cookies "`$url" -o /tmp/onedrive.box
elif command -v wget >/dev/null 2>&1; then
  wget --tries=4 --keep-session-cookies --save-cookies /tmp/onedrive.cookies --load-cookies /tmp/onedrive.cookies --output-document=/tmp/onedrive.box "`$url"
else
  echo 'curl ou wget não encontrado na VM' >&2
  exit 1
fi
printf '%s  %s\n' "`$expected" /tmp/onedrive.box | sha256sum --check -
SHELL
  config.vm.provider "$($publication.provider)" do |vm|
    # VM temporária para validar o download anônimo.
  end
end
"@
Set-Content -LiteralPath (Join-Path $testDirectory 'Vagrantfile') -Value $vagrantfile -Encoding UTF8

Push-Location -LiteralPath $testDirectory
$testSucceeded = $false
try {
    Write-Host "Iniciando VM temporária com interface pública $IpAddress..." -ForegroundColor Cyan
    Write-Host 'A VM baixará a box do OneDrive sem usar o token OAuth do publicador.'
    & $vagrant.Source up --provider=$($publication.provider) --provision
    if ($LASTEXITCODE -ne 0) { throw "vagrant up falhou (código $LASTEXITCODE)." }
    $testSucceeded = $true
    Write-Host 'Download anônimo e validação SHA-256 concluídos dentro da VM.' -ForegroundColor Green
}
finally {
    if ($testSucceeded) {
        & $vagrant.Source destroy -f
        if ($LASTEXITCODE -ne 0) { Write-Warning 'O teste passou, mas não consegui destruir a VM temporária.' }
    }
    else {
        Write-Warning "A VM/arquivos de diagnóstico foram preservados em $testDirectory."
    }
    Pop-Location
}





