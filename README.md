# CheckMate Capture Client Setup

A PowerShell script to install and configure CheckMate Capture as a native Windows service using [Servy](https://github.com/aelassas/servy).

## Overview

This automation script sets up CheckMate Capture client to run as a Windows service that starts automatically at system boot. It handles:

- Downloading [Servy](https://github.com/aelassas/servy/releases/tag/v6.8) v6.8 (portable)
- Downloading [CheckMate Capture](https://github.com/bluewave-labs/capture/releases/tag/v1.3.2) v1.3.2
- Creating the Windows service using `servy-cli`
- Configuring the required `API_SECRET` environment variable

## Requirements

| Requirement | Version |
|-------------|---------|
| Windows | Server 2016+ or Windows 10/11 |
| Privileges | Administrator |
| 7-Zip | Installed |
| Internet | Required for downloads |

## Quick Start

```powershell
# Run as Administrator
powershell -ExecutionPolicy Bypass -File setup_capture_service.ps1
```

## Installation Flow

1. **API_SECRET** - Prompted if not set as system environment variable
2. **Download Servy** - Extracts to `C:\monitor\servy`
3. **Download Capture** - Extracts to `C:\monitor\capture`
4. **Create Service** - Uses `servy-cli install`

## Parameters

```powershell
.\setup_capture_service.ps1 `
    -CaptureInstallDir "C:\monitor\capture" `
    -ServyInstallDir "C:\monitor\servy" `
    -ServiceName "CaptureClient" `
    -ServiceDisplayName "CheckMate Capture Client" `
    -ServiceDescription "CheckMate Capture Client for CheckMate integration"
```

| Parameter | Description | Default |
|-----------|-------------|---------|
| `CaptureInstallDir` | Capture installation path | `C:\monitor\capture` |
| `ServyInstallDir` | Servy installation path | `C:\monitor\servy` |
| `ServiceName` | Windows service name | `CaptureClient` |
| `ServiceDisplayName` | Display name in services.msc | `CheckMate Capture Client` |
| `ServiceDescription` | Service description | CheckMate Capture Client... |

## Servy CLI Commands

The script uses `servy-cli.exe` for service management:

```powershell
# Install a service
servy-cli install --name="MyService" --path="C:\app\myapp.exe" --startupType=Automatic

# Uninstall a service
servy-cli uninstall --name=MyService

# Start/Stop/Restart
servy-cli start --name=MyService
servy-cli stop --name=MyService
servy-cli restart --name=MyService

# Check status
servy-cli status --name=MyService
```

### Full Servy Install Example

```powershell
servy-cli install `
    --name="CaptureClient" `
    --displayName="CheckMate Capture Client" `
    --description="CheckMate Capture Client for CheckMate integration" `
    --path="C:\monitor\capture\capture.exe" `
    --startupDir="C:\monitor\capture" `
    --startupType=Automatic `
    --stdout="C:\monitor\capture\logs\stdout.log" `
    --stderr="C:\monitor\capture\logs\stderr.log" `
    --enableSizeRotation `
    --rotationSize=10 `
    --enableHealth `
    --heartbeatInterval=30 `
    --maxFailedChecks=3 `
    --recoveryAction=RestartService `
    --maxRestartAttempts=5
```

## Service Management

```powershell
# Check service status
Get-Service CaptureClient

# Start/Stop
Start-Service CaptureClient
Stop-Service CaptureClient

# View logs
Get-Content C:\monitor\capture\logs\*.log -Tail 50

# Remove service
C:\monitor\servy\servy-cli.exe uninstall --name=CaptureClient
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `API_SECRET` | Yes | Secret key for CheckMate Capture authentication |
| `GIN_MODE` | No | Gin web framework mode (default: "release") |

```powershell
# Set API_SECRET manually
[Environment]::SetEnvironmentVariable("API_SECRET", "your-secret-value", "Machine")

# Verify
[Environment]::GetEnvironmentVariable("API_SECRET", "Machine")
```

## Troubleshooting

### Service won't start

1. Verify API_SECRET is set:
   ```powershell
   [Environment]::GetEnvironmentVariable("API_SECRET", "Machine")
   ```

2. Check capture.exe exists:
   ```powershell
   Test-Path C:\monitor\capture\capture.exe
   ```

3. Review logs:
   ```powershell
   Get-Content C:\monitor\capture\logs\* -Tail 100
   ```

4. Test capture.exe manually:
   ```powershell
   C:\monitor\capture\capture.exe
   ```

### Reinstall

```powershell
# Stop and remove
Stop-Service CaptureClient -Force -ErrorAction SilentlyContinue
C:\monitor\servy\servy-cli.exe uninstall --name=CaptureClient

# Reinstall
.\setup_capture_service.ps1
```

## Project Structure

```
.
├── setup_capture_service.ps1   # Main setup script
├── AGENTS.md                   # Development guidelines
└── README.md                   # This file
```

## Credits

- [Servy](https://github.com/aelassas/servy) - Windows service wrapper
- [CheckMate Capture](https://github.com/bluewave-labs/capture) - Capture client software

## License

MIT License
