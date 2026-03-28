# dev-init

Dev environment bootstrap for Windows - one command to install everything.

## Quick Start (One-Liner)

```powershell
irm https://yourdomain.com/setup.ps1 | iex
```

Or clone and run locally:

```powershell
git clone https://github.com/yourname/dev-init.git
cd dev-init
.\setup.ps1
```

## What It Installs

- **VS Code** - latest
- **Git** - latest
- **Docker Desktop** - latest
- **Python** - latest
- **Node.js LTS** - latest
- **JDK** - latest Temurin
- **MinGW** - via MSYS2
- **Windows Terminal** - latest
- **Postman** - latest
- **OpenCode** - AI coding assistant

## Features

- Auto-detects latest versions from winget
- Updates existing apps if newer version available
- Git configuration with sensible defaults
- SSH key generation
- VS Code extensions & settings
- Global npm tools (yarn, typescript, nodemon, pnpm)

## Menu Options

1. **Full Setup** - Everything at once
2. **Install Apps** - Core apps only
3. **Install Dev Tools** - Terminal, Postman, etc.
4. **Configure Git & SSH** - Just the configs
5. **Setup VS Code** - Extensions and settings
6. **Install OpenCode** - AI assistant

## Requirements

- Windows 10/11
- PowerShell 5.1+
- winget (Windows 11 or Microsoft Store)
