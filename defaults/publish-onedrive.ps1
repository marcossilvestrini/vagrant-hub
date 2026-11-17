[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $BoxPath,

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string] $RemoteName = 'onedrive',

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string] $RemoteFolder = 'vagrant',

    [Parameter()]
    [string] $VagrantfilePath,

    [Parameter()]
    [string] $PublicationPath,

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string] $CatalogNamespace = 'silvestrini',

    [Parameter()]
    [ValidateSet('x86_64', 'aarch64', 'arm64', 'i386', 'x86')]
    [string] $Architecture,

    [Parameter()]
    [string] $CatalogPath
)

$ErrorActionPreference = 'Stop'
$resolvedBox = Resolve-Path -LiteralPath $BoxPath -ErrorAction Stop
if (-not (Test-Path -LiteralPath $resolvedBox.Path -PathType Leaf) -or $resolvedBox.Path -notmatch '\.box$') {
    throw "Informe o caminho de um arquivo .box: $BoxPath"
}

$rcloneCommand = Get-Command rclone -ErrorAction SilentlyContinue
if ($rcloneCommand) {
    $rclone = $rcloneCommand.Source
}
elseif (Test-Path -LiteralPath 'E:\Apps\rclone\rclone.exe') {
    $rclone = 'E:\Apps\rclone\rclone.exe'
}
else {
    throw 'rclone não foi encontrado. Instale-o ou adicione-o ao PATH.'
}

$remotes = @(& $rclone listremotes 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Não foi possível listar os remotes do rclone: $($remotes -join "`n")"
}
if ($remotes -notcontains "$RemoteName`:") {
    throw "Remote '$RemoteName' não está configurado. Configure-o com 'rclone config' e autentique o OneDrive nesta máquina."
}

$boxFile = Get-Item -LiteralPath $resolvedBox.Path
$providerFolder = Split-Path -Leaf (Split-Path -Parent $boxFile.FullName)
$provider = switch ($providerFolder.ToLowerInvariant()) {
    'virtualbox' { 'virtualbox' }
    'vmware' { 'vmware_desktop' }
    default { throw "A box precisa estar em uma pasta provider 'virtualbox' ou 'vmware': $($boxFile.DirectoryName)" }
}
$version = Split-Path -Leaf (Split-Path -Parent $boxFile.DirectoryName)
$osName = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $boxFile.DirectoryName))
foreach ($segment in @($RemoteFolder, $osName, $version, $providerFolder)) {
    if ($segment -notmatch '^[A-Za-z0-9._-]+$' -or $segment -in @('.', '..')) {
        throw "Segmento de caminho inválido: '$segment'."
    }
}

$relativeRemotePath = ($RemoteFolder, 'boxes', $osName, $version, $providerFolder, $boxFile.Name) -join '/'
$remoteBox = "${RemoteName}:$relativeRemotePath"
$checksum = (Get-FileHash -LiteralPath $boxFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "Enviando $($boxFile.Name) para $remoteBox..." -ForegroundColor Cyan
& $rclone copyto $boxFile.FullName $remoteBox --progress
if ($LASTEXITCODE -ne 0) {
    throw "Upload para o OneDrive falhou (código $LASTEXITCODE)."
}

Write-Host 'Criando link anônimo somente para visualização/download...' -ForegroundColor Cyan
$linkOutput = @(& $rclone link $remoteBox --onedrive-link-scope anonymous --onedrive-link-type view 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Não foi possível criar o link público no OneDrive: $($linkOutput -join "`n")"
}
$shareUrl = $null
foreach ($line in $linkOutput) {
    if ([string] $line -match 'https://\S+') {
        $shareUrl = $Matches[0].TrimEnd('.', ',', ')')
    }
}
if (-not $shareUrl) {
    throw "rclone não retornou um link HTTPS: $($linkOutput -join "`n")"
}
$downloadUrl = if ($shareUrl.Contains('?')) { "$shareUrl&download=1" } else { "$shareUrl?download=1" }
$boxName = $osName
$vagrantBoxName = "$CatalogNamespace/$boxName"
if (-not $Architecture) {
    $architectureMatch = [regex]::Match($boxFile.Name, '-(?<architecture>x86_64|aarch64|arm64|i386|x86)\.')
    if (-not $architectureMatch.Success) {
        throw "Não foi possível determinar a arquitetura pelo nome do arquivo. Informe -Architecture: $($boxFile.Name)"
    }
    $Architecture = $architectureMatch.Groups['architecture'].Value
}
$vagrantArchitecture = switch ($Architecture) {
    'x86_64' { 'amd64' }
    'aarch64' { 'arm64' }
    'arm64' { 'arm64' }
    'i386' { 'i386' }
    'x86' { 'i386' }
}
$escapedBoxName = ConvertTo-Json -InputObject $vagrantBoxName -Compress
$escapedDownloadUrl = ConvertTo-Json -InputObject $downloadUrl -Compress
if ([string]::IsNullOrWhiteSpace($VagrantfilePath)) {
    $exampleDirectory = Join-Path $PSScriptRoot 'onedrive-example'
    $VagrantfilePath = Join-Path $exampleDirectory 'Vagrantfile'
}
else {
    $VagrantfilePath = [IO.Path]::GetFullPath($VagrantfilePath)
    $exampleDirectory = Split-Path -Parent $VagrantfilePath
}
New-Item -ItemType Directory -Path $exampleDirectory -Force | Out-Null
if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $CatalogPath = Join-Path $exampleDirectory 'metadata.json'
}
else {
    $CatalogPath = [IO.Path]::GetFullPath($CatalogPath)
}
$catalogDirectory = Split-Path -Parent $CatalogPath
New-Item -ItemType Directory -Path $catalogDirectory -Force | Out-Null
$catalog = [ordered]@{
    name = $vagrantBoxName
    description = "Vagrant box $boxName ($osName $version), provider $provider."
    versions = @(
        [ordered]@{
            version = $version
            providers = @(
                [ordered]@{
                    name = $provider
                    url = $downloadUrl
                    checksum_type = 'sha256'
                    checksum = $checksum
                    architecture = $vagrantArchitecture
                    default_architecture = $true
                }
            )
        }
    )
}
$catalogJson = $catalog | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $CatalogPath -Value $catalogJson -Encoding UTF8
$remoteCatalogRelativePath = $relativeRemotePath.Substring(0, $relativeRemotePath.LastIndexOf('/')) + '/metadata.json'
$remoteCatalog = "${RemoteName}:$remoteCatalogRelativePath"
Write-Host "Enviando catálogo Vagrant compatível para $remoteCatalog..." -ForegroundColor Cyan
& $rclone copyto $CatalogPath $remoteCatalog
if ($LASTEXITCODE -ne 0) {
    throw "Upload do catálogo JSON falhou (código $LASTEXITCODE)."
}
$catalogLinkOutput = @(& $rclone link $remoteCatalog --onedrive-link-scope anonymous --onedrive-link-type view 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Não foi possível criar o link público do catálogo: $($catalogLinkOutput -join "`n")"
}
$catalogUrl = $null
foreach ($line in $catalogLinkOutput) {
    if ([string] $line -match 'https://\S+') {
        $catalogUrl = $Matches[0].TrimEnd('.', ',', ')')
    }
}
if (-not $catalogUrl) {
    throw "rclone não retornou um link HTTPS para o catálogo: $($catalogLinkOutput -join "`n")"
}
$catalogDownloadUrl = if ($catalogUrl.Contains('?')) { "$catalogUrl&download=1" } else { "$catalogUrl?download=1" }
$cookieJar = 'File.join(__dir__, "onedrive.cookies")'
$vagrantfile = @"
Vagrant.configure("2") do |config|
  config.vm.box = $escapedBoxName
  config.vm.box_version = "$version"
  config.vm.box_url = $escapedDownloadUrl
  config.vm.box_download_checksum = "$checksum"
  config.vm.box_download_checksum_type = "sha256"
  config.vm.box_download_options = {
    "user-agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
    "cookie-jar" => $cookieJar,
    "cookie" => $cookieJar
  }
  config.vm.box_check_update = false
  config.vm.provider "$provider" do |vm|
    # Configure provider-specific settings here.
  end
end
"@
Set-Content -LiteralPath $VagrantfilePath -Value $vagrantfile -Encoding UTF8

$publication = [pscustomobject] @{
    name             = $boxFile.BaseName
    vagrant_box      = $vagrantBoxName
    provider         = $provider
    version          = $version
    file             = $boxFile.Name
    size             = $boxFile.Length
    sha256           = $checksum
    url              = $shareUrl
    download_url     = $downloadUrl
    catalog_name     = $vagrantBoxName
    catalog_url      = $catalogDownloadUrl
    catalog_path     = $remoteCatalogRelativePath
    metadata_path    = $CatalogPath
    remote_path      = $relativeRemotePath
    local_path       = $boxFile.FullName
    vagrantfile_path = $vagrantfilePath
    published        = (Get-Date).ToUniversalTime().ToString('o')
}
if ([string]::IsNullOrWhiteSpace($PublicationPath)) {
    $PublicationPath = Join-Path $PSScriptRoot 'onedrive-publication.json'
}
else {
    $PublicationPath = [IO.Path]::GetFullPath($PublicationPath)
}
$publication | ConvertTo-Json | Set-Content -LiteralPath $PublicationPath -Encoding UTF8

Write-Host ''
Write-Host 'Publicação concluída.' -ForegroundColor Green
Write-Host "Vagrant box name: $vagrantBoxName"
Write-Host "URL pública: $shareUrl" -ForegroundColor Yellow
Write-Host "SHA-256: $checksum"
Write-Host "Vagrantfile de exemplo: $vagrantfilePath"
Write-Host "Detalhes locais: $publicationPath"
Write-Host "Catálogo compatível com Vagrant: $CatalogPath"
Write-Host "URL pública do catálogo: $catalogDownloadUrl" -ForegroundColor Yellow
Write-Host 'Para iniciar a box usando o link do OneDrive:' -ForegroundColor Cyan
Write-Host "  cd `"$exampleDirectory`"; vagrant up --provider=$provider"
Write-Host 'Para validar download anônimo dentro de uma VM:' -ForegroundColor Cyan
Write-Host "  ./test-onedrive-download.ps1 -PublicationFile `"$publicationPath`""

