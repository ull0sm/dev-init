[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    $ScriptDir = Get-Location
}

$IsRemote = $false
if ($MyInvocation.MyCommand.Path -match "^http") {
    $IsRemote = $true
    $ScriptDir = "$env:TEMP\dev-init"
    if (-not (Test-Path $ScriptDir)) {
        New-Item -ItemType Directory -Path $ScriptDir -Force | Out-Null
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestVersion {
    param([string]$AppId)
    $result = winget search $AppId --exact --accept-source-agreements 2>$null
    if ($result -match '(\d+\.\d+\.\d+)') { return $matches[1] }
    return $null
}

function Install-App {
    param([string]$AppId, [string]$Description)
    Write-Host "[INFO] Checking latest version of $AppId..." -ForegroundColor Cyan
    $latestVersion = Get-LatestVersion -AppId $AppId
    
    $installed = winget list --id $AppId --exact 2>$null | Select-Object -Skip 3 | Select-String -Pattern "^$AppId"
    
    if ($installed) {
        $installedVersion = ($installed -split '\s+')[1]
        Write-Host "[INFO] $Description installed: $installedVersion (latest: $latestVersion)" -ForegroundColor Yellow
        $update = Read-Host "Update to latest? (y/N)"
        if ($update -ne "y" -and $update -ne "Y") {
            Write-Host "[SKIP] Keeping current version" -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "[INSTALL] $Description ($latestVersion)..." -ForegroundColor Cyan
    winget install --id $AppId -e --silent --accept-package-agreements --accept-source-agreements
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] $Description installed" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to install $Description" -ForegroundColor Red
    }
}

function Start-AppsInstallation {
    Write-Step "Installing core applications..."
    
    $apps = @(
        @{Id="Microsoft.VisualStudioCode"; Name="VS Code"},
        @{Id="Git.Git"; Name="Git"},
        @{Id="Docker.DockerDesktop"; Name="Docker Desktop"},
        @{Id="Python.Python.3"; Name="Python"},
        @{Id="OpenJS.NodeJS.LTS"; Name="Node.js LTS"},
        @{Id="EclipseAdoptium.Temurin.JDK"; Name="JDK"},
        @{Id="msys2.msys2"; Name="MSYS2/MinGW"}
    )
    
    foreach ($app in $apps) {
        Install-App -AppId $app.Id -Description $app.Name
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "[INFO] Upgrading pip..." -ForegroundColor Cyan
        python -m pip install --upgrade pip 2>$null
        pip install virtualenv 2>$null
    }
    
    $msys2Path = "${env:ProgramFiles}\MSYS2\msys2_shell.cmd"
    if (Test-Path $msys2Path) {
        Write-Host "[INFO] Installing MinGW packages..." -ForegroundColor Cyan
        & $msys2Path -mingw64 -defterm -here -no-start - "pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-make mingw-w64-x86_64-gdb" 2>$null
    }
    
    Write-Host "`n[OK] Core applications complete" -ForegroundColor Green
}

function Start-DevToolsInstallation {
    Write-Step "Installing dev tools..."
    
    $devTools = @(
        @{Id="Postman.Postman"; Name="Postman"},
        @{Id="Microsoft.WindowsTerminal"; Name="Windows Terminal"},
        @{Id="Notepad++.Notepad++"; Name="Notepad++"},
        @{Id="GitHub.GitHubDesktop"; Name="GitHub Desktop"},
        @{Id="Greenshot.Greenshot"; Name="Greenshot"}
    )
    
    foreach ($tool in $devTools) {
        Install-App -AppId $tool.Id -Description $tool.Name
    }
    
    Write-Host "`n[OK] Dev tools complete" -ForegroundColor Green
}

function Start-GitConfiguration {
    Write-Step "Configuring Git..."
    
    $gitConfig = @{
        "init.defaultBranch" = "main"
        "pull.rebase" = "false"
        "fetch.prune" = "true"
        "core.editor" = "code --wait"
        "core.autocrlf" = "true"
        "diff.tool" = "vscode"
        "merge.tool" = "vscode"
        "push.default" = "current"
        "alias.co" = "checkout"
        "alias.br" = "branch"
        "alias.st" = "status"
        "credential.helper" = "manager"
    }
    
    foreach ($key in $gitConfig.Keys) {
        $current = git config --global $key 2>$null
        if ($current -ne $gitConfig[$key]) {
            git config --global $key $gitConfig[$key]
        }
    }
    
    $userName = git config --global user.name 2>$null
    if ([string]::IsNullOrWhiteSpace($userName)) {
        Write-Host "Configuring Git user:" -ForegroundColor Cyan
        $name = Read-Host "Enter your name"
        $email = Read-Host "Enter your email"
        git config --global user.name $name
        git config --global user.email $email
    }
    
    Write-Host "`n[OK] Git configured" -ForegroundColor Green
}

function Start-VSCodeSetup {
    Write-Step "Setting up VS Code..."
    
    $extensions = @(
        "ms-python.python",
        "ms-python.vscode-pylance",
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint",
        "eamodio.gitlens",
        "bradlc.vscode-tailwindcss",
        "ms-vscode.vscode-typescript-next",
        "ms-azuretools.vscode-docker",
        "formulahendry.auto-rename-tag",
        "christian-kohler.path-intellisense",
        "usernamehw.errorlens",
        "usernamehw.indent-rainbow"
    )
    
    if (Get-Command code -ErrorAction SilentlyContinue) {
        foreach ($ext in $extensions) {
            $installed = code --list-extensions 2>$null | Select-String -Pattern $ext -Quiet
            if (-not $installed) {
                Write-Host "[INSTALL] $ext..." -ForegroundColor Cyan
                code --install-extension $ext --force 2>$null
            }
        }
        
        $settings = @{
            "editor.formatOnSave" = $true
            "editor.defaultFormatter" = "esbenp.prettier-vscode"
            "editor.tabSize" = 2
            "files.autoSave" = "afterDelay"
            "terminal.integrated.fontSize" = 14
        }
        
        $settingsPath = "$env:APPDATA\Code\User\settings.json"
        $settings | ConvertTo-Json | Set-Content -Path $settingsPath -Force
    }
    
    Write-Host "`n[OK] VS Code setup complete" -ForegroundColor Green
}

function Start-SSHSetup {
    Write-Host "Setting up SSH..." -ForegroundColor Cyan
    
    $sshDir = "$HOME\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        icacls $sshDir /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
    }
    
    $defaultKey = "$sshDir\id_ed25519"
    if (-not (Test-Path "$defaultKey.pub")) {
        Write-Host "[INFO] Generating SSH key..." -ForegroundColor Cyan
        ssh-keygen -t ed25519 -f $defaultKey -N "" -C "$env:USERNAME@$env:COMPUTERNAME"
    }
    
    $configPath = "$sshDir\config"
    if (-not (Test-Path $configPath)) {
        @"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host *
    AddKeysToAgent yes
"@ | Set-Content -Path $configPath -Force
    }
    
    Write-Host "`n[OK] SSH setup complete" -ForegroundColor Green
    Write-Host "Add this key to GitHub:" -ForegroundColor Cyan
    Get-Content "$defaultKey.pub"
}

function Start-OpenCodeInstall {
    Write-Step "Installing OpenCode..."
    
    $openCodeId = "AnarchyOpenCode.OpenCode"
    $latestVersion = Get-LatestVersion -AppId $openCodeId
    
    $installed = winget list --id $openCodeId --exact 2>$null | Select-Object -Skip 3 | Select-String -Pattern "^$openCodeId"
    
    if ($installed) {
        Write-Host "[INFO] OpenCode is already installed" -ForegroundColor Yellow
        $update = Read-Host "Update to latest? (y/N)"
        if ($update -ne "y" -and $update -ne "Y") { return }
    }
    
    Write-Host "[INSTALL] OpenCode ($latestVersion)..." -ForegroundColor Cyan
    winget install --id $openCodeId -e --silent --accept-package-agreements --accept-source-agreements
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] OpenCode installed" -ForegroundColor Green
    }
}

function Start-PostInstall {
    Write-Step "Running post-install tasks..."
    
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $globalTools = @("yarn", "typescript", "nodemon", "pnpm")
        foreach ($tool in $globalTools) {
            Write-Host "Installing $tool..." -ForegroundColor Cyan
            npm install -g $tool 2>$null
        }
    }
    
    Write-Host "`n[OK] Post-install complete" -ForegroundColor Green
}

function Start-PrerequisiteCheck {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: winget not found. Install App Installer from Microsoft Store." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] winget available" -ForegroundColor Green
}

function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "   Dev Environment Bootstrap" -ForegroundColor Cyan
    Write-Host "======================================`n" -ForegroundColor Cyan
    
    if (-not (Test-Admin)) {
        Write-Host "WARNING: Not running as Administrator`n" -ForegroundColor Yellow
    }
    
    Write-Host "Select option:" -ForegroundColor White
    Write-Host "  1. Full Setup" -ForegroundColor Green
    Write-Host "  2. Install Apps" -ForegroundColor Green
    Write-Host "  3. Install Dev Tools" -ForegroundColor Green
    Write-Host "  4. Configure Git & SSH" -ForegroundColor Green
    Write-Host "  5. Setup VS Code" -ForegroundColor Green
    Write-Host "  6. Install OpenCode" -ForegroundColor Green
    Write-Host "  0. Exit`n" -ForegroundColor Green
    
    $choice = Read-Host "Enter choice [1-6 or 0]"
    return $choice
}

function Start-FullSetup {
    Start-PrerequisiteCheck
    Start-AppsInstallation
    Start-DevToolsInstallation
    Start-GitConfiguration
    Start-SSHSetup
    Start-VSCodeSetup
    Start-OpenCodeInstall
    Start-PostInstall
    
    Write-Step "Setup Complete!"
    Write-Host "Your dev environment is ready!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "  - Restart terminal" -ForegroundColor White
    Write-Host "  - Add SSH key to GitHub" -ForegroundColor White
    Write-Host "  - Start coding!`n" -ForegroundColor White
}

if ($IsRemote) {
    Start-FullSetup
} else {
    $selection = Show-Menu
    switch ($selection) {
        "1" { Start-FullSetup }
        "2" { Start-PrerequisiteCheck; Start-AppsInstallation }
        "3" { Start-PrerequisiteCheck; Start-DevToolsInstallation }
        "4" { Start-GitConfiguration; Start-SSHSetup }
        "5" { Start-VSCodeSetup }
        "6" { Start-OpenCodeInstall }
        "0" { exit 0 }
        default { exit 1 }
    }
}
