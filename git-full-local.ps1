# ============================================================
# Git Dual Platform Full Initialization
# ============================================================
# Functions:
#   - Create remote repos (GitHub + Gitee)
#   - Initialize local Git and push to both platforms
#   - Set pushall alias
#   - Support --delete to remove remote repos
#   - Support --reset to clean local git config
#   - Support --clean to remove .git directory
#
# Usage:
#   .\git-full-local.ps1                    # Run initialization
#   .\git-full-local.ps1 --delete         # Delete remote repos
#   .\git-full-local.ps1 --reset           # Clean local git config
#   .\git-full-local.ps1 --clean           # Remove .git directory
#   .\git-full-local.ps1 --help            # Show help
#
# Platform: Windows PowerShell
# ============================================================

param(
    [switch]$Help
)

# Handle arguments
$Delete = $false
$Reset = $false
$Clean = $false
foreach ($arg in $args) {
    switch ($arg) {
        "--delete" { $Delete = $true }
        "--reset" { $Reset = $true }
        "--clean" { $Clean = $true }
    }
}

# Script directory
$SCRIPT_DIR = $PSScriptRoot
$CONFIG_FILE = "$SCRIPT_DIR\.env"

# ============================================================
# Show Help
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host "Git Dual Platform Full Initialization" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\git-full-local.ps1                    # Run initialization"
    Write-Host "  .\git-full-local.ps1 --delete         # Delete remote repos"
    Write-Host "  .\git-full-local.ps1 --reset           # Clean local git config"
    Write-Host "  .\git-full-local.ps1 --clean           # Remove .git directory"
    Write-Host "  .\git-full-local.ps1 --help            # Show help"
    Write-Host ""
    Write-Host "Functions:" -ForegroundColor Yellow
    Write-Host "  - Create remote repos (GitHub + Gitee)"
    Write-Host "  - Initialize local Git and push to both platforms"
    Write-Host "  - Set pushall alias"
    Write-Host "  - --delete: Delete remote repos only"
    Write-Host "  - --reset: Clean local git config (remotes, alias)"
    Write-Host "  - --clean: Remove .git directory (complete reset)"
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
# Test Tokens
# ============================================================
function Test-Tokens {
    param($config)

    # GitHub Token check
    if ($config.ContainsKey("GITHUB_TOKEN") -and $config["GITHUB_TOKEN"]) {
        $token = $config["GITHUB_TOKEN"]

        Write-Host "[INFO] Checking GitHub Token..." -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/user" `
                -Headers @{ Authorization = "token $token" } `
                -Method Get `
                -ErrorAction Stop
            Write-Host "[OK] GitHub Token is valid" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] GitHub Token is invalid: $_" -ForegroundColor Red
            return $false
        }
    }

    # Gitee Token check
    if ($config.ContainsKey("GITEE_TOKEN") -and $config["GITEE_TOKEN"]) {
        $token = $config["GITEE_TOKEN"]

        Write-Host "[INFO] Checking Gitee Token..." -ForegroundColor Cyan
        try {
            $response = Invoke-RestMethod -Uri "https://gitee.com/api/v5/user/repos?access_token=$token&per_page=1" `
                -Method Get `
                -ErrorAction Stop
            Write-Host "[OK] Gitee Token is valid" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Gitee Token is invalid: $_" -ForegroundColor Red
            return $false
        }
    }

    return $true
}

# ============================================================
# Test SSH
# ============================================================
function Test-SSH {
    param($config)

    # GitHub SSH check
    if ($config.ContainsKey("GITHUB_HOST") -and $config["GITHUB_HOST"]) {
        $sshHost = $config["GITHUB_HOST"]
        Write-Host "[INFO] Testing $sshHost ..." -ForegroundColor Cyan

        try {
            $result = ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$sshHost" 2>&1
            if ($result -match "Hi\s+|successfully authenticated") {
                Write-Host "  [OK] $sshHost SSH connection OK" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] $sshHost response unexpected: $result" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [FAIL] $sshHost SSH connection failed: $_" -ForegroundColor Red
        }
    }

    # Gitee SSH check
    if ($config.ContainsKey("GITEE_HOST") -and $config["GITEE_HOST"]) {
        $sshHost = $config["GITEE_HOST"]
        Write-Host "[INFO] Testing $sshHost ..." -ForegroundColor Cyan

        try {
            $result = ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$sshHost" 2>&1
            if ($result -match "Hi\s+|successfully authenticated") {
                Write-Host "  [OK] $sshHost SSH connection OK" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] $sshHost response unexpected: $result" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [FAIL] $sshHost SSH connection failed: $_" -ForegroundColor Red
        }
    }
}

# ============================================================
# Initialize Git
# ============================================================
function Initialize-Git {
    param($config)

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

    # Configure Git user info
    git config --local --unset-all user.email 2>$null | Out-Null
    git config --local --unset-all user.name 2>$null | Out-Null

    $userName = $config["GIT_USER_NAME"]
    $userEmail = $config["GIT_USER_EMAIL"]

    if ($userName) {
        git config --local user.name $userName
    }
    if ($userEmail) {
        git config --local user.email $userEmail
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

    # Remove existing alias block
    $configPath = ".git\config"
    if (Test-Path $configPath) {
        $lines = Get-Content $configPath
        $newLines = @()
        $skipAlias = $false
        foreach ($line in $lines) {
            if ($line -match '^\[alias\]') {
                $skipAlias = $true
                continue
            }
            if ($skipAlias -and $line -match '^\[remote\]|^\[branch\]|^\[user\]|^\[core\]') {
                $skipAlias = $false
            }
            if (-not $skipAlias) {
                $newLines += $line
            }
        }
        $newContent = $newLines -join "`n"
        Set-Content -Path $configPath -Value $newContent -NoNewline -ErrorAction SilentlyContinue
    }

    if ($hasGithub -and $hasGitee) {
        git config alias.pushall '!git push github main && git push gitee main'
        Write-Host "[OK] pushall alias configured" -ForegroundColor Green
    } elseif ($hasGithub) {
        git config alias.pushall '!git push github main'
        Write-Host "[OK] pushall alias configured (GitHub only)" -ForegroundColor Yellow
    } elseif ($hasGitee) {
        git config alias.pushall '!git push gitee main'
        Write-Host "[OK] pushall alias configured (Gitee only)" -ForegroundColor Yellow
    }
}

# ============================================================
# Create GitHub Repo
# ============================================================
function New-GitHubRepo {
    param($config)

    $projectName = Get-ProjectName

    if (-not ($config.ContainsKey("GITHUB_TOKEN") -and $config["GITHUB_TOKEN"])) {
        Write-Host "[INFO] GitHub Token not configured, skipping" -ForegroundColor Yellow
        return $true
    }

    $token = $config["GITHUB_TOKEN"]

    Write-Host "[INFO] Creating GitHub repo: $projectName" -ForegroundColor Cyan

    $body = @{
        name        = $projectName
        private     = $true
        auto_init   = $false
        description = "Auto initialized by git-full-local.ps1"
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.github.com/user/repos" `
            -Headers @{
                Authorization = "token $token"
                Accept        = "application/vnd.github.v3+json"
            } `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -ErrorAction Stop

        Write-Host "[OK] GitHub repo created: $($response.html_url)" -ForegroundColor Green
        return $true
    } catch {
        $errorDetail = $_.Exception.Message
        if ($errorDetail -match "409" -or $errorDetail -match "already exists" -or $errorDetail -match "422") {
            Write-Host "[OK] GitHub repo already exists, skipping creation" -ForegroundColor Green
            return $true
        }
        Write-Host "[ERROR] GitHub repo creation failed: $errorDetail" -ForegroundColor Red
        return $false
    }
}

# ============================================================
# Create Gitee Repo
# ============================================================
function New-GiteeRepo {
    param($config)

    $projectName = Get-ProjectName

    if (-not ($config.ContainsKey("GITEE_TOKEN") -and $config["GITEE_TOKEN"])) {
        Write-Host "[INFO] Gitee Token not configured, skipping" -ForegroundColor Yellow
        return $true
    }

    $token = $config["GITEE_TOKEN"]

    Write-Host "[INFO] Creating Gitee repo: $projectName" -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod `
            -Uri "https://gitee.com/api/v5/user/repos" `
            -Method Post `
            -Body @{
                access_token = $token
                name         = $projectName
                private      = $true
                description  = "Auto initialized by git-full-local.ps1"
            } `
            -ErrorAction Stop

        Write-Host "[OK] Gitee repo created: $($response.html_url)" -ForegroundColor Green
        return $true
    } catch {
        $errorDetail = $_.Exception.Message
        $alreadyExistsPatterns = @("409", "already exists", "already been taken", "422")
        $isAlreadyExists = $false
        foreach ($pattern in $alreadyExistsPatterns) {
            if ($errorDetail -match $pattern) {
                $isAlreadyExists = $true
                break
            }
        }
        if ($isAlreadyExists) {
            Write-Host "[OK] Gitee repo already exists, skipping creation" -ForegroundColor Green
            return $true
        }
        Write-Host "[ERROR] Gitee repo creation failed: $errorDetail" -ForegroundColor Red
        return $false
    }
}

# ============================================================
# Initial Commit
# ============================================================
function Initialize-FirstCommit {
    $projectName = Get-ProjectName

    if (-not (Test-Path "README.md")) {
        "# $projectName" | Out-File -FilePath "README.md" -Encoding UTF8
        Write-Host "[INFO] Created README.md" -ForegroundColor Cyan
    }

    git add .

    $status = git status 2>&1
    if ($status -match "have diverged") {
        Write-Host "[INFO] Remote has changes, pulling first..." -ForegroundColor Cyan
        git pull --rebase origin main 2>&1 | Out-Null
    }

    $commitOutput = git commit -m "Initial commit (auto by git-full-local.ps1)" 2>&1

    if ($LASTEXITCODE -ne 0) {
        if ($commitOutput -match "nothing to commit") {
            Write-Host "[INFO] Nothing new to commit, skipping" -ForegroundColor Cyan
        } else {
            Write-Host "[ERROR] Commit failed: $commitOutput" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[OK] Initial commit done" -ForegroundColor Green
    }

    return $true
}

# ============================================================
# Push to All Platforms (with force push fallback)
# ============================================================
function Sync-All {
    $remotes = git remote
    $hasGithub = $remotes -contains "github"
    $hasGitee = $remotes -contains "gitee"

    if ($hasGithub) {
        Write-Host "[INFO] Pushing to GitHub..." -ForegroundColor Cyan
        git push github main 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] GitHub push succeeded" -ForegroundColor Green
        } else {
            Write-Host "[WARN] GitHub push failed, trying pull --rebase..." -ForegroundColor Yellow
            git pull --rebase github main 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[INFO] pull --rebase succeeded, retrying push..." -ForegroundColor Cyan
                git push github main 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] GitHub push succeeded" -ForegroundColor Green
                } else {
                    Write-Host "[ERROR] GitHub push failed" -ForegroundColor Red
                    return $false
                }
            } else {
                Write-Host "[ERROR] GitHub pull --rebase failed" -ForegroundColor Red
                return $false
            }
        }
    }

    if ($hasGitee) {
        Write-Host "[INFO] Pushing to Gitee..." -ForegroundColor Cyan
        git push gitee main 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Gitee push succeeded" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Gitee push failed, trying pull --rebase..." -ForegroundColor Yellow
            git pull --rebase gitee main 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[INFO] pull --rebase succeeded, retrying push..." -ForegroundColor Cyan
                git push gitee main 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Gitee push succeeded" -ForegroundColor Green
                } else {
                    # Scenario: remote was deleted and recreated, local has no history
                    Write-Host "[WARN] Gitee push failed, attempting force push..." -ForegroundColor Yellow
                    git push gitee main --force 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Gitee force push succeeded" -ForegroundColor Green
                    } else {
                        Write-Host "[WARN] Gitee force push failed, resetting local..." -ForegroundColor Yellow
                        git fetch gitee 2>&1 | Out-Null
                        git reset --hard gitee/main 2>&1 | Out-Null
                        git push gitee main --force 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "[OK] Gitee force push succeeded" -ForegroundColor Green
                        } else {
                            Write-Host "[ERROR] Gitee push failed" -ForegroundColor Red
                            return $false
                        }
                    }
                }
            } else {
                # Scenario: remote has history but local is fresh
                Write-Host "[WARN] Gitee pull --rebase failed, attempting force push..." -ForegroundColor Yellow
                git fetch gitee 2>&1 | Out-Null
                git reset --hard gitee/main 2>&1 | Out-Null
                git push gitee main --force 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Gitee force push succeeded" -ForegroundColor Green
                } else {
                    Write-Host "[ERROR] Gitee push failed" -ForegroundColor Red
                    return $false
                }
            }
        }
    }

    return $true
}

# ============================================================
# Cleanup Remotes
# ============================================================
function Reset-Remotes {
    Write-Host "[INFO] Cleaning up remotes..." -ForegroundColor Yellow

    $remotes = git remote 2>$null
    if ($remotes) {
        foreach ($remote in $remotes) {
            git remote remove $remote 2>$null | Out-Null
        }
    }

    Write-Host "[INFO] Remote cleanup done" -ForegroundColor Yellow
}

# ============================================================
# Verify Repo Exists
# ============================================================
function Test-RepoExists {
    param($platform, $config)

    $projectName = Get-ProjectName
    $token = $null
    $username = $null

    if ($platform -eq "github") {
        if (-not ($config.ContainsKey("GITHUB_TOKEN") -and $config["GITHUB_TOKEN"])) {
            return $false
        }
        $token = $config["GITHUB_TOKEN"]
        $username = $config["GITHUB_USER"]
        $uri = "https://api.github.com/repos/$username/$projectName"
    } else {
        if (-not ($config.ContainsKey("GITEE_TOKEN") -and $config["GITEE_TOKEN"])) {
            return $false
        }
        $token = $config["GITEE_TOKEN"]
        $username = $config["GITEE_USER"]
        $uri = "https://gitee.com/api/v5/repos/$username/$projectName?access_token=$token"
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ============================================================
# Delete GitHub Repo
# ============================================================
function Remove-GitHubRepo {
    param($config)

    $projectName = Get-ProjectName

    if (-not ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"])) {
        return $true
    }

    $token = $config["GITHUB_TOKEN"]
    $username = $config["GITHUB_USER"]

    if (-not $token) {
        return $true
    }

    Write-Host "[INFO] Deleting GitHub repo: $projectName" -ForegroundColor Cyan

    try {
        $uri = "https://api.github.com/repos/$username/$projectName"
        $null = Invoke-RestMethod `
            -Uri $uri `
            -Headers @{
                Authorization = "token $token"
                Accept = "application/vnd.github.v3+json"
            } `
            -Method Delete `
            -ErrorAction Stop

        Write-Host "[OK] GitHub repo deleted" -ForegroundColor Green
        return $true
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode
        if ($statusCode -eq 204 -or $statusCode -eq 404) {
            Write-Host "[OK] GitHub repo deleted (HTTP $statusCode)" -ForegroundColor Green
            return $true
        }
        Write-Host "[ERROR] GitHub repo deletion failed (HTTP $statusCode)" -ForegroundColor Red
        return $false
    }
}

# ============================================================
# Delete Gitee Repo
# ============================================================
function Remove-GiteeRepo {
    param($config)

    $projectName = Get-ProjectName

    if (-not ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"])) {
        return $true
    }

    $token = $config["GITEE_TOKEN"]
    $username = $config["GITEE_USER"]

    if (-not $token) {
        return $true
    }

    Write-Host "[INFO] Deleting Gitee repo: $projectName" -ForegroundColor Cyan

    try {
        $uri = "https://gitee.com/api/v5/repos/$username/$projectName?access_token=$token"
        $null = Invoke-RestMethod `
            -Uri $uri `
            -Method Delete `
            -ErrorAction Stop

        Write-Host "[OK] Gitee repo deleted" -ForegroundColor Green
        return $true
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode
        if ($statusCode -eq 204 -or $statusCode -eq 404) {
            Write-Host "[OK] Gitee repo deleted (HTTP $statusCode)" -ForegroundColor Green
            return $true
        }
        Write-Host "[ERROR] Gitee repo deletion failed (HTTP $statusCode)" -ForegroundColor Red
        return $false
    }
}

# ============================================================
# Execute Delete
# ============================================================
function Do-Delete {
    $projectName = Get-ProjectName

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Git Dual Platform - Delete Remote Repos" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    $config = Load-Config

    Write-Host "WARNING: This will delete the following repos:" -ForegroundColor Yellow
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        Write-Host "  - GitHub: https://github.com/$username/$projectName" -ForegroundColor Yellow
    }
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        Write-Host "  - Gitee: https://gitee.com/$username/$projectName" -ForegroundColor Yellow
    }
    Write-Host ""

    $confirm = Read-Host "Confirm deletion? (type yes to confirm)"
    if ($confirm -ne "yes") {
        Write-Host "[INFO] Cancelled" -ForegroundColor Cyan
        exit 0
    }

    if (-not (Test-Tokens -config $config)) {
        Write-Host "[ERROR] Token check failed, exiting" -ForegroundColor Red
        exit 1
    }

    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_TOKEN"]) {
        if (-not (Remove-GitHubRepo -config $config)) {
            Write-Host "[ERROR] GitHub deletion failed" -ForegroundColor Red
        }
    }

    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_TOKEN"]) {
        if (-not (Remove-GiteeRepo -config $config)) {
            Write-Host "[ERROR] Gitee deletion failed" -ForegroundColor Red
        }
    }

    Reset-Remotes

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[DONE] Remote repos deleted!" -ForegroundColor Green
    Write-Host "========================================"
}

# ============================================================
# Execute Reset
# ============================================================
function Do-Reset {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Git Dual Platform - Reset Local Config" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    Write-Host "WARNING: This will clean local git configuration:" -ForegroundColor Yellow
    Write-Host "  - Remove all remotes (github, gitee)"
    Write-Host "  - Remove pushall alias"
    Write-Host "  - Local files will NOT be deleted"
    Write-Host ""

    $confirm = Read-Host "Confirm reset? (type yes to confirm)"
    if ($confirm -ne "yes") {
        Write-Host "[INFO] Cancelled" -ForegroundColor Cyan
        exit 0
    }

    # Remove all remotes
    $remotes = git remote 2>$null
    if ($remotes) {
        foreach ($remote in $remotes) {
            git remote remove $remote 2>$null | Out-Null
            Write-Host "[OK] Removed remote: $remote" -ForegroundColor Green
        }
    } else {
        Write-Host "[INFO] No remotes to remove" -ForegroundColor Cyan
    }

    # Remove pushall alias
    git config --local --unset-all alias.pushall 2>$null | Out-Null
    Write-Host "[OK] Removed pushall alias" -ForegroundColor Green

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[DONE] Local git config reset!" -ForegroundColor Green
    Write-Host "Run '.\git-full-local.ps1' to reinitialize" -ForegroundColor Cyan
    Write-Host "========================================"
}

# ============================================================
# Execute Clean
# ============================================================
function Do-Clean {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Git Dual Platform - Complete Clean" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    $projectName = Get-ProjectName
    $config = Load-Config

    Write-Host "WARNING: This will COMPLETELY remove the local git repository:" -ForegroundColor Red
    Write-Host "  - Delete .git directory"
    Write-Host "  - Remove all remotes and aliases"
    Write-Host "  - WARNING: This cannot be undone!" -ForegroundColor Red
    Write-Host ""

    # Check remote repo status
    $githubExists = $false
    $giteeExists = $false

    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        Write-Host "[INFO] Checking GitHub repo status..." -ForegroundColor Cyan
        if (Test-RepoExists -platform "github" -config $config) {
            $githubExists = $true
            Write-Host "  [WARN] GitHub repo still exists: https://github.com/$username/$projectName" -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] GitHub repo already deleted" -ForegroundColor Green
        }
    }

    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        Write-Host "[INFO] Checking Gitee repo status..." -ForegroundColor Cyan
        if (Test-RepoExists -platform "gitee" -config $config) {
            $giteeExists = $true
            Write-Host "  [WARN] Gitee repo still exists: https://gitee.com/$username/$projectName" -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] Gitee repo already deleted" -ForegroundColor Green
        }
    }

    if ($githubExists -or $giteeExists) {
        Write-Host ""
        Write-Host "[WARN] Remote repos still exist." -ForegroundColor Yellow
        Write-Host "[WARN] Run '.\git-full-local.ps1 --delete' to delete remotes first." -ForegroundColor Yellow
        Write-Host ""
    }

    $confirm = Read-Host "Type 'yes' to confirm complete removal:"
    if ($confirm -ne "yes") {
        Write-Host "[INFO] Cancelled" -ForegroundColor Cyan
        exit 0
    }

    if (Test-Path ".git") {
        Remove-Item -Path ".git" -Recurse -Force
        Write-Host "[OK] Removed .git directory" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No .git directory found" -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[DONE] Local git repository removed!" -ForegroundColor Green
    if ($githubExists -or $giteeExists) {
        Write-Host "IMPORTANT: Run '.\git-full-local.ps1 --delete' to clean remote repos" -ForegroundColor Yellow
    }
    Write-Host "Run '.\git-full-local.ps1' to start fresh" -ForegroundColor Cyan
    Write-Host "========================================"
}

# ============================================================
# Execute Init
# ============================================================
function Do-Init {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Git Dual Platform Full Initialization" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    $config = Load-Config

    if (-not (Test-Tokens -config $config)) {
        exit 1
    }

    Test-SSH -config $config

    Initialize-Git -config $config

    if (-not (New-GitHubRepo -config $config)) {
        Write-Host "[ERROR] GitHub repo creation failed, exiting" -ForegroundColor Red
        exit 1
    }

    if (-not (New-GiteeRepo -config $config)) {
        Write-Host "[ERROR] Gitee repo creation failed, rolling back..." -ForegroundColor Red
        Reset-Remotes
        exit 1
    }

    Set-Remotes -config $config

    if (-not (Initialize-FirstCommit)) {
        Write-Host "[ERROR] Commit failed, rolling back..." -ForegroundColor Red
        Reset-Remotes
        exit 1
    }

    if (-not (Sync-All)) {
        Write-Host "[ERROR] Push failed, may need manual intervention" -ForegroundColor Red
        exit 1
    }

    Set-PushAllAlias

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[DONE] Dual platform project ready!" -ForegroundColor Green
    Write-Host "----------------------------------------"
    Write-Host "Next steps:"
    Write-Host "  git add ."
    Write-Host "  git commit -m 'update'"
    Write-Host "  git pushall"
    Write-Host "========================================"
}

# ============================================================
# Main
# ============================================================
function Main {
    if ($Help) {
        Show-Help
        return
    }

    if ($Clean) {
        Do-Clean
    } elseif ($Reset) {
        Do-Reset
    } elseif ($Delete) {
        Do-Delete
    } else {
        Do-Init
    }
}

Main