# PowerShell Odoo Backup Script
# Windows backup solution for Odoo databases
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

param(
    [Parameter(Mandatory=$true)]
    [string]$OdooUrl = "http://localhost:8069",

    [Parameter(Mandatory=$true)]
    [string]$MasterPassword,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,

    [Parameter(Mandatory=$false)]
    [string]$BackupDir = "C:\Backup\Odoo"
)

# Create backup directory if it doesn't exist
if (!(Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force
    Write-Host "Created backup directory: $BackupDir" -ForegroundColor Green
}

# Generate timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $BackupDir "$DatabaseName_$timestamp.zip"

Write-Host "Starting backup for database: $DatabaseName" -ForegroundColor Cyan
Write-Host "Target file: $backupFile" -ForegroundColor Yellow

# Prepare form data
$boundary = [System.Guid]::NewGuid().ToString()
$bodyLines = @(
    "--$boundary",
    'Content-Disposition: form-data; name="master_pwd"',
    '',
    $MasterPassword,
    "--$boundary",
    'Content-Disposition: form-data; name="name"',
    '',
    $DatabaseName,
    "--$boundary",
    'Content-Disposition: form-data; name="backup_format"',
    '',
    'zip',
    "--$boundary--"
)

$body = $bodyLines -join "`r`n"

try {
    # Show progress
    Write-Host "Initiating backup request..." -ForegroundColor Yellow

    # Perform backup
    $response = Invoke-WebRequest -Uri "$OdooUrl/web/database/backup" `
        -Method Post `
        -Body $body `
        -ContentType "multipart/form-data; boundary=$boundary" `
        -OutFile $backupFile

    if (Test-Path $backupFile) {
        $fileSize = (Get-Item $backupFile).Length / 1MB
        Write-Host "✅ Backup successful!" -ForegroundColor Green
        Write-Host "File: $backupFile" -ForegroundColor White
        Write-Host "Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White

        # Basic verification
        if ($fileSize -gt 0.1) {
            Write-Host "✅ File size verification passed" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ Backup file seems too small, please verify manually"
        }

        # Test ZIP integrity
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($backupFile)
            $zip.Dispose()
            Write-Host "✅ ZIP integrity verification passed" -ForegroundColor Green
        } catch {
            Write-Warning "⚠️ ZIP integrity check failed: $($_.Exception.Message)"
        }

    } else {
        Write-Error "❌ Backup file was not created"
        exit 1
    }
} catch {
    Write-Error "❌ Backup failed: $($_.Exception.Message)"
    if (Test-Path $backupFile) {
        Remove-Item $backupFile -Force
        Write-Host "Cleaned up incomplete backup file" -ForegroundColor Yellow
    }
    exit 1
}

# Optional cleanup of old backups
$cleanupDays = 30
$oldBackups = Get-ChildItem -Path $BackupDir -Filter "*.zip" | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$cleanupDays) }

if ($oldBackups.Count -gt 0) {
    Write-Host "Found $($oldBackups.Count) backups older than $cleanupDays days" -ForegroundColor Yellow
    $cleanup = Read-Host "Delete old backups? (y/N)"

    if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
        $oldBackups | Remove-Item -Force
        Write-Host "✅ Cleaned up $($oldBackups.Count) old backup files" -ForegroundColor Green
    }
}

Write-Host "`nBackup operation completed successfully!" -ForegroundColor Green