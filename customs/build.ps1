[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$profileRoot = Join-Path $PSScriptRoot 'profiles'
$workRoot = Join-Path $PSScriptRoot '.work'
$boxesRoot = Join-Path $projectRoot 'boxes'

if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) {
    throw 'Vagrant was not found in PATH.'
}

function Read-MenuChoice {
    param([string] $Prompt, [int] $Count)
    while ($true) {
        $answer = Read-Host $Prompt
        if ($answer -match '^\d+$') {
            $number = [int] $answer
            if ($number -ge 0 -and $number -le $Count) { return $number }
        }
        Write-Host "Informe um número entre 0 e $Count." -ForegroundColor Yellow
    }
}

function Invoke-Vagrant {
    param(
        [Parameter(Mandatory)] [string] $WorkingDirectory,
        [Parameter(Mandatory)] [string[]] $Arguments
    )
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & vagrant @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "vagrant $($Arguments -join ' ') falhou (código $LASTEXITCODE)."
        }
    }
    finally {
        Pop-Location
    }
}

$baseBoxes = @()
if (Test-Path -LiteralPath $boxesRoot -PathType Container) {
    foreach ($osDirectory in Get-ChildItem -LiteralPath $boxesRoot -Directory) {
        foreach ($versionDirectory in Get-ChildItem -LiteralPath $osDirectory.FullName -Directory) {
            foreach ($providerDirectory in Get-ChildItem -LiteralPath $versionDirectory.FullName -Directory) {
                $baseBoxes += Get-ChildItem -LiteralPath $providerDirectory.FullName -File -Filter '*.box' |
                    ForEach-Object {
                        [pscustomobject]@{
                            File = $_
                            Os = $osDirectory.Name
                            Version = $versionDirectory.Name
                            Provider = $providerDirectory.Name
                        }
                    }
            }
        }
    }
}
$baseBoxes = @($baseBoxes | Sort-Object Os, Version, Provider, { $_.File.Name })
if ($baseBoxes.Count -eq 0) {
    throw "Nenhuma box base local foi encontrada em boxes/<sistema>/<versão>/<provider>/*.box. Crie uma box Bento primeiro."
}

$profiles = @(
    Get-ChildItem -LiteralPath $profileRoot -File -Filter '*.json' |
        Sort-Object Name |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }
)
if ($profiles.Count -eq 0) {
    throw "Nenhum perfil custom foi encontrado em $profileRoot."
}

Write-Host ''
Write-Host 'Boxes base locais' -ForegroundColor Cyan
for ($index = 0; $index -lt $baseBoxes.Count; $index++) {
    $base = $baseBoxes[$index]
    Write-Host ('{0,2}. {1} {2} / {3} ({4})' -f ($index + 1), $base.Os, $base.Version, $base.Provider, $base.File.Name)
}
Write-Host ' 0. Sair'
$baseChoice = Read-MenuChoice -Prompt 'Escolha a box base' -Count $baseBoxes.Count
if ($baseChoice -eq 0) { return }
$base = $baseBoxes[$baseChoice - 1]
if ($base.Os -notin @('rockylinux', 'oraclelinux', 'ol')) {
    throw "As customs portadas de debug suportam apenas Rocky Linux/Oracle Linux (Red Hat). Base selecionada: $($base.Os)."
}

Write-Host ''
Write-Host 'Boxes customizadas' -ForegroundColor Cyan
for ($index = 0; $index -lt $profiles.Count; $index++) {
    Write-Host ('{0,2}. {1} - {2}' -f ($index + 1), $profiles[$index].displayName, $profiles[$index].description)
}
Write-Host ' 0. Voltar'
$profileChoice = Read-MenuChoice -Prompt 'Escolha a customização' -Count $profiles.Count
if ($profileChoice -eq 0) { return }
$profile = $profiles[$profileChoice - 1]

if ($profile.name -notmatch '^[a-z0-9][a-z0-9-]*$') {
    throw "Nome de perfil inválido no manifesto: $($profile.name)"
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "ansible\playbooks\$($profile.playbook)") -PathType Leaf)) {
    throw "Playbook não encontrado para o perfil '$($profile.name)': $($profile.playbook)"
}

switch ($base.Provider.ToLowerInvariant()) {
    'virtualbox' { $vagrantProvider = 'virtualbox' }
    'vmware' { $vagrantProvider = 'vmware_desktop' }
    default { throw "Provider '$($base.Provider)' ainda não tem configuração no menu custom." }
}

$legacyOsName = switch ($base.Os.ToLowerInvariant()) {
    'rockylinux' { if ($base.Version -match '^9') { 'rocky9' } else { $null } }
    'oraclelinux' { if ($base.Version -match '^9') { 'ol9' } else { $null } }
    'ol' { if ($base.Version -match '^9') { 'ol9' } else { $null } }
    default { $null }
}
if ($legacyOsName) {
    $customName = "silvestrini-$legacyOsName-$($profile.name)"
}
else {
    $customName = "$($base.Os)-$($base.Version)-$($profile.name)"
}
$destination = Join-Path $boxesRoot 'custom'
$destination = Join-Path $destination $base.Os
$destination = Join-Path $destination $base.Version
$destination = Join-Path $destination $profile.name
$destination = Join-Path $destination $base.Provider
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$outputBox = Join-Path $destination "$customName.box"
$partialBox = Join-Path $destination "$customName.building.box"
if (Test-Path -LiteralPath $partialBox) {
    throw "Artefato temporário já existe: $partialBox. Verifique e remova-o antes de tentar novamente."
}

$workDirectory = Join-Path $workRoot (Join-Path "$($base.Os)-$($base.Version)-$($base.Provider)" $profile.name)
$stateDirectory = Join-Path $workDirectory '.vagrant'
if (Test-Path -LiteralPath $stateDirectory) {
    throw "Há uma VM de build anterior em $workDirectory. Entre nessa pasta, execute 'vagrant destroy -f' e rode o menu novamente."
}
New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'templates\build.Vagrantfile') -Destination (Join-Path $workDirectory 'Vagrantfile') -Force

$environmentNames = @(
    'CUSTOM_BASE_BOX_PATH','CUSTOM_BASE_BOX_NAME','CUSTOM_ANSIBLE_DIR','CUSTOM_PLAYBOOK',
    'CUSTOM_PROFILE_NAME','CUSTOM_PROVIDER','CUSTOM_VAGRANT_PROVIDER','CUSTOM_MEMORY',
    'CUSTOM_CPUS','CUSTOM_EXTRA_VARS'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) { $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:CUSTOM_BASE_BOX_PATH = $base.File.FullName
    $env:CUSTOM_BASE_BOX_NAME = "$($base.Os)-$($base.Version)-$($base.Provider)"
    $env:CUSTOM_ANSIBLE_DIR = Join-Path $PSScriptRoot 'ansible'
    $env:CUSTOM_PLAYBOOK = $profile.playbook
    $env:CUSTOM_PROFILE_NAME = $profile.name
    $env:CUSTOM_PROVIDER = $base.Provider
    $env:CUSTOM_VAGRANT_PROVIDER = $vagrantProvider
    $env:CUSTOM_MEMORY = [string] $profile.memory
    $env:CUSTOM_CPUS = [string] $profile.cpus
    if ($profile.extraVars) {
        $env:CUSTOM_EXTRA_VARS = $profile.extraVars | ConvertTo-Json -Depth 12 -Compress
    }
    else {
        $env:CUSTOM_EXTRA_VARS = '{}'
    }

    Write-Host "Criando $customName sobre $($base.Os) $($base.Version) ($($base.Provider))..." -ForegroundColor Cyan
    Invoke-Vagrant -WorkingDirectory $workDirectory -Arguments @('validate')
    Invoke-Vagrant -WorkingDirectory $workDirectory -Arguments @('up', '--provider', $vagrantProvider)
    Invoke-Vagrant -WorkingDirectory $workDirectory -Arguments @('halt')
    Invoke-Vagrant -WorkingDirectory $workDirectory -Arguments @('package', '--output', $partialBox)
    if (-not (Test-Path -LiteralPath $partialBox -PathType Leaf)) {
        throw "O Vagrant terminou sem criar o artefato esperado: $partialBox"
    }
    Move-Item -LiteralPath $partialBox -Destination $outputBox -Force
    Invoke-Vagrant -WorkingDirectory $destination -Arguments @('box', 'add', '--name', $customName, '--provider', $vagrantProvider, '--force', $outputBox)

    $testVagrantfile = @"
Vagrant.configure("2") do |config|
  config.vm.box = "$customName"
  config.vm.box_check_update = false
  config.vm.provider "$vagrantProvider" do |vm|
    if "$vagrantProvider" == "virtualbox"
      vm.name = "$customName-test"
      vm.memory = $($profile.memory)
      vm.cpus = $($profile.cpus)
    else
      vm.vmx["displayName"] = "$customName"
      vm.vmx["memsize"] = "$($profile.memory)"
      vm.vmx["numvcpus"] = "$($profile.cpus)"
    end
  end
end
"@
    $testNetworkLines = @()
    if ($profile.hostname) { $testNetworkLines += ('  config.vm.hostname = "' + $profile.hostname + '"') }
    if ($profile.networkIp) {
        $testNetworkLines += ('  config.vm.network "public_network", ip: "' + $profile.networkIp + '", netmask: "255.255.255.0", mode: "bridge", bridge: ["Intel(R) I211 Gigabit Network Connection", "MediaTek Wi-Fi 6 MT7921 Wireless LAN"]')
    }
    $testVagrantfile = $testVagrantfile.Replace('  config.vm.provider', ($testNetworkLines -join [Environment]::NewLine) + [Environment]::NewLine + '  config.vm.provider')
    $testVagrantfilePath = Join-Path $destination 'Vagrantfile'
    Set-Content -LiteralPath $testVagrantfilePath -Value $testVagrantfile -Encoding UTF8

    try {
        Invoke-Vagrant -WorkingDirectory $workDirectory -Arguments @('destroy', '-f')
        if (Test-Path -LiteralPath $stateDirectory) {
            Remove-Item -LiteralPath $stateDirectory -Recurse -Force
        }
    }
    catch {
        Write-Warning "A box foi empacotada, mas a VM temporária não foi removida: $($_.Exception.Message)"
        Write-Warning "Para limpar manualmente: cd `"$workDirectory`"; vagrant destroy -f"
    }

    Write-Host "Box criada: $outputBox" -ForegroundColor Green
    Write-Host "Exemplo de teste: $testVagrantfilePath" -ForegroundColor Green
    Write-Host "Para testar: cd `"$destination`"; vagrant up" -ForegroundColor Cyan
}
finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
}




