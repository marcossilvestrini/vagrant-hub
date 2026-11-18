<#
.SYNOPSIS
    Builds a Bento base box, moves it into the project box catalog, and creates a local Vagrant example.

.DESCRIPTION
    Uses Bento's current Packer layout (os_pkrvars and packer_templates).
    Requires PowerShell 7 and Packer 1.14.0 or newer.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $BentoPath = (Join-Path $PSScriptRoot 'bento'),

    [Parameter()]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string] $CatalogNamespace = 'silvestrini'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    throw 'Packer was not found in PATH. Install Packer and try again.'
}

$packerVersionOutput = & packer version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw 'Could not read the Packer version. Install Packer 1.14.0 or newer.'
}
$versionMatch = [regex]::Match(($packerVersionOutput -join "`n"), '(?m)^\s*Packer v?(\d+\.\d+\.\d+)')
if (-not $versionMatch.Success) {
    throw 'Could not parse the Packer version. Install Packer 1.14.0 or newer.'
}
$packerVersion = [version] $versionMatch.Groups[1].Value
if ($packerVersion -lt [version] '1.14.0') {
    throw "Packer $packerVersion is too old for Bento's HashiCorp plugins. Upgrade to Packer 1.14.0 or newer, then rerun this script."
}

$bentoRoot = Resolve-Path -LiteralPath $BentoPath -ErrorAction SilentlyContinue
if (-not $bentoRoot) {
    throw "Bento checkout not found: $BentoPath`nClone Bento into defaults/bento or pass -BentoPath."
}

$templatePath = Join-Path $bentoRoot.Path 'packer_templates'
$profilesPath = Join-Path $bentoRoot.Path 'os_pkrvars'
if (-not (Test-Path -LiteralPath $templatePath -PathType Container)) {
    throw "Bento Packer templates were not found: $templatePath"
}
if (-not (Test-Path -LiteralPath $profilesPath -PathType Container)) {
    throw "Bento OS profiles were not found: $profilesPath"
}

$profiles = @(
    Get-ChildItem -LiteralPath $profilesPath -Recurse -File -Filter '*.pkrvars.hcl' |
        Sort-Object DirectoryName, Name
)
if ($profiles.Count -eq 0) {
    throw "No Bento profiles (*.pkrvars.hcl) were found in $profilesPath."
}

function Read-MenuChoice {
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [Parameter(Mandatory)] [int] $ItemCount
    )

    while ($true) {
        $selection = Read-Host $Prompt
        if ($selection -match '^\d+$') {
            $choice = [int] $selection
            if ($choice -ge 0 -and $choice -le $ItemCount) {
                return $choice
            }
        }
        Write-Host "Informe um número entre 0 e $ItemCount." -ForegroundColor Yellow
    }
}

function Get-ProfileValue {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $Name
    )

    $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s*=\s*"([^"]+)"'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        throw "Bento profile is missing the '$Name' value."
    }
    return $match.Groups[1].Value
}

function Stop-BentoBuilderMachines {
    param(
        [Parameter(Mandatory)] [object[]] $Providers,
        [Parameter(Mandatory)] [string[]] $OutputDirectories,
        [Parameter(Mandatory)] [string] $MachineName
    )

    $directoryPrefixes = @(
        $OutputDirectories | ForEach-Object {
            [IO.Path]::GetFullPath($_).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        }
    )
    $isBuildMachinePath = {
        param([string] $Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
        try { $fullPath = [IO.Path]::GetFullPath($Path) } catch { return $false }
        foreach ($prefix in $directoryPrefixes) {
            if ($fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }

    if ($Providers.FolderName -contains 'vmware') {
        $vmrun = Get-Command vmrun.exe, vmrun -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $vmrun) {
            foreach ($candidate in @('C:\Program Files\VMware\VMware Workstation\vmrun.exe', 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe', '/Applications/VMware Fusion.app/Contents/Library/vmrun', '/usr/bin/vmrun')) {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $vmrun = [pscustomobject]@{ Source = $candidate }; break }
            }
        }
        if (-not $vmrun) { throw 'vmrun was not found; cannot safely check for orphaned Bento VMware VMs.' }
        $runningVms = @(& $vmrun.Source list 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "vmrun list failed: $($runningVms -join ' ')" }
        foreach ($vmxPath in $runningVms | Select-Object -Skip 1) {
            $vmxPath = ([string]$vmxPath).Trim()
            if (& $isBuildMachinePath $vmxPath) {
                Write-Host "Desligando VM VMware de build anterior: $vmxPath" -ForegroundColor Yellow
                & $vmrun.Source stop $vmxPath hard | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Não foi possível desligar a VM VMware de build: $vmxPath" }
            }
        }
    }

    if ($Providers.FolderName -contains 'virtualbox') {
        $vbox = Get-Command VBoxManage.exe, VBoxManage -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $vbox) {
            foreach ($candidate in @('C:\Program Files\Oracle\VirtualBox\VBoxManage.exe', 'C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe', '/Applications/VirtualBox.app/Contents/MacOS/VBoxManage')) {
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $vbox = [pscustomobject]@{ Source = $candidate }; break }
            }
        }
        if (-not $vbox) { throw 'VBoxManage.exe was not found; cannot safely check for orphaned Bento VirtualBox VMs.' }

        $systemProperties = @(& $vbox.Source list systemproperties 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "VBoxManage list systemproperties failed: $($systemProperties -join ' ')" }
        $machineFolderLine = $systemProperties | Where-Object { $_ -match '^Default machine folder:' } | Select-Object -First 1
        if (-not $machineFolderLine) { throw 'Could not determine the VirtualBox machine folder.' }
        $machineFolder = ([string]$machineFolderLine -replace '^Default machine folder:\s*', '').Trim()
        $machineDirectory = [IO.Path]::GetFullPath((Join-Path $machineFolder $MachineName))
        $machineFolderPrefix = [IO.Path]::GetFullPath($machineFolder).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $machineDirectory.StartsWith($machineFolderPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to inspect a VirtualBox path outside the machine folder: $machineDirectory"
        }
        $machineConfig = Join-Path $machineDirectory "$MachineName.vbox"
        if (Test-Path -LiteralPath $machineConfig -PathType Leaf) {
            [xml]$machineXml = Get-Content -LiteralPath $machineConfig -Raw
            $diskPaths = @(
                $machineXml.SelectNodes('//*[local-name()="HardDisk"][@location]') | ForEach-Object {
                    $location = $_.GetAttribute('location')
                    if ([IO.Path]::IsPathRooted($location)) { [IO.Path]::GetFullPath($location) }
                    else { [IO.Path]::GetFullPath((Join-Path $machineDirectory $location)) }
                }
            )
            $hasBentoDisk = $false
            foreach ($diskPath in $diskPaths) {
                if (& $isBuildMachinePath $diskPath) { $hasBentoDisk = $true; break }
            }

            if ($hasBentoDisk) {
                $machineNode = $machineXml.SelectSingleNode('//*[local-name()="Machine"]')
                $machineUuid = ([string]$machineNode.GetAttribute('uuid')).Trim('{}')
                $registeredVms = @(& $vbox.Source list vms 2>&1)
                if ($LASTEXITCODE -ne 0) { throw "VBoxManage list vms failed: $($registeredVms -join ' ')" }
                $registered = $false
                foreach ($entry in $registeredVms) {
                    $registeredMatch = [regex]::Match([string]$entry, '\{(?<uuid>[^}]+)\}')
                    if ($registeredMatch.Success -and $registeredMatch.Groups['uuid'].Value -eq $machineUuid) { $registered = $true; break }
                }

                if ($registered) {
                    $runningVms = @(& $vbox.Source list runningvms 2>&1)
                    if ($LASTEXITCODE -ne 0) { throw "VBoxManage list runningvms failed: $($runningVms -join ' ')" }
                    $isRunning = $false
                    foreach ($entry in $runningVms) {
                        $runningMatch = [regex]::Match([string]$entry, '\{(?<uuid>[^}]+)\}')
                        if ($runningMatch.Success -and $runningMatch.Groups['uuid'].Value -eq $machineUuid) { $isRunning = $true; break }
                    }
                    if ($isRunning) {
                        Write-Host "Desligando VM VirtualBox de build anterior: $MachineName" -ForegroundColor Yellow
                        & $vbox.Source controlvm $machineUuid poweroff | Out-Null
                        if ($LASTEXITCODE -ne 0) { throw "Não foi possível desligar a VM VirtualBox de build: $MachineName" }
                    }
                    Write-Host "Removendo registro da VM VirtualBox de build anterior: $MachineName" -ForegroundColor Yellow
                    & $vbox.Source unregistervm $machineUuid --delete | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "Não foi possível remover a VM VirtualBox de build: $MachineName" }
                }
                else {
                    Write-Host "Removendo definição órfã da VM VirtualBox de build: $machineConfig" -ForegroundColor Yellow
                    Remove-Item -LiteralPath $machineDirectory -Recurse -Force
                }
            }
        }
    }
}

Write-Host ''
Write-Host 'Bento: selecione o sistema operacional e a versão' -ForegroundColor Cyan
Write-Host "Fonte: $($bentoRoot.Path)"
Write-Host ''

for ($index = 0; $index -lt $profiles.Count; $index++) {
    Write-Host ('{0,3}. {1}/{2}' -f ($index + 1), $profiles[$index].Directory.Name, $profiles[$index].BaseName)
}
Write-Host '  0. Sair'
Write-Host ''

$profileChoice = Read-MenuChoice -Prompt 'Escolha o perfil Bento' -ItemCount $profiles.Count
if ($profileChoice -eq 0) {
    return
}
$profile = $profiles[$profileChoice - 1]
$profileText = Get-Content -LiteralPath $profile.FullName -Raw
$osName = Get-ProfileValue -Text $profileText -Name 'os_name'
$osVersion = Get-ProfileValue -Text $profileText -Name 'os_version'
$osArch = Get-ProfileValue -Text $profileText -Name 'os_arch'
foreach ($pathSegment in @($osName, $osVersion, $osArch)) {
    if ($pathSegment -notmatch '^[A-Za-z0-9._-]+$' -or $pathSegment -in @('.', '..')) {
        throw "Unsafe path component in Bento profile: '$pathSegment'."
    }
}

$pathSeparators = [char[]] @([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$rootPrefix = $bentoRoot.Path.TrimEnd($pathSeparators) + [IO.Path]::DirectorySeparatorChar
$profileRelativePath = $profile.FullName.Substring($rootPrefix.Length).Replace('\', '/')
$profileDeclaresSources = $profileText -match '(?m)^\s*sources_enabled\s*='
if ($profileDeclaresSources) {
    $profilePackerTargets = @([regex]::Matches($profileText, '"source\.([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
}
else {
    $profilePackerTargets = @('parallels-iso.vm', 'qemu.vm', 'utm-iso.vm', 'virtualbox-iso.vm', 'vmware-iso.vm', 'hyperv-iso.vm')
}

$hostPlatform = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
$providers = @(
    [pscustomobject] @{ Name = 'VirtualBox'; PackerTargets = @('virtualbox-iso.vm', 'virtualbox-ovf.vm'); FolderName = 'virtualbox'; ArtifactRegex = '\.virtualbox\.box$'; VagrantProvider = 'virtualbox'; HostPlatforms = @('Windows', 'Linux', 'macOS'); Experimental = $false; VagrantPlugin = $null; ProfileAvailable = $false },
    [pscustomobject] @{ Name = 'VMware Workstation / Fusion'; PackerTargets = @('vmware-iso.vm'); FolderName = 'vmware'; ArtifactRegex = '\.vmware(?:_desktop|_fusion)?\.box$'; VagrantProvider = 'vmware_desktop'; HostPlatforms = @('Windows', 'Linux', 'macOS'); Experimental = $false; VagrantPlugin = $null; ProfileAvailable = $false },
    [pscustomobject] @{ Name = 'Parallels Desktop Pro [macOS]'; PackerTargets = @('parallels-iso.vm', 'parallels-ipsw.vm'); FolderName = 'parallels'; ArtifactRegex = '\.parallels\.box$'; VagrantProvider = 'parallels'; HostPlatforms = @('macOS'); Experimental = $false; VagrantPlugin = 'vagrant-parallels'; ProfileAvailable = $false },
    [pscustomobject] @{ Name = 'UTM [macOS]'; PackerTargets = @('utm-iso.vm'); FolderName = 'utm'; ArtifactRegex = '\.utm\.box$'; VagrantProvider = 'utm'; HostPlatforms = @('macOS'); Experimental = $false; VagrantPlugin = 'vagrant_utm'; ProfileAvailable = $false },
    [pscustomobject] @{ Name = 'QEMU [experimental]'; PackerTargets = @('qemu.vm'); FolderName = 'qemu'; ArtifactRegex = '\.qemu\.box$'; VagrantProvider = 'qemu'; HostPlatforms = @('Windows', 'Linux', 'macOS'); Experimental = $true; VagrantPlugin = 'vagrant-qemu'; ProfileAvailable = $false },
    [pscustomobject] @{ Name = 'Hyper-V [Windows, experimental]'; PackerTargets = @('hyperv-iso.vm'); FolderName = 'hyperv'; ArtifactRegex = '\.hyperv\.box$'; VagrantProvider = 'hyperv'; HostPlatforms = @('Windows'); Experimental = $true; VagrantPlugin = $null; ProfileAvailable = $false }
)
foreach ($provider in $providers) {
    $matchingTargets = @($provider.PackerTargets | Where-Object { $profilePackerTargets -contains $_ })
    if ($matchingTargets.Count -gt 0) {
        $provider.PackerTarget = $matchingTargets[0]
        $provider.ProfileAvailable = $true
    }
}

function Get-ProviderUnavailableReason {
    param([Parameter(Mandatory)] [object] $Provider)

    if ($Provider.HostPlatforms -notcontains $hostPlatform) {
        return "exige host $($Provider.HostPlatforms -join ', ')"
    }
    if (-not $Provider.ProfileAvailable) {
        return "não há source Packer deste provider no perfil $($profile.BaseName)"
    }

    $commands = switch ($Provider.FolderName) {
        'virtualbox' { @('VBoxManage.exe', 'VBoxManage') }
        'vmware' { @('vmrun.exe', 'vmrun') }
        'parallels' { @('prlctl') }
        'utm' { @('utmctl') }
        'qemu' { @('qemu-system-x86_64.exe', 'qemu-system-x86_64', 'qemu-system-aarch64.exe', 'qemu-system-aarch64') }
        'hyperv' { @('Get-VM') }
    }
    foreach ($commandName in $commands) {
        if (Get-Command $commandName -ErrorAction SilentlyContinue) { return $null }
    }

    if ($Provider.FolderName -eq 'virtualbox') {
        foreach ($candidate in @('C:\Program Files\Oracle\VirtualBox\VBoxManage.exe', 'C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe', '/Applications/VirtualBox.app/Contents/MacOS/VBoxManage')) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $null }
        }
    }
    if ($Provider.FolderName -eq 'vmware') {
        foreach ($candidate in @('C:\Program Files\VMware\VMware Workstation\vmrun.exe', 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe', '/Applications/VMware Fusion.app/Contents/Library/vmrun', '/usr/bin/vmrun')) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $null }
        }
    }
    if ($Provider.FolderName -eq 'utm' -and (Test-Path -LiteralPath '/Applications/UTM.app' -PathType Container)) { return $null }

    $toolName = switch ($Provider.FolderName) {
        'virtualbox' { 'VBoxManage' }
        'vmware' { 'vmrun' }
        'parallels' { 'prlctl' }
        'utm' { 'UTM / utmctl' }
        'qemu' { 'qemu-system' }
        'hyperv' { 'Hyper-V PowerShell tools (Get-VM)' }
    }
    return "$toolName não encontrado ou não está disponível no host."
}

Write-Host ''
Write-Host "Providers Bento para $osName $osVersion ($osArch) — host: ${hostPlatform}:" -ForegroundColor Cyan
for ($index = 0; $index -lt $providers.Count; $index++) {
    Write-Host ('{0,2}. {1}' -f ($index + 1), $providers[$index].Name)
}
Write-Host ('{0,2}. Todos disponíveis neste host e perfil (em paralelo)' -f ($providers.Count + 1))
Write-Host ' 0. Voltar'

$allCompatibleChoice = $providers.Count + 1
while ($true) {
    $providerChoice = Read-MenuChoice -Prompt 'Escolha o provider' -ItemCount $allCompatibleChoice
    if ($providerChoice -eq 0) { return }
    if ($providerChoice -eq $allCompatibleChoice) {
        $selectedProviders = @()
        foreach ($provider in $providers) {
            $unavailableReason = Get-ProviderUnavailableReason -Provider $provider
            if (-not $unavailableReason) { $selectedProviders += $provider }
            else { Write-Host "Ignorando $($provider.Name): $unavailableReason" -ForegroundColor DarkGray }
        }
        break
    }

    $candidateProvider = $providers[$providerChoice - 1]
    $unavailableReason = Get-ProviderUnavailableReason -Provider $candidateProvider
    if ($unavailableReason) {
        Write-Host "$($candidateProvider.Name) indisponível: $unavailableReason Escolha outro provider." -ForegroundColor Yellow
        continue
    }

    $selectedProviders = @($candidateProvider)
    break
}
if ($selectedProviders.Count -eq 0) {
    throw "Nenhum provider Bento compatível com o host $hostPlatform foi encontrado."
}

$outputPath = Join-Path $bentoRoot.Path 'builds/build_complete'
$existingArtifacts = @{}
if (Test-Path -LiteralPath $outputPath -PathType Container) {
    foreach ($artifact in Get-ChildItem -LiteralPath $outputPath -File -Filter '*.box') {
        $existingArtifacts[$artifact.FullName] = "{0}|{1}" -f $artifact.Length, $artifact.LastWriteTimeUtc.Ticks
    }
}

Push-Location -LiteralPath $bentoRoot.Path
try {
    Write-Host 'Inicializando plugins Packer do Bento...' -ForegroundColor Cyan
    & packer init './packer_templates'
    if ($LASTEXITCODE -ne 0) {
        throw "packer init falhou (código $LASTEXITCODE)."
    }

    $targets = ($selectedProviders | ForEach-Object { $_.PackerTarget }) -join ','
    $providerNames = ($selectedProviders | ForEach-Object { $_.Name }) -join ' e '
    $providerSlug = ($selectedProviders | ForEach-Object { $_.FolderName }) -join '-and-'
    $buildFilesRoot = Join-Path $bentoRoot.Path 'builds/build_files'
    $builderOutputDirectories = @(
        $selectedProviders | ForEach-Object { Join-Path $buildFilesRoot "packer-$osName-$osVersion-$osArch-$($_.FolderName)" }
    )
    Stop-BentoBuilderMachines -Providers $selectedProviders -OutputDirectories $builderOutputDirectories -MachineName "$osName-$osVersion-$(if ($osArch -eq 'x86_64') { 'amd64' } else { $osArch })"
    $logDirectory = Join-Path $bentoRoot.Path 'builds/logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $providerSources = ($selectedProviders | ForEach-Object { '"source.{0}"' -f $_.PackerTarget }) -join ', '
    $providerVariablesPath = Join-Path ([IO.Path]::GetTempPath()) "vagrant-hub-bento-sources-$PID-$logTimestamp.pkrvars.hcl"
    Set-Content -LiteralPath $providerVariablesPath -Value "sources_enabled = [$providerSources]`n" -Encoding utf8NoBOM
    $providerSources = ($selectedProviders | ForEach-Object { '"source.{0}"' -f $_.PackerTarget }) -join ', '
    $providerVariablesPath = Join-Path ([IO.Path]::GetTempPath()) "vagrant-hub-bento-sources-$PID-$logTimestamp.pkrvars.hcl"
    Set-Content -LiteralPath $providerVariablesPath -Value "sources_enabled = [$providerSources]`n" -Encoding utf8NoBOM
    $packerLogPath = Join-Path $logDirectory "packer-$osName-$osVersion-$osArch-$providerSlug-$logTimestamp.log"
    $previousPackerLog = [Environment]::GetEnvironmentVariable('PACKER_LOG', 'Process')
    $previousPackerLogPath = [Environment]::GetEnvironmentVariable('PACKER_LOG_PATH', 'Process')

    Write-Host "Criando $osName $osVersion ($osArch) para $providerNames..." -ForegroundColor Cyan
    Write-Host "Log detalhado do Packer: $packerLogPath" -ForegroundColor DarkGray
    try {
        $env:PACKER_LOG = '1'
        $env:PACKER_LOG_PATH = $packerLogPath
        & packer build -force "-only=$targets" "-parallel-builds=$($selectedProviders.Count)" "-var-file=$profileRelativePath" "-var-file=$providerVariablesPath" './packer_templates'
        if ($LASTEXITCODE -ne 0) {
            $packerExitCode = $LASTEXITCODE
            Stop-BentoBuilderMachines -Providers $selectedProviders -OutputDirectories $builderOutputDirectories -MachineName "$osName-$osVersion-$(if ($osArch -eq 'x86_64') { 'amd64' } else { $osArch })"
            throw "A criação da box falhou (código $packerExitCode). Log detalhado: $packerLogPath"
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('PACKER_LOG', $previousPackerLog, 'Process')
        [Environment]::SetEnvironmentVariable('PACKER_LOG_PATH', $previousPackerLogPath, 'Process')
        Remove-Item -LiteralPath $providerVariablesPath -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Pop-Location
}

$boxPrefix = "$osName-$osVersion-$osArch."
$projectRoot = Split-Path -Parent $PSScriptRoot
foreach ($provider in $selectedProviders) {
    $builtArtifacts = @(
        Get-ChildItem -LiteralPath $outputPath -File -Filter '*.box' |
            Where-Object {
                $signature = "{0}|{1}" -f $_.Length, $_.LastWriteTimeUtc.Ticks
                $_.Name.StartsWith($boxPrefix, [StringComparison]::OrdinalIgnoreCase) -and
                    $_.Name -match $provider.ArtifactRegex -and
                    (-not $existingArtifacts.ContainsKey($_.FullName) -or $existingArtifacts[$_.FullName] -ne $signature)
            }
    )
    if ($builtArtifacts.Count -ne 1) {
        throw "Expected one newly built box for $osName $osVersion ($osArch) / $($provider.Name), found $($builtArtifacts.Count) in $outputPath."
    }

    $destinationPath = Join-Path $projectRoot 'boxes'
    $destinationPath = Join-Path $destinationPath $osName
    $destinationPath = Join-Path $destinationPath $osVersion
    $destinationPath = Join-Path $destinationPath $provider.FolderName
    New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

    $builtBox = $builtArtifacts[0]
    $destinationBox = Join-Path $destinationPath $builtBox.Name
    Move-Item -LiteralPath $builtBox.FullName -Destination $destinationBox -Force

    $vagrantfilePath = Join-Path $destinationPath 'Vagrantfile'
    $boxName = "$osName-$osVersion-$osArch"
    $pluginDeclaration = if ($provider.VagrantPlugin) { "  config.vagrant.plugins = `"$($provider.VagrantPlugin)`"`n" } else { '' }
    $vagrantfile = @"
require "uri"

Vagrant.configure("2") do |config|
$pluginDeclaration  config.vm.box = "local/$boxName"
  box_path = File.expand_path("$($builtBox.Name)", __dir__).tr("\\", "/")
  box_path = "/#{box_path}" unless box_path.start_with?("/")
  config.vm.box_url = "file://#{URI::DEFAULT_PARSER.escape(box_path)}"
  config.vm.box_check_update = false
  config.vm.provider "$($provider.VagrantProvider)" do |vm|
    # Configure provider-specific settings here.
  end
end
"@
    Set-Content -LiteralPath $vagrantfilePath -Value $vagrantfile -Encoding UTF8

    Write-Host "Box movida para: $destinationBox" -ForegroundColor Green
    Write-Host "Vagrantfile de teste: $vagrantfilePath" -ForegroundColor Green
    Write-Host "Para testar localmente: cd `"$destinationPath`"; vagrant up" -ForegroundColor Cyan

    while ($true) {
        $publishChoice = Read-Host "Deseja publicar esta box no OneDrive? [s/N]"
        if ([string]::IsNullOrWhiteSpace($publishChoice) -or $publishChoice -match '^(n|nao|não)$') {
            Write-Host 'Box mantida apenas localmente.' -ForegroundColor DarkGray
            break
        }
        if ($publishChoice -match '^(s|sim)$') {
            $publisherPath = Join-Path $PSScriptRoot 'publish-onedrive.ps1'
            if (-not (Test-Path -LiteralPath $publisherPath -PathType Leaf)) {
                throw "Script de publicação não encontrado: $publisherPath"
            }

            $publicationPath = Join-Path $destinationPath 'box-publication.json'
            & $publisherPath -BoxPath $destinationBox -VagrantfilePath $vagrantfilePath -PublicationPath $publicationPath -CatalogPath (Join-Path $destinationPath 'metadata.json') -Architecture $osArch -CatalogNamespace $CatalogNamespace
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                throw "Publicação da box falhou (código $LASTEXITCODE)."
            }
            Write-Host "Exemplo Vagrant com URL do OneDrive: $vagrantfilePath" -ForegroundColor Green
            Write-Host "Dados para uso futuro: $publicationPath" -ForegroundColor Green
            break
        }
        Write-Host 'Responda s para publicar ou n para pular.' -ForegroundColor Yellow
    }
}




