#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Hytale Server Manager - Windows Update Script

.DESCRIPTION
    This script checks for and applies updates to the Hytale Server Manager.
    It will:
    - Check the current version
    - Query GitHub for the latest release
    - Download and install the update if available
    - Preserve configuration and data

.PARAMETER Force
    Force update even if already on latest version

.PARAMETER Check
    Only check for updates without installing

.PARAMETER InstallPath
    The installation directory. Default: C:\HytaleServerManager

.EXAMPLE
    .\update.ps1
    .\update.ps1 -Check
    .\update.ps1 -Force
#>

param(
    [switch]$Force,
    [switch]$Check,
    [string]$InstallPath = "C:\HytaleServerManager"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status { param($Message) Write-Host "[*] $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[-] $Message" -ForegroundColor Red }

Write-Host ""
Write-Host "======================================" -ForegroundColor Magenta
Write-Host "  Hytale Server Manager Updater" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta
Write-Host ""

# Verify installation exists
if (-not (Test-Path "$InstallPath\package.json")) {
    Write-Error "Installation not found at: $InstallPath"
    Write-Host "Please specify the correct path with -InstallPath"
    exit 1
}

# Get current version
Write-Status "Checking current version..."
$packageJson = Get-Content "$InstallPath\package.json" | ConvertFrom-Json
$currentVersion = $packageJson.version
Write-Host "Current version: $currentVersion" -ForegroundColor White

# Read config to get GitHub repo
$githubRepo = "yourusername/hytale-server-manager"
if (Test-Path "$InstallPath\config.json") {
    $config = Get-Content "$InstallPath\config.json" | ConvertFrom-Json
    if ($config.updates.githubRepo) {
        $githubRepo = $config.updates.githubRepo
    }
}

# Check for updates
Write-Status "Checking for updates from: $githubRepo"
try {
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
        "User-Agent" = "HytaleServerManager-Updater"
    }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$githubRepo/releases/latest" -Headers $headers
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Warning "No releases found on GitHub"
        Write-Host "Repository: $githubRepo"
        exit 0
    }
    Write-Error "Failed to check for updates: $_"
    exit 1
}

$latestVersion = $release.tag_name -replace '^v', ''
Write-Host "Latest version:  $latestVersion" -ForegroundColor White

# Compare versions
function Compare-Versions {
    param($v1, $v2)
    $parts1 = $v1.Split('.') | ForEach-Object { [int]$_ }
    $parts2 = $v2.Split('.') | ForEach-Object { [int]$_ }

    for ($i = 0; $i -lt [Math]::Max($parts1.Length, $parts2.Length); $i++) {
        $p1 = if ($i -lt $parts1.Length) { $parts1[$i] } else { 0 }
        $p2 = if ($i -lt $parts2.Length) { $parts2[$i] } else { 0 }

        if ($p1 -gt $p2) { return 1 }
        if ($p1 -lt $p2) { return -1 }
    }
    return 0
}

$comparison = Compare-Versions $latestVersion $currentVersion

if ($comparison -le 0 -and -not $Force) {
    Write-Success "You are already running the latest version!"
    exit 0
}

if ($comparison -gt 0) {
    Write-Host ""
    Write-Host "Update available: $currentVersion -> $latestVersion" -ForegroundColor Yellow
    Write-Host "Release: $($release.name)" -ForegroundColor White
    Write-Host ""
}

if ($Check) {
    Write-Host "Release notes:" -ForegroundColor Cyan
    Write-Host $release.body
    Write-Host ""
    Write-Host "Download URL: $($release.html_url)" -ForegroundColor White
    exit 0
}

# Find the Windows download asset
$windowsAsset = $release.assets | Where-Object { $_.name -match 'windows.*\.zip$' }
if (-not $windowsAsset) {
    Write-Error "No Windows release package found"
    Write-Host "Available assets:"
    $release.assets | ForEach-Object { Write-Host "  - $($_.name)" }
    exit 1
}

# Confirm update
if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "Do you want to install this update? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Update cancelled."
        exit 0
    }
}

# Stop the service
$serviceName = "HytaleServerManager"
$serviceWasRunning = $false

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Status "Stopping service..."
    Stop-Service -Name $serviceName -Force
    $serviceWasRunning = $true
    Write-Success "Service stopped"
}

# Create backup
$backupDir = "$InstallPath\backups\update-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Status "Creating backup: $backupDir"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item "$InstallPath\config.json" "$backupDir\" -ErrorAction SilentlyContinue
Copy-Item "$InstallPath\data" "$backupDir\" -Recurse -ErrorAction SilentlyContinue
Write-Success "Backup created"

# Download update
$downloadPath = "$env:TEMP\hsm-update.zip"
Write-Status "Downloading update: $($windowsAsset.name)"
Invoke-WebRequest -Uri $windowsAsset.browser_download_url -OutFile $downloadPath
Write-Success "Download complete"

# Extract update
$extractPath = "$env:TEMP\hsm-update"
Write-Status "Extracting update..."
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
}
Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force

# Find the extracted folder (might be nested)
$extractedFolder = Get-ChildItem $extractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
if ($extractedFolder) {
    $sourcePath = $extractedFolder.FullName
} else {
    $sourcePath = $extractPath
}

Write-Success "Extracted successfully"

# Apply update (preserve config and data)
Write-Status "Applying update..."

# Remove old files except config and data
Get-ChildItem $InstallPath -Exclude @("config.json", "data", "backups", "nssm.exe") | Remove-Item -Recurse -Force

# Copy new files
Copy-Item "$sourcePath\*" -Destination $InstallPath -Recurse -Force -Exclude @("config.json", "data")

Write-Success "Files updated"

# Run database migrations
Write-Status "Running database migrations..."
Push-Location $InstallPath

# Create database backup before migration
$dbPath = "$InstallPath\data\db\hytalepanel.db"
$dbBackupPath = "$backupDir\hytalepanel.db.pre-migration"
if (Test-Path $dbPath) {
    Copy-Item $dbPath $dbBackupPath -Force
    Write-Success "Database backed up before migration"
}

try {
    & npx prisma generate 2>&1 | Out-Null
    $migrateOutput = & npx prisma migrate deploy 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Migration failed: $migrateOutput"
    }
    Write-Success "Database migrations applied"
} catch {
    Write-Warning "Database migration failed: $_"
    if (Test-Path $dbBackupPath) {
        Write-Status "Restoring database from backup..."
        Copy-Item $dbBackupPath $dbPath -Force
        Write-Success "Database restored from backup"
    }
    Write-Error "Update completed but migrations failed. Please check the database manually."
}
Pop-Location

# Cleanup
Write-Status "Cleaning up..."
Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

# Restart service
if ($serviceWasRunning) {
    Write-Status "Starting service..."
    Start-Service -Name $serviceName
    Write-Success "Service started"
}

# Done
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  Update Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Updated from $currentVersion to $latestVersion" -ForegroundColor White
Write-Host "Backup saved to: $backupDir" -ForegroundColor White
Write-Host ""

if ($serviceWasRunning) {
    Write-Host "Service is running. Access the web interface to verify." -ForegroundColor Cyan
} else {
    Write-Host "Start the application with: $InstallPath\start.bat" -ForegroundColor Cyan
}

Write-Host ""
