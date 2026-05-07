# ============================================================
# Git Local Initialization Tool - Git Dual Platform
# ============================================================
# Functions:
#   - Initialize Git repository (main branch)
#   - Configure project-level Git user info
#   - Configure dual platform remotes (GitHub + Gitee)
#   - Set pushall alias
#
# Usage:
#   .\git-init-local.ps1                    # Run initialization
#   .\git-init-local.ps1 -Help            # Show help
#
# Platform: Windows PowerShell
# ============================================================

param(
    [switch]$Help
)

# Script directory
$SCRIPT_DIR = $PSScriptRoot
$CONFIG_FILE = "$SCRIPT_DIR\.env"

# ============================================================
# Show Help
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host "Git Local Initialization Tool - Git Dual Platform" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\git-init-local.ps1                    # Run initialization"
    Write-Host "  .\git-init-local.ps1 -Help            # Show help"
    Write-Host ""
    Write-Host "Functions:" -ForegroundColor Yellow
    Write-Host "  - Initialize Git repository (main branch)"
    Write-Host "  - Configure project-level Git user info"
    Write-Host "  - Configure dual platform remotes (GitHub + Gitee)"
    Write-Host "  - Set pushall alias"
    Write-Host ""
}

# ============================================================
# Load Config
# ============================================================
function Load-Config {
    if (-not (Test-Path $CONFIG_FILE)) {
        Write-Host "[ERROR] Config file not found: $CONFIG_FILE" -ForegroundColor Red
        Write-Host "[ERROR] Please copy env.example to .env first"
        exit 1
    }

    $config = @{}
    Get-Content $CONFIG_FILE | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^#' -or $line -match '^\s*$') { return }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $config[$key] = $value
        }
    }

    return $config
}

# ============================================================
# Get Project Name
# ============================================================
function Get-ProjectName {
    return Split-Path -Leaf (Get-Location)
}

# ============================================================
# Initialize Git Repository
# ============================================================
function Initialize-Git {
    $projectName = Get-ProjectName

    if (-not (Test-Path ".git")) {
        Write-Host "[INFO] Initializing Git repository..." -ForegroundColor Cyan
        git init -b main
        Write-Host "[OK] Git repository created" -ForegroundColor Green
    } else {
        Write-Host "[INFO] Git repository already exists, skipping" -ForegroundColor Cyan
        $branchOutput = git branch | Out-String
        if ($branchOutput -match "master") {
            git branch -m master main
            Write-Host "[INFO] Branch renamed from master to main" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# Configure Git User Info
# ============================================================
function Set-GitConfig {
    param($config)

    # Remove existing config
    git config --local --unset-all user.email 2>$null | Out-Null
    git config --local --unset-all user.name 2>$null | Out-Null

    $userName = $config["GIT_USER_NAME"]
    $userEmail = $config["GIT_USER_EMAIL"]

    if ($userName) {
        git config --local user.name $userName
        Write-Host "[OK] Git user name: $userName" -ForegroundColor Green
    }

    if ($userEmail) {
        git config --local user.email $userEmail
        Write-Host "[OK] Git user email: $userEmail" -ForegroundColor Green
    }
}

# ============================================================
# Configure Remotes
# ============================================================
function Set-Remotes {
    param($config)

    $projectName = Get-ProjectName

    # Remove existing remotes
    $existingRemotes = git remote
    if ($existingRemotes) {
        foreach ($remote in $existingRemotes) {
            git remote remove $remote 2>$null | Out-Null
        }
    }

    # Add GitHub remote (only if both USER and HOST are configured)
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"] -and
        $config.ContainsKey("GITHUB_HOST") -and $config["GITHUB_HOST"]) {
        $githubUser = $config["GITHUB_USER"]
        $githubHost = $config["GITHUB_HOST"]
        $remoteUrl = "git@$githubHost`:$githubUser/$projectName.git"
        git remote add github $remoteUrl
        Write-Host "[OK] GitHub remote: github -> $remoteUrl" -ForegroundColor Green
    }

    # Add Gitee remote (only if both USER and HOST are configured)
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"] -and
        $config.ContainsKey("GITEE_HOST") -and $config["GITEE_HOST"]) {
        $giteeUser = $config["GITEE_USER"]
        $giteeHost = $config["GITEE_HOST"]
        $remoteUrl = "git@$giteeHost`:$giteeUser/$projectName.git"
        git remote add gitee $remoteUrl
        Write-Host "[OK] Gitee remote: gitee -> $remoteUrl" -ForegroundColor Green
    }
}

# ============================================================
# Set pushall Alias
# ============================================================
function Set-PushAllAlias {
    $remotes = git remote
    $hasGithub = $remotes -contains "github"
    $hasGitee = $remotes -contains "gitee"

    if ($hasGithub -and $hasGitee) {
        git config alias.pushall '!git push github main && git push gitee main'
        Write-Host "[OK] pushall alias configured" -ForegroundColor Green
    } elseif ($hasGithub) {
        git config alias.pushall '!git push github main'
        Write-Host "[OK] pushall alias configured (GitHub only)" -ForegroundColor Yellow
    } elseif ($hasGitee) {
        git config alias.pushall '!git push gitee main'
        Write-Host "[OK] pushall alias configured (Gitee only)" -ForegroundColor Yellow
    } else {
        Write-Host "[WARN] No remotes configured, cannot set pushall" -ForegroundColor Yellow
    }
}

# ============================================================
# Show Status
# ============================================================
function Show-Status {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Current Status" -ForegroundColor Cyan
    Write-Host "========================================"

    Write-Host ""
    Write-Host "[Git Config]" -ForegroundColor Yellow
    git config --local user.name
    git config --local user.email

    Write-Host ""
    Write-Host "[Remote Config]" -ForegroundColor Yellow
    git remote -v

    Write-Host ""
    Write-Host "[pushall Alias]" -ForegroundColor Yellow
    git config --get alias.pushall

    Write-Host ""
    Write-Host "[Next Steps]" -ForegroundColor Yellow
    Write-Host "  git add ."
    Write-Host "  git commit -m 'init'"
    Write-Host "  git pushall"
}

# ============================================================
# Main
# ============================================================
function Main {
    if ($Help) {
        Show-Help
        return
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Git Local Initialization Tool - Git Dual Platform" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # Load config
    $config = Load-Config

    # Run initialization
    Initialize-Git
    Set-GitConfig -config $config
    Set-Remotes -config $config
    Set-PushAllAlias

    # Show status
    Show-Status

    Write-Host ""
    Write-Host "[DONE] Local Git configuration complete" -ForegroundColor Green
}

Main
