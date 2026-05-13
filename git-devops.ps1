# ============================================================
# Git DevOps CLI - Cross-Platform Git Automation Tool
# ============================================================
# Platform: Windows PowerShell
#
# Usage:
#   .\git-devops.ps1 <module> <action> [options]
#   .\git-devops.ps1 ssh create -Platform github
#   .\git-devops.ps1 repo create -Platform github
#   .\git-devops.ps1 git init
#   .\git-devops.ps1 all init
#   .\git-devops.ps1 -Help
#
# Global Options:
#   -Platform    Target platform: github / gitee
#   -Force       Overwrite existing resources
#   -Yes         Auto-confirm dangerous operations
#   -Debug       Show DEBUG level logs
#   -Quiet       Show only WARN/ERROR logs
# ============================================================

# ============================================================
# Parameters (MUST come first, after comments only)
# ============================================================
param(
    [string]$Module = "",
    [string]$Action = "",
    [string]$Platform = "",
    [switch]$Force,
    [switch]$Yes,
    [switch]$Debug,
    [switch]$Quiet,
    [switch]$Help,
    [string]$RepoName = ""
)

# ============================================================
# Encoding (must be after param block)
# ============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Strict mode
Set-StrictMode -Version Latest

# ============================================================
# Global Variables
# ============================================================
$script:SCRIPT_DIR = $PSScriptRoot
$script:CONFIG_FILE = Join-Path $PSScriptRoot ".env"
$script:SSH_DIR = Join-Path $env:USERPROFILE ".ssh"
$script:REPO_NAME = $RepoName

$script:GITHUB_ACCOUNTS = "[]"
$script:GITEE_ACCOUNTS = "[]"
$script:GIT_USER_NAME = ""
$script:GIT_USER_EMAIL = ""

# ============================================================
# Colors
# ============================================================
$script:COLOR_DEBUG = "Gray"
$script:COLOR_INFO = "Cyan"
$script:COLOR_WARN = "Yellow"
$script:COLOR_ERROR = "Red"
$script:COLOR_SUCCESS = "Green"

# ============================================================
# Logging Function
# ============================================================
function Write-Log {
    param(
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        [string]$Message = ""
    )

    if ($Quiet -and ($Level -eq "INFO" -or $Level -eq "DEBUG")) {
        return
    }

    if ($Level -eq "DEBUG" -and -not $Debug) {
        return
    }

    $color = switch ($Level) {
        "DEBUG"   { $COLOR_DEBUG }
        "INFO"    { $COLOR_INFO }
        "WARN"    { $COLOR_WARN }
        "ERROR"   { $COLOR_ERROR }
        "SUCCESS" { $COLOR_SUCCESS }
        default   { $COLOR_INFO }
    }

    $tag = switch ($Level) {
        "DEBUG"   { "[DEBUG]" }
        "INFO"    { "[INFO]" }
        "WARN"    { "[WARN]" }
        "ERROR"   { "[ERROR]" }
        "SUCCESS" { "[OK]" }
        default   { "[INFO]" }
    }

    Write-Host -ForegroundColor $color "$tag $Message"
}

# ============================================================
# Get OS Type
# Returns: win / lin / mac / wsl
# ============================================================
function Get-OsType {
    $osType = "lin"

    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        # Check if running under WSL
        if (Test-Path "/proc/version") {
            $versionContent = Get-Content "/proc/version" -Raw -ErrorAction SilentlyContinue
            if ($versionContent -match "Microsoft" -or $versionContent -match "WSL") {
                $osType = "wsl"
            } else {
                $osType = "win"
            }
        } else {
            $osType = "win"
        }
    }
    elseif ($IsMacOS) {
        $osType = "mac"
    }
    elseif ($IsLinux) {
        $osType = "lin"
    }

    return $osType
}

# ============================================================
# Generate SSH Key Title with platform and system info
# Format: git-devops-{os}-{platform}-{user}-{timestamp}
# Example: git-devops-win-gitee-guanchunguang-202605131150
# ============================================================
function New-SshKeyTitle {
    param(
        [string]$Platform,
        [string]$User
    )

    $osType = Get-OsType
    $timestamp = Get-Date -Format "yyyyMMddHHmm"

    return "git-devops-${osType}-${Platform}-${User}-${timestamp}"
}

# ============================================================
# Show Help
# ============================================================
function Show-Help {
    Write-Host ""
    Write-Host -ForegroundColor Cyan "Git DevOps CLI - Cross-Platform Git Automation Tool"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Usage:"
    Write-Host '  .\git-devops.ps1 <module> <action> [options]'
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Modules:"
    Write-Host "  ssh      SSH key management"
    Write-Host "  repo     Remote repo management"
    Write-Host "  git      Git local config"
    Write-Host "  all      One-command init"
    Write-Host "  clean    Clean operations"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Examples:"
    Write-Host "  .\git-devops.ps1 ssh create -Platform github"
    Write-Host "  .\git-devops.ps1 ssh verify -Platform github"
    Write-Host "  .\git-devops.ps1 repo create -Platform github"
    Write-Host "  .\git-devops.ps1 repo delete -Platform github"
    Write-Host "  .\git-devops.ps1 git init"
    Write-Host "  .\git-devops.ps1 all init"
    Write-Host "  .\git-devops.ps1 clean reset"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Global Options:"
    Write-Host "  -Platform    Target platform: github / gitee"
    Write-Host "  -Force       Overwrite existing resources"
    Write-Host "  -Yes         Auto-confirm dangerous operations"
    Write-Host "  -Debug       Show DEBUG level logs"
    Write-Host "  -Quiet       Show only WARN/ERROR logs"
    Write-Host "  -Help        Show this help"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "SSH Module Actions:"
    Write-Host "  create         Create SSH key pair"
    Write-Host "  push           Push public key to platform"
    Write-Host "  verify         Verify SSH connection"
    Write-Host "  agent-start    Start ssh-agent"
    Write-Host "  agent-status   Check agent status"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Repo Module Actions:"
    Write-Host "  create         Create remote repo"
    Write-Host "  delete         Delete remote repo"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Git Module Actions:"
    Write-Host "  init           Initialize Git repo"
    Write-Host "  remote         Configure remotes"
    Write-Host "  push           Push to remote"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "All Module Actions:"
    Write-Host "  init           One-command init"
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Clean Module Actions:"
    Write-Host "  reset          Clean local Git config"
    Write-Host "  clean          Delete .git directory"
    Write-Host ""
}

# ============================================================
# Load Config
# ============================================================
function Load-Config {
    if (-not (Test-Path $CONFIG_FILE)) {
        Write-Log ERROR "Config file not found: $CONFIG_FILE"
        Write-Log ERROR "Please copy env.example to .env first"
        exit 1
    }

    $content = Get-Content $CONFIG_FILE -Raw

    $lines = $content -split "`n" | ForEach-Object { $_.Trim() }
    foreach ($line in $lines) {
        if ($line -match "^#" -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match "^([^=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            switch ($key) {
                "GITHUB_ACCOUNTS" { $script:GITHUB_ACCOUNTS = $value }
                "GITEE_ACCOUNTS" { $script:GITEE_ACCOUNTS = $value }
                "GIT_USER_NAME" { $script:GIT_USER_NAME = $value }
                "GIT_USER_EMAIL" { $script:GIT_USER_EMAIL = $value }
            }
        }
    }

    Write-Log DEBUG "Config loaded: $CONFIG_FILE"
}

# ============================================================
# JSON Parsing Functions
# ============================================================
function Get-JsonAccounts {
    param([string]$Json)

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return @()
    }

    try {
        $result = $Json | ConvertFrom-Json
        if ($result -is [System.Array]) {
            return $result
        }
        # Single object - wrap in array
        return @($result)
    }
    catch {
        Write-Log DEBUG "Failed to parse JSON: $_"
        return @()
    }
}

function Get-AccountInfo {
    param(
        [string]$Platform,
        [string]$AccountsJson
    )

    $accounts = Get-JsonAccounts -Json $AccountsJson
    if (@($accounts).Count -eq 0) {
        return $null
    }

    foreach ($account in $accounts) {
        if ($account.user -and $account.token -and $account.host) {
            return @{
                User = $account.user
                Token = $account.token
                Host = $account.host
            }
        }
    }
    return $null
}

# ============================================================
# Get Account Config (for backward compatibility)
# ============================================================
function Get-AccountConfig {
    param(
        [string]$Platform,
        [string]$AccountsVar
    )

    $accountsJson = Get-Variable -Name $AccountsVar -ValueOnly
    $account = Get-AccountInfo -Platform $Platform -AccountsJson $accountsJson

    if ($account) {
        return "$($account.User):$($account.Token):$($account.Host)"
    }
    return ""
}

# ============================================================
# Confirm Action
# ============================================================
function Confirm-Action {
    param([string]$Message)

    if ($Yes) {
        Write-Log INFO "${Message} [auto-confirmed]"
        return $true
    }

    $answer = Read-Host -Prompt "$Message [y/N]"
    return ($answer -eq "Y" -or $answer -eq "y")
}

# ============================================================
# Get Project Name
# ============================================================
function Get-ProjectName {
    if ($REPO_NAME) {
        return $REPO_NAME
    }
    return (Split-Path -Leaf (Get-Location))
}

# ============================================================
# SSH Module
# ============================================================
function Invoke-SshModule {
    param([string]$Operation)

    switch ($Operation) {
        "create" { SSH-Create }
        "push" { SSH-Push }
        "verify" { SSH-Verify }
        "agent-start" { SSH-AgentStart }
        "agent-status" { SSH-AgentStatus }
        default {
            Write-Log ERROR "Unknown SSH operation: $Operation"
            Write-Log INFO "Supported SSH operations: create, push, verify, agent-start, agent-status"
            exit 1
        }
    }
}

# ============================================================
# SSH Create
# ============================================================
function SSH-Create {
    Write-Log INFO "Creating SSH key..."

    if (-not $Platform) {
        Write-Log ERROR "Please specify platform: -Platform github or -Platform gitee"
        exit 1
    }

    $accountsVar = switch ($Platform) {
        "github" { "GITHUB_ACCOUNTS" }
        "gitee" { "GITEE_ACCOUNTS" }
        default {
            Write-Log ERROR "Unknown platform: $Platform"
            exit 1
        }
    }

    $accountLine = Get-AccountConfig -Platform $Platform -AccountsVar $accountsVar
    if (-not $accountLine) {
        Write-Log ERROR "No $Platform account config found"
        exit 1
    }

    $parts = $accountLine -split ':'
    $user = $parts[0]

    $keyFile = "id_ed25519_${Platform}_${user}"
    $keyPath = Join-Path $SSH_DIR $keyFile
    $pubKeyPath = "${keyPath}.pub"

    if (Test-Path $keyPath) {
        if ($Force) {
            Write-Log WARN "SSH key exists, overwriting..."
            $backupSuffix = (Get-Date).UnixEpochSecond
            Move-Item -Path $keyPath -Destination "${keyPath}.backup_${backupSuffix}" -Force
            Move-Item -Path $pubKeyPath -Destination "${pubKeyPath}.backup_${backupSuffix}" -Force
        }
        else {
            Write-Log WARN "SSH key already exists: $keyPath"
            Write-Log INFO "Use -Force to overwrite"
            return
        }
    }

    $sshDir = $SSH_DIR
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    Write-Log INFO "Generating SSH key: $keyFile"
    ssh-keygen -t ed25519 -f $keyPath -C $GIT_USER_EMAIL -N ""

    Write-Log SUCCESS "SSH key created: $keyPath"
}

# ============================================================
# SSH Push
# ============================================================
function SSH-Push {
    Write-Log INFO "Pushing SSH public key to platform..."

    if (-not $Platform) {
        Write-Log ERROR "Please specify platform: -Platform github or -Platform gitee"
        exit 1
    }

    $accountsVar = switch ($Platform) {
        "github" { "GITHUB_ACCOUNTS" }
        "gitee" { "GITEE_ACCOUNTS" }
        default {
            Write-Log ERROR "Unknown platform: $Platform"
            exit 1
        }
    }

    $accountLine = Get-AccountConfig -Platform $Platform -AccountsVar $accountsVar
    if (-not $accountLine) {
        Write-Log ERROR "No $Platform account config found"
        exit 1
    }

    $parts = $accountLine -split ':'
    $user = $parts[0]
    $token = $parts[1]
    $targetHost = $parts[2]

    $keyFile = "id_ed25519_${Platform}_${user}"
    $pubKeyPath = Join-Path $SSH_DIR "${keyFile}.pub"

    if (-not (Test-Path $pubKeyPath)) {
        Write-Log ERROR "Public key not found: $pubKeyPath"
        Write-Log INFO "Run: .\git-devops.ps1 ssh create -Platform $Platform"
        exit 1
    }

    $keyContent = (Get-Content $pubKeyPath -Raw).Trim()
    $title = New-SshKeyTitle -Platform $Platform -User $user

    if ($Platform -eq "github") {
        SSH-Push-GitHub -User $user -Token $token -Title $title -KeyContent $keyContent
    }
    else {
        SSH-Push-Gitee -User $user -Token $token -Title $title -KeyContent $keyContent
    }
}

# ============================================================
# Push to GitHub
# ============================================================
function SSH-Push-GitHub {
    param(
        [string]$User,
        [string]$Token,
        [string]$Title,
        [string]$KeyContent
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github.v3+json"
        "Content-Type" = "application/json"
    }

    $body = @{
        title = $Title
        key = $KeyContent
        type = "authentication_key"
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/keys" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30

        if ($response.id) {
            Write-Log SUCCESS "Added to GitHub (ID: $($response.id))"
        }
    }
    catch {
        $errorDetail = $_.Exception.Response.StatusCode
        Write-Log ERROR "GitHub add failed: $errorDetail"
        exit 1
    }
}

# ============================================================
# Push to Gitee
# ============================================================
function SSH-Push-Gitee {
    param(
        [string]$User,
        [string]$Token,
        [string]$Title,
        [string]$KeyContent
    )

    $uri = "https://gitee.com/api/v5/user/keys"
    $body = @{
        access_token = $Token
        title = $Title
        key = $KeyContent
    }

    try {
        $response = Invoke-RestMethod -Uri $uri `
            -Method Post `
            -Body $body `
            -TimeoutSec 30

        if ($response.id) {
            Write-Log SUCCESS "Added to Gitee (ID: $($response.id))"
        }
    }
    catch {
        $errorDetail = $_.Exception.Message
        Write-Log ERROR "Gitee add failed: $errorDetail"
        exit 1
    }
}

# ============================================================
# SSH Verify
# ============================================================
function SSH-Verify {
    Write-Log INFO "Verifying SSH connection..."

    if (-not $Platform) {
        Write-Log ERROR "Please specify platform: -Platform github or -Platform gitee"
        exit 1
    }

    $accountsVar = switch ($Platform) {
        "github" { "GITHUB_ACCOUNTS" }
        "gitee" { "GITEE_ACCOUNTS" }
        default {
            Write-Log ERROR "Unknown platform: $Platform"
            exit 1
        }
    }

    $accountLine = Get-AccountConfig -Platform $Platform -AccountsVar $accountsVar
    if (-not $accountLine) {
        Write-Log ERROR "No $Platform account config found"
        exit 1
    }

    $parts = $accountLine -split ':'
    $user = $parts[0]
    $targetHost = $parts[2]

    Write-Log INFO "Testing $targetHost ..."

    try {
        $result = ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$targetHost" 2>&1
        if ($result -match "(Hi|successfully authenticated)") {
            Write-Log SUCCESS "$targetHost SSH connection OK"
        }
        else {
            Write-Log WARN "$targetHost response: $result"
            return 1
        }
    }
    catch {
        Write-Log WARN "$targetHost connection failed: $_"
        return 1
    }
}

# ============================================================
# SSH Agent Start
# ============================================================
function SSH-AgentStart {
    Write-Log INFO "Starting ssh-agent..."

    $agentPid = Get-Process ssh-agent -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Id
    if ($agentPid) {
        Write-Log INFO "ssh-agent already running (PID: $agentPid)"
    }
    else {
        $agentOutput = ssh-agent -s 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log SUCCESS "ssh-agent started"
            if ($agentOutput -match 'SSH_AUTH_SOCK=([^;]+);') {
                $env:SSH_AUTH_SOCK = $matches[1]
            }
            if ($agentOutput -match 'SSH_AGENT_PID=(\d+)') {
                $env:SSH_AGENT_PID = $matches[1]
            }
        }
        else {
            Write-Log ERROR "ssh-agent start failed: $agentOutput"
        }
    }
}

# ============================================================
# SSH Agent Status
# ============================================================
function SSH-AgentStatus {
    Write-Log INFO "Checking ssh-agent status..."

    $agentPid = Get-Process ssh-agent -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Id
    if ($agentPid) {
        Write-Log SUCCESS "ssh-agent running (PID: $agentPid)"

        Write-Log INFO "Loaded keys:"
        try {
            $keys = ssh-add -l 2>&1
            if ($keys -and $keys -notmatch "no keys") {
                $keys | ForEach-Object { Write-Host "  $_" }
            }
            else {
                Write-Log INFO "  No keys loaded"
            }
        }
        catch {
            Write-Log INFO "  No keys loaded"
        }
    }
    else {
        Write-Log WARN "ssh-agent not running"
        Write-Log INFO "Run: .\git-devops.ps1 ssh agent-start"
    }
}

# ============================================================
# Repo Module
# ============================================================
function Invoke-RepoModule {
    param([string]$Operation)

    switch ($Operation) {
        "create" { Repo-Create }
        "delete" { Repo-Delete }
        default {
            Write-Log ERROR "Unknown Repo operation: $Operation"
            Write-Log INFO "Supported Repo operations: create, delete"
            exit 1
        }
    }
}

# ============================================================
# Repo Create
# ============================================================
function Repo-Create {
    Write-Log INFO "Creating remote repo..."

    if (-not $Platform) {
        Write-Log ERROR "Please specify platform: -Platform github or -Platform gitee"
        exit 1
    }

    $accountsVar = switch ($Platform) {
        "github" { "GITHUB_ACCOUNTS" }
        "gitee" { "GITEE_ACCOUNTS" }
        default {
            Write-Log ERROR "Unknown platform: $Platform"
            exit 1
        }
    }

    $accountLine = Get-AccountConfig -Platform $Platform -AccountsVar $accountsVar
    if (-not $accountLine) {
        Write-Log ERROR "No $Platform account config found"
        exit 1
    }

    $parts = $accountLine -split ':'
    $user = $parts[0]
    $token = $parts[1]

    $repoName = Get-ProjectName

    if ($Platform -eq "github") {
        Repo-Create-GitHub -User $user -Token $token -RepoName $repoName
    }
    else {
        Repo-Create-Gitee -User $user -Token $token -RepoName $repoName
    }
}

# ============================================================
# Create GitHub Repo
# ============================================================
function Repo-Create-GitHub {
    param(
        [string]$User,
        [string]$Token,
        [string]$RepoName
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github.v3+json"
        "Content-Type" = "application/json"
    }

    $body = @{
        name = $RepoName
        private = $false
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 30

        if ($response.id) {
            Write-Log SUCCESS "GitHub repo created: $RepoName"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode -eq 422 -or $statusCode -eq 301) {
            Write-Log WARN "GitHub repo already exists: $RepoName"
        }
        else {
            Write-Log ERROR "GitHub repo creation failed (HTTP $statusCode)"
            exit 1
        }
    }
}

# ============================================================
# Create Gitee Repo
# ============================================================
function Repo-Create-Gitee {
    param(
        [string]$User,
        [string]$Token,
        [string]$RepoName
    )

    $uri = "https://gitee.com/api/v5/user/repos"
    $body = @{
        access_token = $Token
        name = $RepoName
        private = $false
    }

    try {
        $response = Invoke-RestMethod -Uri $uri `
            -Method Post `
            -Body $body `
            -TimeoutSec 30

        if ($response.id) {
            Write-Log SUCCESS "Gitee repo created: $RepoName"
        }
    }
    catch {
        $errorDetail = $_.Exception.Message
        if ($errorDetail -match "already exists") {
            Write-Log WARN "Gitee repo already exists: $RepoName"
        }
        else {
            Write-Log ERROR "Gitee repo creation failed: $errorDetail"
            exit 1
        }
    }
}

# ============================================================
# Repo Delete
# ============================================================
function Repo-Delete {
    Write-Log WARN "Deleting remote repo..."

    if (-not $Platform) {
        Write-Log ERROR "Please specify platform: -Platform github or -Platform gitee"
        exit 1
    }

    if (-not (Confirm-Action -Message "Delete remote repo?")) {
        Write-Log INFO "Cancelled"
        return
    }

    $accountsVar = switch ($Platform) {
        "github" { "GITHUB_ACCOUNTS" }
        "gitee" { "GITEE_ACCOUNTS" }
        default {
            Write-Log ERROR "Unknown platform: $Platform"
            exit 1
        }
    }

    $accountLine = Get-AccountConfig -Platform $Platform -AccountsVar $accountsVar
    if (-not $accountLine) {
        Write-Log ERROR "No $Platform account config found"
        exit 1
    }

    $parts = $accountLine -split ':'
    $user = $parts[0]
    $token = $parts[1]

    $repoName = Get-ProjectName

    if ($Platform -eq "github") {
        Repo-Delete-GitHub -User $user -Token $token -RepoName $repoName
    }
    else {
        Repo-Delete-Gitee -User $user -Token $token -RepoName $repoName
    }
}

# ============================================================
# Delete GitHub Repo
# ============================================================
function Repo-Delete-GitHub {
    param(
        [string]$User,
        [string]$Token,
        [string]$RepoName
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github.v3+json"
    }

    try {
        Invoke-WebRequest -Uri "https://api.github.com/repos/$User/$RepoName" `
            -Method Delete `
            -Headers $headers `
            -TimeoutSec 30

        Write-Log SUCCESS "GitHub repo deleted: $RepoName"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Log ERROR "GitHub repo deletion failed (HTTP $statusCode)"
        exit 1
    }
}

# ============================================================
# Delete Gitee Repo
# ============================================================
function Repo-Delete-Gitee {
    param(
        [string]$User,
        [string]$Token,
        [string]$RepoName
    )

    $uri = "https://gitee.com/api/v5/repos/$User/$RepoName?access_token=$Token"

    try {
        $response = Invoke-WebRequest -Uri $uri `
            -Method Delete `
            -TimeoutSec 30

        if ($response.StatusCode -eq 204 -or $response.StatusCode -eq 200) {
            Write-Log SUCCESS "Gitee repo deleted: $RepoName"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Log ERROR "Gitee repo deletion failed (HTTP $statusCode)"
        exit 1
    }
}

# ============================================================
# Git Module
# ============================================================
function Invoke-GitModule {
    param([string]$Operation)

    switch ($Operation) {
        "init" { Git-Init }
        "remote" { Git-Remote }
        "push" { Git-Push }
        default {
            Write-Log ERROR "Unknown Git operation: $Operation"
            Write-Log INFO "Supported Git operations: init, remote, push"
            exit 1
        }
    }
}

# ============================================================
# Git Init
# ============================================================
function Git-Init {
    Write-Log INFO "Initializing Git repo..."

    if (-not (Test-Path ".git")) {
        git init -b main
        Write-Log SUCCESS "Git repo created"
    }
    else {
        Write-Log INFO "Git repo already exists, skipping"

        $branches = git branch | Out-String
        if ($branches -match "master") {
            git branch -m master main
            Write-Log INFO "Branch renamed master -> main"
        }
    }

    if ($GIT_USER_NAME) {
        git config --local user.name $GIT_USER_NAME
        Write-Log DEBUG "Git user.name: $GIT_USER_NAME"
    }

    if ($GIT_USER_EMAIL) {
        git config --local user.email $GIT_USER_EMAIL
        Write-Log DEBUG "Git user.email: $GIT_USER_EMAIL"
    }
}

# ============================================================
# Git Remote
# ============================================================
function Git-Remote {
    Write-Log INFO "Configuring Git remotes..."

    if (-not (Test-Path ".git")) {
        Write-Log ERROR "Git repo not initialized"
        Write-Log INFO "Run: .\git-devops.ps1 git init"
        exit 1
    }

    $project = Get-ProjectName

    $existingRemotes = git remote | Out-String
    if ($existingRemotes) {
        $existingRemotes -split "`n" | ForEach-Object {
            $remote = $_.Trim()
            if ($remote) {
                git remote remove $remote 2>$null
            }
        }
    }

    $githubAccount = Get-AccountConfig -Platform "github" -AccountsVar "GITHUB_ACCOUNTS"
    if ($githubAccount) {
        $parts = $githubAccount -split ':'
        $user = $parts[0]
        $targetHost = $parts[2]
        $remoteUrl = "git@${targetHost}:${user}/$project.git"
        git remote add github $remoteUrl
        Write-Log SUCCESS "GitHub remote: github -> $remoteUrl"
    }

    $giteeAccount = Get-AccountConfig -Platform "gitee" -AccountsVar "GITEE_ACCOUNTS"
    if ($giteeAccount) {
        $parts = $giteeAccount -split ':'
        $user = $parts[0]
        $targetHost = $parts[2]
        $remoteUrl = "git@${targetHost}:${user}/$project.git"
        git remote add gitee $remoteUrl
        Write-Log SUCCESS "Gitee remote: gitee -> $remoteUrl"
    }

    $hasGithub = git remote | Out-String -Stream | Where-Object { $_ -eq "github" } | Measure-Object | Select-Object -ExpandProperty Count
    $hasGitee = git remote | Out-String -Stream | Where-Object { $_ -eq "gitee" } | Measure-Object | Select-Object -ExpandProperty Count

    if ($hasGithub -gt 0 -and $hasGitee -gt 0) {
        git config alias.pushall "!git push github main; git push gitee main"
        Write-Log SUCCESS "pushall alias configured"
    }
    elseif ($hasGithub -gt 0) {
        git config alias.pushall "!git push github main"
        Write-Log INFO "pushall alias configured (GitHub only)"
    }
    elseif ($hasGitee -gt 0) {
        git config alias.pushall "!git push gitee main"
        Write-Log INFO "pushall alias configured (Gitee only)"
    }
}

# ============================================================
# Git Push
# ============================================================
function Git-Push {
    Write-Log INFO "Pushing to remote..."

    if (-not (Test-Path ".git")) {
        Write-Log ERROR "Git repo not initialized"
        exit 1
    }

    if (-not $Platform) {
        git pushall
    }
    else {
        switch ($Platform) {
            "github" { git push github main }
            "gitee" { git push gitee main }
            default {
                Write-Log ERROR "Unknown platform: $Platform"
                exit 1
            }
        }
    }
}

# ============================================================
# All Module - One Command Init
# ============================================================
function Invoke-AllModule {
    param([string]$Operation)

    switch ($Operation) {
        "init" { All-Init }
        default {
            Write-Log ERROR "Unknown All operation: $Operation"
            Write-Log INFO "Supported All operations: init"
            exit 1
        }
    }
}

# ============================================================
# One-Command Init
# ============================================================
function All-Init {
    Write-Log INFO "========================================"
    Write-Log INFO "Git DevOps One-Command Init"
    Write-Log INFO "========================================"
    Write-Host ""

    foreach ($p in @("github", "gitee")) {
        $savedPlatform = $Platform
        $Platform = $p

        $accountsVar = if ($p -eq "github") { "GITHUB_ACCOUNTS" } else { "GITEE_ACCOUNTS" }

        $accountLine = Get-AccountConfig -Platform $p -AccountsVar $accountsVar

        if (-not $accountLine) {
            Write-Log WARN "Skipping platform ${p}: no account config"
            $Platform = $savedPlatform
            continue
        }

        $parts = $accountLine -split ':'
        $user = $parts[0]

        $keyFile = "id_ed25519_${p}_${user}"
        $keyPath = Join-Path $SSH_DIR $keyFile

        if (-not (Test-Path $keyPath)) {
            Write-Log INFO "[$p] Creating SSH key..."
            SSH-Create
        }
        else {
            Write-Log INFO "[$p] SSH key exists, skipping"
        }

        $Platform = $savedPlatform
    }

    Write-Host ""

    foreach ($p in @("github", "gitee")) {
        $savedPlatform = $Platform
        $Platform = $p

        $accountsVar = if ($p -eq "github") { "GITHUB_ACCOUNTS" } else { "GITEE_ACCOUNTS" }

        $accountLine = Get-AccountConfig -Platform $p -AccountsVar $accountsVar

        if (-not $accountLine) {
            Write-Log WARN "Skipping platform ${p}: no account config"
            $Platform = $savedPlatform
            continue
        }

        Write-Log INFO "[$p] Creating remote repo..."
        try {
            Repo-Create
        }
        catch {
            Write-Log WARN "[$p] Repo may already exist"
        }

        $Platform = $savedPlatform
    }

    Write-Host ""

    Write-Log INFO "Initializing Git repo..."
    Git-Init

    Write-Host ""

    Write-Log INFO "Configuring Git remotes..."
    Git-Remote

    Write-Host ""
    Write-Log SUCCESS "One-command init complete!"
    Write-Log INFO "Next steps:"
    Write-Log INFO "  git add ."
    Write-Log INFO '  git commit -m "init"'
    Write-Log INFO "  git pushall"
}

# ============================================================
# Clean Module
# ============================================================
function Invoke-CleanModule {
    param([string]$Operation)

    switch ($Operation) {
        "reset" { Clean-Reset }
        "clean" { Clean-Full }
        default {
            Write-Log ERROR "Unknown Clean operation: $Operation"
            Write-Log INFO "Supported Clean operations: reset, clean"
            exit 1
        }
    }
}

# ============================================================
# Clean Reset
# ============================================================
function Clean-Reset {
    Write-Log WARN "Cleaning local Git config..."

    if (-not (Test-Path ".git")) {
        Write-Log ERROR "Git repo not initialized"
        exit 1
    }

    if (-not (Confirm-Action -Message "Clean local Git config?")) {
        Write-Log INFO "Cancelled"
        return
    }

    $existingRemotes = git remote | Out-String
    if ($existingRemotes) {
        $existingRemotes -split "`n" | ForEach-Object {
            $remote = $_.Trim()
            if ($remote) {
                git remote remove $remote 2>$null
                Write-Log INFO "Removed remote: $remote"
            }
        }
    }

    git config --local --unset alias.pushall 2>$null

    Write-Log SUCCESS "Local Git config cleaned"
}

# ============================================================
# Clean Full
# ============================================================
function Clean-Full {
    Write-Log ERROR "Deleting .git directory..."

    if (-not (Test-Path ".git")) {
        Write-Log ERROR "Git repo not initialized"
        exit 1
    }

    if (-not (Confirm-Action -Message "Completely delete .git directory? This cannot be undone!")) {
        Write-Log INFO "Cancelled"
        return
    }

    Remove-Item -Path ".git" -Recurse -Force
    Write-Log SUCCESS ".git directory deleted"
}

# ============================================================
# Main
# ============================================================
function Main {
    if ($Help) {
        Show-Help
        exit 0
    }

    if (-not $Module -or -not $Action) {
        Show-Help
        exit 0
    }

    Load-Config

    Write-Log DEBUG "Module: $Module, Action: $Action, Platform: $Platform"

    switch ($Module.ToLower()) {
        "ssh" { Invoke-SshModule -Operation $Action.ToLower() }
        "repo" { Invoke-RepoModule -Operation $Action.ToLower() }
        "git" { Invoke-GitModule -Operation $Action.ToLower() }
        "all" { Invoke-AllModule -Operation $Action.ToLower() }
        "clean" { Invoke-CleanModule -Operation $Action.ToLower() }
        default {
            Write-Log ERROR "Unknown module: $Module"
            Show-Help
            exit 1
        }
    }
}

# ============================================================
# Execute
# ============================================================
Main