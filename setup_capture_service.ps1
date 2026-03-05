# CheckMate Capture Client Setup Script
# This script downloads and sets up capture.exe as a Windows service using servy

param(
    [string]$CaptureInstallDir = "C:\monitor\capture",
    [string]$ServyInstallDir = "C:\monitor\servy",
    [string]$ServiceName = "CaptureClient",
    [string]$ServiceDisplayName = "CheckMate Capture Client",
    [string]$ServiceDescription = "CheckMate Capture Client for CheckMate integration"
)

$ErrorActionPreference = "Stop"

# Check for Administrator privileges
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click on PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Check for API_SECRET environment variable
$apiSecret = [Environment]::GetEnvironmentVariable("API_SECRET", "Machine")
if ([string]::IsNullOrEmpty($apiSecret)) {
    Write-Host ""
    Write-Host "WARNING: API_SECRET environment variable is not set!" -ForegroundColor Yellow
    Write-Host "This is required for capture.exe to run." -ForegroundColor Yellow
    Write-Host ""
    $apiSecretInput = Read-Host "Enter API_SECRET value (or press Enter to skip and configure manually)"
    if ([string]::IsNullOrWhiteSpace($apiSecretInput)) {
        Write-Host "Skipped. You will need to set API_SECRET manually before starting the service." -ForegroundColor Yellow
    } else {
        [Environment]::SetEnvironmentVariable("API_SECRET", $apiSecretInput, "Machine")
        Write-Host "API_SECRET has been set as a system environment variable." -ForegroundColor Green
    }
} else {
    Write-Host "API_SECRET is already configured." -ForegroundColor Green
}

Write-Host ""

Write-Host "=== CheckMate Capture Client Setup ===" -ForegroundColor Cyan
Write-Host "Capture Directory: $CaptureInstallDir" -ForegroundColor Gray
Write-Host "Servy Directory:  $ServyInstallDir" -ForegroundColor Gray
Write-Host "Service Name:      $ServiceName" -ForegroundColor Gray
Write-Host ""

# Create capture installation directory
if (-not (Test-Path $CaptureInstallDir)) {
    Write-Host "[1/5] Creating capture directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $CaptureInstallDir -Force | Out-Null
} else {
    Write-Host "[1/5] Capture directory exists" -ForegroundColor Gray
}

# Create servy installation directory
if (-not (Test-Path $ServyInstallDir)) {
    Write-Host "[2/5] Creating servy directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ServyInstallDir -Force | Out-Null
} else {
    Write-Host "[2/5] Servy directory exists" -ForegroundColor Gray
}

# Download servy portable
Write-Host "[3/5] Downloading servy portable..." -ForegroundColor Yellow
$servyUrl = "https://github.com/aelassas/servy/releases/download/v6.8/servy-6.8-x64-portable.7z"
$servyArchive = "$env:TEMP\servy.7z"

try {
    Invoke-WebRequest -Uri $servyUrl -OutFile $servyArchive -UseBasicParsing
    Write-Host "  Downloaded servy v6.8 portable" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to download servy: $_" -ForegroundColor Red
    exit 1
}

# Extract servy using 7zip to C:\monitor\servy
Write-Host "[4/5] Extracting servy..." -ForegroundColor Yellow
try {
    $sevenZip = "D:\Applications\Scoop\apps\7zip\current\7z.exe"
    if (-not (Test-Path $sevenZip)) {
        $sevenZip = "C:\Program Files\7-Zip\7z.exe"
    }
    if (-not (Test-Path $sevenZip)) {
        Write-Host "ERROR: 7-Zip not found" -ForegroundColor Red
        exit 1
    }
    & $sevenZip x "$servyArchive" -o"$ServyInstallDir" -y | Out-Null
    Remove-Item $servyArchive -Force
    
    # Move files from subfolder to main directory
    $servySubfolder = Join-Path $ServyInstallDir "servy-6.8-x64-portable"
    if (Test-Path $servySubfolder) {
        Get-ChildItem $servySubfolder | Move-Item -Destination $ServyInstallDir -Force
        Remove-Item $servySubfolder -Recurse -Force
    }
    
    Write-Host "  Extracted servy to $ServyInstallDir" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to extract servy: $_" -ForegroundColor Red
    exit 1
}

# Download capture
Write-Host "[5/5] Downloading CheckMate Capture client..." -ForegroundColor Yellow
$captureUrl = "https://github.com/bluewave-labs/capture/releases/download/v1.3.2/capture_1.3.2_windows_amd64.zip"
$captureZip = "$CaptureInstallDir\capture.zip"

try {
    Invoke-WebRequest -Uri $captureUrl -OutFile $captureZip -UseBasicParsing
    Write-Host "  Downloaded capture v1.3.2" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to download capture: $_" -ForegroundColor Red
    exit 1
}

# Extract capture to C:\monitor\capture
try {
    Expand-Archive -Path $captureZip -DestinationPath $CaptureInstallDir -Force
    Remove-Item $captureZip -Force
    
    # Rename capture.exe to avoid conflict with folder name
    $extractedCaptureDir = Join-Path $CaptureInstallDir "capture_1.3.2_windows_amd64"
    if (Test-Path $extractedCaptureDir) {
        $captureExeSource = Join-Path $extractedCaptureDir "capture.exe"
        $captureExeDest = Join-Path $CaptureInstallDir "capture.exe"
        if (Test-Path $captureExeSource) {
            Move-Item $captureExeSource $captureExeDest -Force
        }
        # Copy all files from extracted directory
        Get-ChildItem $extractedCaptureDir | Move-Item -Destination $CaptureInstallDir -Force
        Remove-Item $extractedCaptureDir -Recurse -Force
    }
    Write-Host "  Extracted capture to $CaptureInstallDir" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to extract capture: $_" -ForegroundColor Red
    exit 1
}

# Create the Windows service using servy-cli
Write-Host "[5/5] Creating Windows service..." -ForegroundColor Yellow

# Servy CLI is in C:\monitor\servy
$servyCli = Join-Path $ServyInstallDir "servy-cli.exe"

$captureExePath = Join-Path $CaptureInstallDir "capture.exe"

if (-not (Test-Path $servyCli)) {
    Write-Host "ERROR: servy-cli.exe not found at $servyCli" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $captureExePath)) {
    Write-Host "ERROR: capture.exe not found at $captureExePath" -ForegroundColor Red
    exit 1
}

# Stop existing service if it exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Remove existing service
    Write-Host "  Removing existing service..." -ForegroundColor Yellow
    & $servyCli uninstall --name="$ServiceName" 2>$null
    Start-Sleep -Seconds 2
}

# Create new service using servy-cli
Write-Host "  Creating service '$ServiceName'..." -ForegroundColor Yellow
& $servyCli install `
    --name="$ServiceName" `
    --path="$captureExePath" `
    --displayName="$ServiceDisplayName" `
    --description="$ServiceDescription" `
    --startupType=Automatic `
    --startupDir="$CaptureInstallDir"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Service created successfully" -ForegroundColor Green
} else {
    Write-Host "WARNING: Service creation returned exit code $LASTEXITCODE" -ForegroundColor Yellow
}

# Start the service
Write-Host "  Starting service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($?) {
    Write-Host "  Service started successfully" -ForegroundColor Green
} else {
    Write-Host "WARNING: Service may not have started. Check service status manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service Details:" -ForegroundColor White
Write-Host "  Name:          $ServiceName" -ForegroundColor Gray
Write-Host "  Display Name: $ServiceDisplayName" -ForegroundColor Gray
Write-Host "  Capture Path: $CaptureInstallDir" -ForegroundColor Gray
Write-Host "  Servy Path:   $ServyInstallDir" -ForegroundColor Gray
Write-Host ""
Write-Host "Useful Commands:" -ForegroundColor White
Write-Host "  Start service:   Start-Service $ServiceName" -ForegroundColor Gray
Write-Host "  Stop service:    Stop-Service $ServiceName" -ForegroundColor Gray
Write-Host "  View status:     Get-Service $ServiceName" -ForegroundColor Gray
Write-Host "  View logs:       Get-Content '$CaptureInstallDir\logs\*' -Tail 50" -ForegroundColor Gray
Write-Host "  Remove service:  '$servyCli' uninstall --name='$ServiceName'" -ForegroundColor Gray
