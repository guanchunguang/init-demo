# ============================================================
# SSH Key and Config Generator - Git Dual Platform
# ============================================================
# Functions:
#   - Generate SSH keygen commands
#   - Generate SSH config
#   - (Optional) Push public keys to GitHub/Gitee via API
#   - (Optional) Verify SSH connection
#   - (Optional) List keys from platforms
#   - (Optional) Delete keys from platforms
#
# Usage (Unix-style parameters for consistency with .sh):
#   .\ssh-init-config.ps1                    # Show info only
#   .\ssh-init-config.ps1 --push-key         # Show + push keys
#   .\ssh-init-config.ps1 --verify-ssh       # Show + verify SSH
#   .\ssh-init-config.ps1 --list-keys         # Show + list platform keys
#   .\ssh-init-config.ps1 --delete-key <platform> <key_id>  # Delete platform key
#   .\ssh-init-config.ps1 --all              # Show + push keys + verify SSH
#   .\ssh-init-config.ps1 --help             # Show help
#
# Platform: Windows PowerShell
# ============================================================

# Script directory
$SCRIPT_DIR = $PSScriptRoot
$CONFIG_FILE = "$SCRIPT_DIR\.env"
$SSH_DIR = "$env:USERPROFILE\.ssh"

# ============================================================
# Parse Arguments (Unix-style for consistency with .sh)
# ============================================================
$ACTION = "display"
$DELETE_PLATFORM = ""
$DELETE_KEY_ID = ""

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]

    switch ($arg) {
        "--push-key" { $ACTION = "push-key" }
        "--verify-ssh" { $ACTION = "verify-ssh" }
        "--list-keys" { $ACTION = "list-keys" }
        "--delete-key" {
            $ACTION = "delete-key"
            if ($i + 2 -lt $args.Count) {
                $DELETE_PLATFORM = $args[$i + 1]
                $DELETE_KEY_ID = $args[$i + 2]
                $i += 2
            }
        }
        "--all" { $ACTION = "all" }
        { $_ -eq "--help" -or $_ -eq "-h" } { $ACTION = "help" }
    }
    $i++
}

# ============================================================
# Show Help
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host "SSH Key and Config Generator - Git Dual Platform" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\ssh-init-config.ps1                    # Show info only (default)"
    Write-Host "  .\ssh-init-config.ps1 --push-key          # Show + push keys to platforms"
    Write-Host "  .\ssh-init-config.ps1 --verify-ssh        # Show + verify SSH connection"
    Write-Host "  .\ssh-init-config.ps1 --list-keys        # Show + list platform keys"
    Write-Host "  .\ssh-init-config.ps1 --delete-key <platform> <key_id>  # Delete platform key"
    Write-Host "  .\ssh-init-config.ps1 --all              # Show + push keys + verify SSH"
    Write-Host "  .\ssh-init-config.ps1 --help             # Show help"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  --push-key     Push public keys to GitHub/Gitee via API (requires Token)"
    Write-Host "  --verify-ssh   Verify SSH connection"
    Write-Host "  --list-keys    List public keys from platforms"
    Write-Host "  --delete-key   Delete public key from platform (requires platform and key_id)"
    Write-Host "  --all          Run all operations (--push-key + --verify-ssh)"
    Write-Host ""
    Write-Host "DeleteKey Examples:" -ForegroundColor Yellow
    Write-Host '  .\ssh-init-config.ps1 --delete-key github 123456'
    Write-Host '  .\ssh-init-config.ps1 --delete-key gitee 789012'
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
# Show SSH Keygen Commands
# ============================================================
function Show-Commands {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Execute the following commands to generate SSH keys" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        $keyFile = "id_ed25519_github_$username"
        Write-Host "# GitHub - $username"
        $cmd = "ssh-keygen -t ed25519 -f `"$SSH_DIR\$keyFile`" -C `"$($config['GIT_USER_EMAIL'])`""
        Write-Host $cmd
        Write-Host ""
    }

    # Gitee
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        $keyFile = "id_ed25519_gitee_$username"
        Write-Host "# Gitee - $username"
        $cmd = "ssh-keygen -t ed25519 -f `"$SSH_DIR\$keyFile`" -C `"$($config['GIT_USER_EMAIL'])`""
        Write-Host $cmd
        Write-Host ""
    }
}

# ============================================================
# Show SSH Config Content
# ============================================================
function Show-Config {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SSH Config Content" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Add the following to ~/.ssh/config:"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        $sshHost = $config["GITHUB_HOST"]
        $keyFile = "id_ed25519_github_$username"

        Write-Host "# GitHub - $username"
        Write-Host "Host $sshHost"
        Write-Host "    HostName github.com"
        Write-Host "    User git"
        Write-Host "    IdentityFile $SSH_DIR\$keyFile"
        Write-Host "    IdentitiesOnly yes"
        Write-Host ""
    }

    # Gitee
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        $sshHost = $config["GITEE_HOST"]
        $keyFile = "id_ed25519_gitee_$username"

        Write-Host "# Gitee - $username"
        Write-Host "Host $sshHost"
        Write-Host "    HostName gitee.com"
        Write-Host "    User git"
        Write-Host "    IdentityFile $SSH_DIR\$keyFile"
        Write-Host "    IdentitiesOnly yes"
        Write-Host ""
    }
}

# ============================================================
# Show Public Keys
# ============================================================
function Show-PublicKeys {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Public Key Content" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_github_$username.pub"

        if (Test-Path $pubKeyFile) {
            $content = Get-Content $pubKeyFile -Raw
            Write-Host "[GitHub - $username]"
            Write-Host $content
        } else {
            Write-Host "[GitHub - $username] Key not found, run ssh-keygen first" -ForegroundColor Yellow
        }
    }

    # Gitee
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_gitee_$username.pub"

        if (Test-Path $pubKeyFile) {
            $content = Get-Content $pubKeyFile -Raw
            Write-Host "[Gitee - $username]"
            Write-Host $content
        } else {
            Write-Host "[Gitee - $username] Key not found, run ssh-keygen first" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# Push Public Key to GitHub via API
# ============================================================
function Push-Key-ToGitHub {
    param($title, $pubKeyFile, $token)

    if (-not (Test-Path $pubKeyFile)) {
        Write-Host "  [SKIP] Key file not found: $pubKeyFile" -ForegroundColor Yellow
        return $false
    }

    $keyContent = Get-Content $pubKeyFile -Raw
    $keyContent = $keyContent.Trim()

    # Check if key already exists
    $match = Test-KeyMatch -platform "github" -localPubKey $keyContent -token $token
    if ($match.matched) {
        Write-Host "  [SKIP] Key already registered on GitHub (ID: $($match.id), Title: $($match.title))" -ForegroundColor Yellow
        return $true
    }

    try {
        $body = @{
            title = $title
            key = $keyContent
            type = "authentication_key"
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "https://api.github.com/user/keys" `
            -Method POST `
            -Headers @{
                "Authorization" = "token $token"
                "Accept" = "application/vnd.github.v3+json"
            } `
            -ContentType "application/json" `
            -Body $body `
            -ErrorAction Stop

        if ($response.id) {
            Write-Host "  [OK] Added to GitHub: $($response.title) (ID: $($response.id))" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "  [FAIL] GitHub add failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $false
}

# ============================================================
# Push Public Key to Gitee via API
# ============================================================
function Push-Key-ToGitee {
    param($title, $pubKeyFile, $token)

    if (-not (Test-Path $pubKeyFile)) {
        Write-Host "  [SKIP] Key file not found: $pubKeyFile" -ForegroundColor Yellow
        return $false
    }

    $keyContent = Get-Content $pubKeyFile -Raw
    $keyContent = $keyContent.Trim()

    # Check if key already exists
    $match = Test-KeyMatch -platform "gitee" -localPubKey $keyContent -token $token
    if ($match.matched) {
        Write-Host "  [SKIP] Key already registered on Gitee (ID: $($match.id), Title: $($match.title))" -ForegroundColor Yellow
        return $true
    }

    try {
        $response = Invoke-RestMethod -Uri "https://gitee.com/api/v5/user/keys" `
            -Method POST `
            -Body @{
                access_token = $token
                title = $title
                key = $keyContent
            } `
            -ErrorAction Stop

        if ($response.id) {
            Write-Host "  [OK] Added to Gitee: $($response.title) (ID: $($response.id))" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "  [FAIL] Gitee add failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    return $false
}

# ============================================================
# Push Keys to Platforms
# ============================================================
function Push-Keys {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Pushing public keys to platforms via API" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_USER") -and $config["GITHUB_USER"]) {
        $username = $config["GITHUB_USER"]
        $token = $config["GITHUB_TOKEN"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_github_$username.pub"

        if ($token) {
            Write-Host "[INFO] Adding GitHub public key: $username..." -ForegroundColor Cyan
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $title = "ssh-init-config $timestamp $username"
            Push-Key-ToGitHub -title $title -pubKeyFile $pubKeyFile -token $token
        } else {
            Write-Host "[WARN] GITHUB_TOKEN not configured" -ForegroundColor Yellow
        }
    }

    # Gitee
    if ($config.ContainsKey("GITEE_USER") -and $config["GITEE_USER"]) {
        $username = $config["GITEE_USER"]
        $token = $config["GITEE_TOKEN"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_gitee_$username.pub"

        if ($token) {
            Write-Host "[INFO] Adding Gitee public key: $username..." -ForegroundColor Cyan
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $title = "ssh-init-config $timestamp $username"
            Push-Key-ToGitee -title $title -pubKeyFile $pubKeyFile -token $token
        } else {
            Write-Host "[WARN] GITEE_TOKEN not configured" -ForegroundColor Yellow
        }
    }

    Write-Host ""
}

# ============================================================
# Verify SSH Connection
# ============================================================
function Verify-SSH {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Verifying SSH Connection" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_HOST") -and $config["GITHUB_HOST"]) {
        $sshHost = $config["GITHUB_HOST"]
        $username = $config["GITHUB_USER"]
        $token = $config["GITHUB_TOKEN"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_github_$username.pub"

        Write-Host "[GitHub - $username]" -ForegroundColor Cyan
        if (Test-Path $pubKeyFile) {
            $pubKeyContent = Get-Content $pubKeyFile -Raw
            $pubKeyContent = $pubKeyContent.Trim()
            Write-Host "  Local public key: $pubKeyContent"
        } else {
            Write-Host "  [WARN] Local public key not found: $pubKeyFile" -ForegroundColor Yellow
            $pubKeyContent = $null
        }

        Write-Host "[INFO] Testing $sshHost ..." -ForegroundColor Cyan
        $sshSuccess = $false
        try {
            $result = ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$sshHost" 2>&1

            if ($result -match "Hi\s+|successfully authenticated") {
                Write-Host "  [OK] $sshHost SSH connection OK" -ForegroundColor Green
                $sshSuccess = $true
            } else {
                Write-Host "  [WARN] $sshHost response unexpected: $result" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [FAIL] $sshHost SSH connection failed: $_" -ForegroundColor Red
        }

        # Key matching check
        if (-not $sshSuccess -and $pubKeyContent -and $token) {
            $match = Test-KeyMatch -platform "github" -localPubKey $pubKeyContent -token $token
            if ($match.matched) {
                Write-Host "  [MISMATCH] Local key registered as ID:$($match.id) '$($match.title)'" -ForegroundColor Magenta
            } else {
                Write-Host "  [MISMATCH] Local key NOT registered on GitHub" -ForegroundColor Magenta
            }
        }
        Write-Host ""
    }

    # Gitee
    if ($config.ContainsKey("GITEE_HOST") -and $config["GITEE_HOST"]) {
        $sshHost = $config["GITEE_HOST"]
        $username = $config["GITEE_USER"]
        $token = $config["GITEE_TOKEN"]
        $pubKeyFile = "$SSH_DIR\id_ed25519_gitee_$username.pub"

        Write-Host "[Gitee - $username]" -ForegroundColor Cyan
        if (Test-Path $pubKeyFile) {
            $pubKeyContent = Get-Content $pubKeyFile -Raw
            $pubKeyContent = $pubKeyContent.Trim()
            Write-Host "  Local public key: $pubKeyContent"
        } else {
            Write-Host "  [WARN] Local public key not found: $pubKeyFile" -ForegroundColor Yellow
            $pubKeyContent = $null
        }

        Write-Host "[INFO] Testing $sshHost ..." -ForegroundColor Cyan
        $sshSuccess = $false
        try {
            $result = ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$sshHost" 2>&1

            if ($result -match "Hi\s+|successfully authenticated") {
                Write-Host "  [OK] $sshHost SSH connection OK" -ForegroundColor Green
                $sshSuccess = $true
            } else {
                Write-Host "  [WARN] $sshHost response unexpected: $result" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [FAIL] $sshHost SSH connection failed: $_" -ForegroundColor Red
        }

        # Key matching check
        if (-not $sshSuccess -and $pubKeyContent -and $token) {
            $match = Test-KeyMatch -platform "gitee" -localPubKey $pubKeyContent -token $token
            if ($match.matched) {
                Write-Host "  [MISMATCH] Local key registered as ID:$($match.id) '$($match.title)'" -ForegroundColor Magenta
            } else {
                Write-Host "  [MISMATCH] Local key NOT registered on Gitee" -ForegroundColor Magenta
            }
        }
        Write-Host ""
    }
}

# ============================================================
# Get GitHub registered keys
# ============================================================
function Get-GitHubKeys {
    param($token)

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/keys" `
            -Method GET `
            -Headers @{
                "Authorization" = "Bearer $token"
                "Accept" = "application/vnd.github.v3+json"
            } `
            -ErrorAction Stop
        return $response
    } catch {
        return @()
    }
}

# ============================================================
# Get Gitee registered keys
# ============================================================
function Get-GiteeKeys {
    param($token)

    try {
        $response = Invoke-RestMethod -Uri "https://gitee.com/api/v5/user/keys?access_token=$token" `
            -Method GET `
            -ErrorAction Stop
        return $response
    } catch {
        return @()
    }
}

# ============================================================
# Test if local key is registered on platform
# ============================================================
function Test-KeyMatch {
    param($platform, $localPubKey, $token)

    $localKey = $localPubKey.Trim()

    if ($platform -eq "github") {
        # GitHub API returns keys WITHOUT comment (format: "ssh-ed25519 AAA...XXX")
        $parts = $localKey -split '\s+'
        $localKeyNoComment = $parts[0] + ' ' + $parts[1]
        $platformKeys = Get-GitHubKeys -token $token
        foreach ($pk in $platformKeys) {
            if ($pk.key -eq $localKeyNoComment) {
                return @{ matched = $true; id = $pk.id; title = $pk.title }
            }
        }
    } elseif ($platform -eq "gitee") {
        # Gitee API returns keys WITH comment (format: "ssh-ed25519 AAA...XXX user@email.com")
        $platformKeys = Get-GiteeKeys -token $token
        foreach ($pk in $platformKeys) {
            if ($pk.key -eq $localKey) {
                return @{ matched = $true; id = $pk.id; title = $pk.title }
            }
        }
    }

    return @{ matched = $false; id = $null; title = $null }
}

# ============================================================
# List Keys from GitHub
# ============================================================
function List-Keys-GitHub {
    param($token)

    Write-Host "[INFO] GitHub public key list" -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/keys" `
            -Method GET `
            -Headers @{
                "Authorization" = "token $token"
                "Accept" = "application/vnd.github.v3+json"
            } `
            -ErrorAction Stop

        foreach ($key in $response) {
            Write-Host "  ID: $($key.id) | Title: $($key.title)"
        }
        Write-Host ""
    } catch {
        Write-Host "  [WARN] Cannot get GitHub public key list: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ============================================================
# List Keys from Gitee
# ============================================================
function List-Keys-Gitee {
    param($token)

    Write-Host "[INFO] Gitee public key list" -ForegroundColor Cyan

    try {
        $response = Invoke-RestMethod -Uri "https://gitee.com/api/v5/user/keys?access_token=$token" `
            -Method GET `
            -ErrorAction Stop

        foreach ($key in $response) {
            Write-Host "  ID: $($key.id) | Title: $($key.title)"
        }
        Write-Host ""
    } catch {
        Write-Host "  [WARN] Cannot get Gitee public key list: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
    }
}

# ============================================================
# List Keys from Platforms
# ============================================================
function List-Keys {
    param($config)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "List platform SSH public keys" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    # GitHub
    if ($config.ContainsKey("GITHUB_TOKEN") -and $config["GITHUB_TOKEN"]) {
        List-Keys-GitHub -token $config["GITHUB_TOKEN"]
    } else {
        Write-Host "[WARN] GITHUB_TOKEN not configured" -ForegroundColor Yellow
    }

    # Gitee
    if ($config.ContainsKey("GITEE_TOKEN") -and $config["GITEE_TOKEN"]) {
        List-Keys-Gitee -token $config["GITEE_TOKEN"]
    } else {
        Write-Host "[WARN] GITEE_TOKEN not configured" -ForegroundColor Yellow
    }
}

# ============================================================
# Delete Key from GitHub
# ============================================================
function Delete-Key-GitHub {
    param($keyId, $token)

    Write-Host "[INFO] Deleting GitHub public key: $keyId" -ForegroundColor Cyan

    try {
        $null = Invoke-WebRequest -Uri "https://api.github.com/user/keys/$keyId" `
            -Method DELETE `
            -Headers @{
                "Authorization" = "token $token"
                "Accept" = "application/vnd.github.v3+json"
            } `
            -ErrorAction Stop

        Write-Host "  [OK] GitHub public key deleted (ID: $keyId)" -ForegroundColor Green
        return $true
    } catch {
        if ($_.Exception.Response) {
            $httpCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  [FAIL] GitHub public key delete failed (HTTP $httpCode)" -ForegroundColor Red
        } else {
            Write-Host "  [FAIL] GitHub public key delete failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

# ============================================================
# Delete Key from Gitee
# ============================================================
function Delete-Key-Gitee {
    param($keyId, $token)

    $keyIdStr = [string]$keyId
    Write-Host "[INFO] Deleting Gitee public key: $keyIdStr" -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri "https://gitee.com/api/v5/user/keys/${keyIdStr}?access_token=$token" `
            -Method DELETE -ErrorAction Stop
        $httpCode = [int]$response.StatusCode
        if ($httpCode -eq 204 -or $httpCode -eq 200) {
            Write-Host "  [OK] Gitee public key deleted (ID: $keyIdStr)" -ForegroundColor Green
            return $true
        }
        Write-Host "  [FAIL] Gitee public key delete failed (HTTP $httpCode)" -ForegroundColor Red
        return $false
    } catch {
        if ($_.Exception.Response) {
            $httpCode = [int]$_.Exception.Response.StatusCode
            Write-Host "  [FAIL] Gitee public key delete failed (HTTP $httpCode)" -ForegroundColor Red
        } else {
            Write-Host "  [FAIL] Gitee public key delete failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

# ============================================================
# Delete Key from Platform
# ============================================================
function Delete-Key {
    param($platform, $keyId, $config)

    if ([string]::IsNullOrEmpty($platform) -or [string]::IsNullOrEmpty($keyId)) {
        Write-Host "[ERROR] Usage: .\ssh-init-config.ps1 --delete-key <platform> <key_id>" -ForegroundColor Red
        Write-Host "  platform: github or gitee"
        Write-Host "  key_id: from --list-keys output"
        return
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Delete platform SSH public key" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    switch ($platform.ToLower()) {
        "github" {
            if (-not $config.ContainsKey("GITHUB_TOKEN") -or [string]::IsNullOrEmpty($config["GITHUB_TOKEN"])) {
                Write-Host "[ERROR] GITHUB_TOKEN not configured" -ForegroundColor Red
                return
            }
            Delete-Key-GitHub -keyId $keyId -token $config["GITHUB_TOKEN"]
        }
        "gitee" {
            if (-not $config.ContainsKey("GITEE_TOKEN") -or [string]::IsNullOrEmpty($config["GITEE_TOKEN"])) {
                Write-Host "[ERROR] GITEE_TOKEN not configured" -ForegroundColor Red
                return
            }
            Delete-Key-Gitee -keyId $keyId -token $config["GITEE_TOKEN"]
        }
        default {
            Write-Host "[ERROR] Unknown platform: $platform" -ForegroundColor Red
            Write-Host "  platform must be: github or gitee"
        }
    }

    Write-Host ""
}

# ============================================================
# Main
# ============================================================
function Main {
    # Handle help first - no config needed
    if ($ACTION -eq "help") {
        Show-Help
        return
    }

    $config = Load-Config

    # list-keys, verify-ssh, delete-key only show their specific output, no default display
    if ($ACTION -eq "list-keys" -or $ACTION -eq "verify-ssh" -or $ACTION -eq "delete-key") {
        if ($ACTION -eq "list-keys") {
            List-Keys -config $config
        } elseif ($ACTION -eq "verify-ssh") {
            Verify-SSH -config $config
        } else {
            Delete-Key -platform $DELETE_PLATFORM -keyId $DELETE_KEY_ID -config $config
        }
        return
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SSH Key and Config Generator - Git Dual Platform" -ForegroundColor Cyan
    Write-Host "========================================"
    Write-Host ""

    Show-Commands -config $config
    Show-Config -config $config
    Show-PublicKeys -config $config

    switch ($ACTION) {
        "all" {
            Push-Keys -config $config
            Verify-SSH -config $config
        }
        "push-key" {
            Push-Keys -config $config
        }
        "delete-key" {
            Delete-Key -platform $DELETE_PLATFORM -keyId $DELETE_KEY_ID -config $config
        }
        "display" {
            Write-Host ""
            Write-Host "[HINT] To push keys or verify SSH, use the following parameters:" -ForegroundColor Yellow
            Write-Host "  .\ssh-init-config.ps1 --push-key         # Push keys to platforms"
            Write-Host "  .\ssh-init-config.ps1 --verify-ssh       # Verify SSH connection"
            Write-Host "  .\ssh-init-config.ps1 --list-keys        # List platform public keys"
            Write-Host '  .\ssh-init-config.ps1 --delete-key <platform> <key_id>  # Delete public key'
            Write-Host "  .\ssh-init-config.ps1 --all            # Run all"
        }
    }

    Write-Host ""
    Write-Host "[DONE]" -ForegroundColor Green
}

Main
