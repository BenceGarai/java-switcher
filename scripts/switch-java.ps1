<#
.SYNOPSIS
    Switch between installed Java versions on Windows.

.DESCRIPTION
    Reads configuration from config/config.json to locate Java installations.
    Lists available versions, lets the user pick one, and updates the system
    JAVA_HOME and PATH accordingly.

.NOTES
    Run this script as Administrator.
#>

class JavaSwitcher {
    [string]$ConfigPath
    [string]$JavaBase
    [string]$SelectedJava
    [string]$LogPath
    [string]$DefaultVersion
    [array]$Folders

    

    JavaSwitcher([string]$configPath) {
        if (-not (Test-Path $configPath)) {
            throw "Config file not found at $configPath"
        }

        $this.ConfigPath = $configPath
        $config = Get-Content -Raw -Path $configPath | ConvertFrom-Json
        $this.JavaBase = $config.JavaBase

        if ($config.PSObject.Properties.Name -contains "LogPath") {
            $this.LogPath = $config.LogPath
        } else {
            $this.LogPath = $null
        }

        $this.LoadJavaFolders()

        if ($config.PSObject.Properties.Name -contains "DefaultVersion") {
            $this.DefaultVersion = $config.DefaultVersion
        }
    }

    [void]LoadJavaFolders() {
        if (-not (Test-Path $this.JavaBase)) {
            throw "Java base folder not found at '$($this.JavaBase)'"
        }
        $this.Folders = Get-ChildItem -Path $this.JavaBase -Directory | Sort-Object Name
        if (-not $this.Folders) {
            throw "No Java installations found in $($this.JavaBase)"
        }
    }

    [void]ListJavaVersions() {
        Write-Host "`nAvailable Java versions:`n" -ForegroundColor Cyan
        for ($i = 0; $i -lt $this.Folders.Count; $i++) {
            $marker = ""
            if ($this.PSObject.Properties.Name -contains "DefaultVersion" -and $this.Folders[$i].Name -eq $this.DefaultVersion) {
                $marker = " (default)"
            }
            Write-Host "$($i + 1) - $($this.Folders[$i].Name)$marker"
        }
    }

    [void]SelectJavaVersion() {
        $choice = Read-Host "`nEnter number to set JAVA_HOME (or press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($choice)) {
            if ($this.PSObject.Properties.Name -contains "DefaultVersion" -and $this.DefaultVersion) {
                $this.SelectedJava = Join-Path $this.JavaBase $this.DefaultVersion
                Write-Host "`nUsing default Java version: $($this.DefaultVersion)" -ForegroundColor Green
            } else {
                throw "No selection made and no default version configured."
            }
        } else {
            if (-not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $this.Folders.Count) {
                throw "Invalid selection."
            }
            $this.SelectedJava = $this.Folders[$choice - 1].FullName
        }
    }

    [void]SetJavaHome() {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $this.SelectedJava, "Machine")
        Write-Host "`nJAVA_HOME set to: $($this.SelectedJava)" -ForegroundColor Green
    }

    [void]UpdatePath() {
        $oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $cleanPath = ($oldPath -replace 'C:\\Program Files\\Java\\[^;]+\\bin;?', '')
        $newPath = "$($this.SelectedJava)\bin;" + $cleanPath
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "PATH updated successfully." -ForegroundColor Green
    }

    [void]WriteLog() {
        if ($this.LogPath) {
            if (-not (Test-Path $this.LogPath)) { New-Item -ItemType Directory -Path $this.LogPath | Out-Null }
            $logFile = Join-Path $this.LogPath "java-switcher.log"
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content $logFile "$timestamp | JAVA_HOME set to $($this.SelectedJava)"
        }
    }

    [void]Run() {
        $this.ListJavaVersions()
        $this.SelectJavaVersion()
        $this.SetJavaHome()
        $this.UpdatePath()
        $this.WriteLog()
        Write-Host "`nJava version switched successfully!" -ForegroundColor Cyan
        Write-Host "You may need to open a new terminal for changes to take effect.`n"
    }
}

# === Entry Point ===
# Resolve path to config/config.json (relative to script)
$configPath = Join-Path $PSScriptRoot "..\config\config.json"

# Create the JavaSwitcher instance and run it
try {
    $switcher = [JavaSwitcher]::new($configPath)
    $switcher.Run()
} catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
}

