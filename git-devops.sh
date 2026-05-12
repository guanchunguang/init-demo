#!/bin/bash
# ============================================================
# Git DevOps CLI - Cross-Platform Git 双平台自动化工具
# ============================================================
# 支持平台：Linux / macOS / Git Bash on Windows
#
# 使用方法：
#   ./git-devops.sh <模块> <操作> [参数]
#   ./git-devops.sh ssh create -p github
#   ./git-devops.sh repo create -p github
#   ./git-devops.sh git init
#   ./git-devops.sh all init
#   ./git-devops.sh --help
#
# 全局参数：
#   -p, --platform    目标平台：github / gitee
#   -f, --force       强制覆盖已存在的资源
#   -y, --yes         自动确认危险操作
#   -d, --debug       显示 DEBUG 级别日志
#   -q, --quiet       只显示 WARN/ERROR 日志
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"
SSH_DIR="${HOME}/.ssh"

# ============================================================
# 全局变量
# ============================================================
MODULE=""
ACTION=""
PLATFORM=""
FORCE="false"
YES="false"
DEBUG_MODE="false"
QUIET_MODE="false"
REPO_NAME=""

GITHUB_ACCOUNTS="[]"
GITEE_ACCOUNTS="[]"
GIT_USER_NAME=""
GIT_USER_EMAIL=""

# ============================================================
# 颜色定义
# ============================================================
readonly COLOR_DEBUG='\033[90m'
readonly COLOR_INFO='\033[36m'
readonly COLOR_WARN='\033[33m'
readonly COLOR_ERROR='\033[31m'
readonly COLOR_SUCCESS='\033[32m'
readonly COLOR_RESET='\033[0m'

# ============================================================
# 日志函数
# ============================================================
log() {
    local level="$1"
    shift
    local message="$*"

    local color
    local tag

    case "$level" in
        DEBUG)
            color="$COLOR_DEBUG"
            tag="[DEBUG]"
            ;;
        INFO)
            color="$COLOR_INFO"
            tag="[INFO]"
            ;;
        WARN)
            color="$COLOR_WARN"
            tag="[WARN]"
            ;;
        ERROR)
            color="$COLOR_ERROR"
            tag="[ERROR]"
            ;;
        SUCCESS)
            color="$COLOR_SUCCESS"
            tag="[OK]"
            ;;
        *)
            color="$COLOR_INFO"
            tag="[INFO]"
            ;;
    esac

    # Quiet mode: suppress INFO and DEBUG
    if [[ "$QUIET_MODE" == "true" ]] && [[ "$level" == "INFO" || "$level" == "DEBUG" ]]; then
        return
    fi

    # Debug mode: suppress DEBUG if not enabled
    if [[ "$level" == "DEBUG" && "$DEBUG_MODE" != "true" ]]; then
        return
    fi

    echo -e "${color}${tag}${COLOR_RESET} $message"
}

# ============================================================
# 显示帮助
# ============================================================
show_help() {
    echo ""
    echo -e "${COLOR_INFO}Git DevOps CLI - Cross-Platform Git 双平台自动化工具${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_WARN}使用方法 / Usage:${COLOR_RESET}"
    echo "  ./git-devops.sh <模块> <操作> [参数]"
    echo "  ./git-devops.sh <module> <action> [options]"
    echo ""
    echo -e "${COLOR_WARN}模块 / Modules:${COLOR_RESET}"
    echo "  ssh      SSH 密钥管理 / SSH key management"
    echo "  repo     远程仓库管理 / Remote repo management"
    echo "  git      Git 本地配置 / Git local config"
    echo "  all      一键初始化 / One-command init"
    echo "  clean    清理操作 / Clean operations"
    echo ""
    echo -e "${COLOR_WARN}示例 / Examples:${COLOR_RESET}"
    echo "  ./git-devops.sh ssh create -p github"
    echo "  ./git-devops.sh ssh verify -p github"
    echo "  ./git-devops.sh repo create -p github"
    echo "  ./git-devops.sh repo delete -p github"
    echo "  ./git-devops.sh git init"
    echo "  ./git-devops.sh all init"
    echo "  ./git-devops.sh clean reset"
    echo ""
    echo -e "${COLOR_WARN}全局参数 / Global Options:${COLOR_RESET}"
    echo "  -p, --platform    目标平台：github / gitee"
    echo "  -f, --force       强制覆盖已存在的资源"
    echo "  -y, --yes         自动确认危险操作"
    echo "  -d, --debug       显示 DEBUG 级别日志"
    echo "  -q, --quiet       只显示 WARN/ERROR 日志"
    echo "  -h, --help        显示帮助信息"
    echo ""
    echo -e "${COLOR_WARN}SSH 模块操作 / SSH Module Actions:${COLOR_RESET}"
    echo "  create         创建 SSH 密钥对"
    echo "  push           推送公钥到平台"
    echo "  verify         验证 SSH 连接"
    echo "  agent-start    启动 ssh-agent"
    echo "  agent-status   检查 agent 状态"
    echo ""
    echo -e "${COLOR_WARN}Repo 模块操作 / Repo Module Actions:${COLOR_RESET}"
    echo "  create         创建远程仓库"
    echo "  delete         删除远程仓库"
    echo ""
    echo -e "${COLOR_WARN}Git 模块操作 / Git Module Actions:${COLOR_RESET}"
    echo "  init           初始化 Git 仓库"
    echo "  remote         配置 remotes"
    echo "  push           推送到远程"
    echo ""
    echo -e "${COLOR_WARN}All 模块操作 / All Module Actions:${COLOR_RESET}"
    echo "  init           一键完成全部初始化"
    echo ""
    echo -e "${COLOR_WARN}Clean 模块操作 / Clean Module Actions:${COLOR_RESET}"
    echo "  reset          清理本地 Git 配置"
    echo "  clean          删除 .git 目录"
    echo ""
}

# ============================================================
# 加载配置
# ============================================================
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log ERROR "配置文件不存在: $CONFIG_FILE"
        log ERROR "请先复制 env.example 为 .env"
        exit 1
    fi

    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # 去除首尾空白，但保留 JSON 格式的引号
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # 对于 JSON 数组，保留原始格式（包括引号）
            case "$key" in
                GITHUB_ACCOUNTS|GITEE_ACCOUNTS)
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    ;;
                *)
                    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    ;;
            esac

            case "$key" in
                GITHUB_ACCOUNTS) GITHUB_ACCOUNTS="$value" ;;
                GITEE_ACCOUNTS) GITEE_ACCOUNTS="$value" ;;
                GIT_USER_NAME) GIT_USER_NAME="$value" ;;
                GIT_USER_EMAIL) GIT_USER_EMAIL="$value" ;;
            esac
        fi
    done < "$CONFIG_FILE"

    log DEBUG "配置文件已加载: $CONFIG_FILE"
}

# ============================================================
# JSON 解析函数 (使用 sed，不依赖 jq)
# ============================================================
json_get_array_length() {
    local json="$1"
    # 移除空白和外层括号，计算逗号数量 + 1
    local content
    content=$(echo "$json" | tr -d ' \n' | sed 's/^\[//;s/\]$//')
    if [ -z "$content" ]; then
        echo "0"
        return
    fi
    local count
    count=$(echo "$content" | awk -F',' '{print NF}')
    echo "$count"
}

json_get_field() {
    local json="$1"
    local index="$2"
    local field="$3"

    # 提取第 N 个对象
    local content
    content=$(echo "$json" | tr -d ' \n' | sed 's/^\[//;s/\]$//')

    local obj
    obj=$(echo "$content" | awk -F'}\\{' -v i="$((index + 1))" '{if(NR==i) print "{"$0"}"}')

    if [ -z "$obj" ]; then
        echo ""
        return
    fi

    # 使用 sed 提取字段值
    local value
    value=$(echo "$obj" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")

    if [ -z "$value" ]; then
        value=$(echo "$obj" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p")
    fi

    echo "$value"
}


# ============================================================
# 获取账户配置
# ============================================================
get_account_config() {
    local platform="$1"
    local accounts_var="$2"

    local count
    count=$(json_get_array_length "${!accounts_var}")

    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        echo ""
        return
    fi

    local user token host
    for ((i = 0; i < count; i++)); do
        user=$(json_get_field "${!accounts_var}" "$i" "user")
        token=$(json_get_field "${!accounts_var}" "$i" "token")
        host=$(json_get_field "${!accounts_var}" "$i" "host")

        if [ -n "$user" ] && [ -n "$token" ] && [ -n "$host" ]; then
            echo "${user}:${token}:${host}"
        fi
    done
}

# ============================================================
# 确认提示函数
# ============================================================
confirm() {
    local message="$1"
    local default="N"

    if [[ "$YES" == "true" ]]; then
        log INFO "${message} [Y/y] -> auto-confirmed"
        return 0
    fi

    echo -e "${COLOR_WARN}${message} [y/N]${COLOR_RESET}"
    read -r answer

    case "$answer" in
        Y|y)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================
# 获取项目名称
# ============================================================
get_project_name() {
    if [ -n "$REPO_NAME" ]; then
        echo "$REPO_NAME"
    else
        basename "$(pwd)"
    fi
}

# ============================================================
# SSH 模块
# ============================================================
ssh_module() {
    local operation="$1"
    shift

    case "$operation" in
        create)
            ssh_create "$@"
            ;;
        push)
            ssh_push "$@"
            ;;
        verify)
            ssh_verify "$@"
            ;;
        agent-start)
            ssh_agent_start
            ;;
        agent-status)
            ssh_agent_status
            ;;
        *)
            log ERROR "未知 SSH 操作: $operation"
            log INFO "支持的 SSH 操作: create, push, verify, agent-start, agent-status"
            exit 1
            ;;
    esac
}

# ============================================================
# SSH 创建
# ============================================================
ssh_create() {
    log INFO "创建 SSH 密钥..."

    if [ -z "$PLATFORM" ]; then
        log ERROR "请指定平台: -p github 或 -p gitee"
        exit 1
    fi

    local accounts_var
    case "$PLATFORM" in
        github) accounts_var="GITHUB_ACCOUNTS" ;;
        gitee) accounts_var="GITEE_ACCOUNTS" ;;
        *)
            log ERROR "未知平台: $PLATFORM"
            exit 1
            ;;
    esac

    local account_line
    account_line=$(get_account_config "$PLATFORM" "$accounts_var" | head -1)

    if [ -z "$account_line" ]; then
        log ERROR "未找到 $PLATFORM 账户配置"
        exit 1
    fi

    IFS=':' read -r user token host <<< "$account_line"

    local key_file="id_ed25519_${PLATFORM}_${user}"
    local key_path="${SSH_DIR}/${key_file}"
    local pub_key_path="${key_path}.pub"

    if [ -f "$key_path" ]; then
        if [[ "$FORCE" == "true" ]]; then
            log WARN "SSH 密钥已存在，强制覆盖..."
            mv "$key_path" "${key_path}.backup_$(date +%s)"
            mv "$pub_key_path" "${pub_key_path}.backup_$(date +%s)"
        else
            log WARN "SSH 密钥已存在: $key_path"
            log INFO "使用 --force 强制覆盖"
            return 0
        fi
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    log INFO "生成 SSH 密钥: $key_file"
    ssh-keygen -t ed25519 -f "$key_path" -C "$GIT_USER_EMAIL" -N ""

    log SUCCESS "SSH 密钥已创建: $key_path"
}

# ============================================================
# SSH 推送公钥到平台
# ============================================================
ssh_push() {
    log INFO "推送 SSH 公钥到平台..."

    if [ -z "$PLATFORM" ]; then
        log ERROR "请指定平台: -p github 或 -p gitee"
        exit 1
    fi

    local accounts_var token
    case "$PLATFORM" in
        github) accounts_var="GITHUB_ACCOUNTS" ;;
        gitee) accounts_var="GITEE_ACCOUNTS" ;;
        *)
            log ERROR "未知平台: $PLATFORM"
            exit 1
            ;;
    esac

    local account_line
    account_line=$(get_account_config "$PLATFORM" "$accounts_var" | head -1)

    if [ -z "$account_line" ]; then
        log ERROR "未找到 $PLATFORM 账户配置"
        exit 1
    fi

    IFS=':' read -r user token host <<< "$account_line"

    local key_file="id_ed25519_${PLATFORM}_${user}"
    local pub_key_path="${SSH_DIR}/${key_file}.pub"

    if [ ! -f "$pub_key_path" ]; then
        log ERROR "公钥文件不存在: $pub_key_path"
        log INFO "请先运行: ./git-devops.sh ssh create -p $PLATFORM"
        exit 1
    fi

    local key_content
    key_content=$(cat "$pub_key_path" | tr -d '\n')

    local title="git-devops ${PLATFORM} ${user} $(date +%s)"

    if [ "$PLATFORM" = "github" ]; then
        ssh_push_github "$user" "$token" "$title" "$key_content"
    else
        ssh_push_gitee "$user" "$token" "$title" "$key_content"
    fi
}

# ============================================================
# 推送公钥到 GitHub
# ============================================================
ssh_push_github() {
    local user="$1"
    local token="$2"
    local title="$3"
    local key_content="$4"

    local response
    response=$(curl -s --max-time 30 -X POST \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "{\"title\":\"$title\",\"key\":\"$key_content\",\"type\":\"authentication_key\"}" \
        "https://api.github.com/user/keys")

    if echo "$response" | grep -qE '"id":[[:space:]]*[0-9]+'; then
        local id
        id=$(echo "$response" | grep -oE '"id":[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
        log SUCCESS "已添加到 GitHub (ID: $id)"
    else
        log ERROR "GitHub 添加失败: $response"
        exit 1
    fi
}

# ============================================================
# 推送公钥到 Gitee
# ============================================================
ssh_push_gitee() {
    local user="$1"
    local token="$2"
    local title="$3"
    local key_content="$4"

    local response
    response=$(curl -s --max-time 30 -X POST \
        -d "access_token=$token" \
        -d "title=$title" \
        -d "key=$key_content" \
        "https://gitee.com/api/v5/user/keys")

    if echo "$response" | grep -q '"id"'; then
        local id
        id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        log SUCCESS "已添加到 Gitee (ID: $id)"
    else
        log ERROR "Gitee 添加失败: $response"
        exit 1
    fi
}

# ============================================================
# SSH 验证
# ============================================================
ssh_verify() {
    log INFO "验证 SSH 连接..."

    if [ -z "$PLATFORM" ]; then
        log ERROR "请指定平台: -p github 或 -p gitee"
        exit 1
    fi

    local accounts_var
    case "$PLATFORM" in
        github) accounts_var="GITHUB_ACCOUNTS" ;;
        gitee) accounts_var="GITEE_ACCOUNTS" ;;
        *)
            log ERROR "未知平台: $PLATFORM"
            exit 1
            ;;
    esac

    local account_line
    account_line=$(get_account_config "$PLATFORM" "$accounts_var" | head -1)

    if [ -z "$account_line" ]; then
        log ERROR "未找到 $PLATFORM 账户配置"
        exit 1
    fi

    IFS=':' read -r user token host <<< "$account_line"

    log INFO "测试 $host ..."

    local result
    result=$(timeout 10 ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$host" 2>&1) || true

    if echo "$result" | grep -qE "(Hi|successfully authenticated|successfully authenticated)"; then
        log SUCCESS "$host SSH 连接正常"
    else
        log WARN "$host 响应异常: $result"
        return 1
    fi
}

# ============================================================
# SSH Agent 启动
# ============================================================
ssh_agent_start() {
    log INFO "启动 ssh-agent..."

    if pgrep -x ssh-agent > /dev/null 2>&1; then
        log INFO "ssh-agent 已在运行"
    else
        eval "$(ssh-agent -s)"
        log SUCCESS "ssh-agent 已启动"
    fi
}

# ============================================================
# SSH Agent 状态
# ============================================================
ssh_agent_status() {
    log INFO "检查 ssh-agent 状态..."

    if pgrep -x ssh-agent > /dev/null 2>&1; then
        log SUCCESS "ssh-agent 正在运行"

        log INFO "已加载的密钥:"
        ssh-add -l 2>/dev/null || log INFO "  无已加载密钥"
    else
        log WARN "ssh-agent 未运行"
        log INFO "运行 ./git-devops.sh ssh agent-start 启动"
    fi
}

# ============================================================
# Repo 模块
# ============================================================
repo_module() {
    local operation="$1"
    shift

    case "$operation" in
        create)
            repo_create "$@"
            ;;
        delete)
            repo_delete "$@"
            ;;
        *)
            log ERROR "未知 Repo 操作: $operation"
            log INFO "支持的 Repo 操作: create, delete"
            exit 1
            ;;
    esac
}

# ============================================================
# Repo 创建
# ============================================================
repo_create() {
    log INFO "创建远程仓库..."

    if [ -z "$PLATFORM" ]; then
        log ERROR "请指定平台: -p github 或 -p gitee"
        exit 1
    fi

    local accounts_var
    case "$PLATFORM" in
        github) accounts_var="GITHUB_ACCOUNTS" ;;
        gitee) accounts_var="GITEE_ACCOUNTS" ;;
        *)
            log ERROR "未知平台: $PLATFORM"
            exit 1
            ;;
    esac

    local account_line
    account_line=$(get_account_config "$PLATFORM" "$accounts_var" | head -1)

    if [ -z "$account_line" ]; then
        log ERROR "未找到 $PLATFORM 账户配置"
        exit 1
    fi

    IFS=':' read -r user token host <<< "$account_line"

    local repo_name
    repo_name=$(get_project_name)

    if [ "$PLATFORM" = "github" ]; then
        repo_create_github "$user" "$token" "$repo_name"
    else
        repo_create_gitee "$user" "$token" "$repo_name"
    fi
}

# ============================================================
# 创建 GitHub 仓库
# ============================================================
repo_create_github() {
    local user="$1"
    local token="$2"
    local repo_name="$3"

    local response
    response=$(curl -s --max-time 30 -X POST \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$repo_name\",\"private\":false}" \
        "https://api.github.com/user/repos")

    if echo "$response" | grep -qE '"id":[[:space:]]*[0-9]+'; then
        log SUCCESS "GitHub 仓库已创建: $repo_name"
    elif echo "$response" | grep -q '"name":"already exists"'; then
        log WARN "GitHub 仓库已存在: $repo_name"
    else
        log ERROR "GitHub 仓库创建失败: $response"
        exit 1
    fi
}

# ============================================================
# 创建 Gitee 仓库
# ============================================================
repo_create_gitee() {
    local user="$1"
    local token="$2"
    local repo_name="$3"

    local response
    response=$(curl -s --max-time 30 -X POST \
        -d "access_token=$token" \
        -d "name=$repo_name" \
        -d "private=false" \
        "https://gitee.com/api/v5/user/repos")

    if echo "$response" | grep -q '"id"'; then
        log SUCCESS "Gitee 仓库已创建: $repo_name"
    elif echo "$response" | grep -q '"error"'; then
        local err_msg
        err_msg=$(echo "$response" | sed -n 's/.*"error_description":"\([^"]*\)".*/\1/p')
        if echo "$err_msg" | grep -q "already exists"; then
            log WARN "Gitee 仓库已存在: $repo_name"
        else
            log ERROR "Gitee 仓库创建失败: $err_msg"
            exit 1
        fi
    else
        log ERROR "Gitee 仓库创建失败: $response"
        exit 1
    fi
}

# ============================================================
# Repo 删除
# ============================================================
repo_delete() {
    log WARN "删除远程仓库..."

    if [ -z "$PLATFORM" ]; then
        log ERROR "请指定平台: -p github 或 -p gitee"
        exit 1
    fi

    if [[ "$YES" != "true" ]]; then
        if ! confirm "确定要删除远程仓库吗?"; then
            log INFO "操作已取消"
            return 0
        fi
    fi

    local accounts_var
    case "$PLATFORM" in
        github) accounts_var="GITHUB_ACCOUNTS" ;;
        gitee) accounts_var="GITEE_ACCOUNTS" ;;
        *)
            log ERROR "未知平台: $PLATFORM"
            exit 1
            ;;
    esac

    local account_line
    account_line=$(get_account_config "$PLATFORM" "$accounts_var" | head -1)

    if [ -z "$account_line" ]; then
        log ERROR "未找到 $PLATFORM 账户配置"
        exit 1
    fi

    IFS=':' read -r user token host <<< "$account_line"

    local repo_name
    repo_name=$(get_project_name)

    if [ "$PLATFORM" = "github" ]; then
        repo_delete_github "$user" "$token" "$repo_name"
    else
        repo_delete_gitee "$user" "$token" "$repo_name"
    fi
}

# ============================================================
# 删除 GitHub 仓库
# ============================================================
repo_delete_github() {
    local user="$1"
    local token="$2"
    local repo_name="$3"

    local http_code
    http_code=$(curl -s --max-time 30 -X DELETE \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -o /dev/null -w "%{http_code}" \
        "https://api.github.com/repos/$user/$repo_name")

    if [ "$http_code" = "204" ]; then
        log SUCCESS "GitHub 仓库已删除: $repo_name"
    else
        log ERROR "GitHub 仓库删除失败 (HTTP $http_code)"
        exit 1
    fi
}

# ============================================================
# 删除 Gitee 仓库
# ============================================================
repo_delete_gitee() {
    local user="$1"
    local token="$2"
    local repo_name="$3"

    local http_code
    http_code=$(curl -s --max-time 30 -X DELETE \
        -o /dev/null -w "%{http_code}" \
        "https://gitee.com/api/v5/repos/$user/$repo_name?access_token=$token")

    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        log SUCCESS "Gitee 仓库已删除: $repo_name"
    else
        log ERROR "Gitee 仓库删除失败 (HTTP $http_code)"
        exit 1
    fi
}

# ============================================================
# Git 模块
# ============================================================
git_module() {
    local operation="$1"
    shift

    case "$operation" in
        init)
            git_init "$@"
            ;;
        remote)
            git_remote "$@"
            ;;
        push)
            git_push "$@"
            ;;
        *)
            log ERROR "未知 Git 操作: $operation"
            log INFO "支持的 Git 操作: init, remote, push"
            exit 1
            ;;
    esac
}

# ============================================================
# Git 初始化
# ============================================================
git_init() {
    log INFO "初始化 Git 仓库..."

    if [ ! -d ".git" ]; then
        git init -b main
        log SUCCESS "Git 仓库已创建"
    else
        log INFO "Git 仓库已存在，跳过初始化"

        if git branch | grep -q "^  master$"; then
            git branch -m master main
            log INFO "分支已从 master 改为 main"
        fi
    fi

    # 配置 Git 用户信息
    if [ -n "$GIT_USER_NAME" ]; then
        git config --local user.name "$GIT_USER_NAME"
        log DEBUG "Git 用户名: $GIT_USER_NAME"
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --local user.email "$GIT_USER_EMAIL"
        log DEBUG "Git 用户邮箱: $GIT_USER_EMAIL"
    fi
}

# ============================================================
# Git 配置 Remote
# ============================================================
git_remote() {
    log INFO "配置 Git remotes..."

    if [ ! -d ".git" ]; then
        log ERROR "Git 仓库未初始化"
        log INFO "请先运行: ./git-devops.sh git init"
        exit 1
    fi

    # 获取项目名
    local project
    project=$(get_project_name)

    # 移除已存在的 remote
    local existing_remotes
    existing_remotes=$(git remote)
    if [ -n "$existing_remotes" ]; then
        for remote in $existing_remotes; do
            git remote remove "$remote" 2>/dev/null || true
        done
    fi

    # 配置 GitHub remote
    local github_account
    github_account=$(get_account_config "github" "GITHUB_ACCOUNTS" | head -1)
    if [ -n "$github_account" ]; then
        IFS=':' read -r user token host <<< "$github_account"
        local remote_url="git@${host}:${user}/$project.git"
        git remote add github "$remote_url"
        log SUCCESS "GitHub remote: github -> $remote_url"
    fi

    # 配置 Gitee remote
    local gitee_account
    gitee_account=$(get_account_config "gitee" "GITEE_ACCOUNTS" | head -1)
    if [ -n "$gitee_account" ]; then
        IFS=':' read -r user token host <<< "$gitee_account"
        local remote_url="git@${host}:${user}/$project.git"
        git remote add gitee "$remote_url"
        log SUCCESS "Gitee remote: gitee -> $remote_url"
    fi

    # 设置 pushall 别名
    local has_github has_gitee
    has_github=$(git remote | grep -c "^github$" || true)
    has_gitee=$(git remote | grep -c "^gitee$" || true)

    if [ "$has_github" -gt 0 ] && [ "$has_gitee" -gt 0 ]; then
        git config alias.pushall '!git push github main && git push gitee main'
        log SUCCESS "pushall 别名已配置"
    elif [ "$has_github" -gt 0 ]; then
        git config alias.pushall '!git push github main'
        log INFO "pushall 别名已配置（仅 GitHub）"
    elif [ "$has_gitee" -gt 0 ]; then
        git config alias.pushall '!git push gitee main'
        log INFO "pushall 别名已配置（仅 Gitee）"
    fi
}

# ============================================================
# Git 推送
# ============================================================
git_push() {
    log INFO "推送到远程仓库..."

    if [ ! -d ".git" ]; then
        log ERROR "Git 仓库未初始化"
        exit 1
    fi

    if [ -z "$PLATFORM" ]; then
        # 推送到所有 remotes
        git pushall
    else
        case "$PLATFORM" in
            github|gitee)
                git push "$PLATFORM" main
                ;;
            *)
                log ERROR "未知平台: $PLATFORM"
                exit 1
                ;;
        esac
    fi
}

# ============================================================
# All 模块 - 一键初始化
# ============================================================
all_module() {
    local operation="$1"
    shift

    case "$operation" in
        init)
            all_init "$@"
            ;;
        *)
            log ERROR "未知 All 操作: $operation"
            log INFO "支持的 All 操作: init"
            exit 1
            ;;
    esac
}

# ============================================================
# 一键初始化
# ============================================================
all_init() {
    log INFO "========================================"
    log INFO "Git DevOps 一键初始化"
    log INFO "========================================"
    echo ""

    # SSH 创建
    for platform in github gitee; do
        PLATFORM="$platform"

        local accounts_var="GITHUB_ACCOUNTS"
        if [ "$platform" = "gitee" ]; then
            accounts_var="GITEE_ACCOUNTS"
        fi

        local account_line
        account_line=$(get_account_config "$platform" "$accounts_var" | head -1)

        if [ -z "$account_line" ]; then
            log WARN "跳过 $platform：未配置账户"
            continue
        fi

        IFS=':' read -r user token host <<< "$account_line"

        local key_file="id_ed25519_${platform}_${user}"
        local key_path="${SSH_DIR}/${key_file}"

        if [ ! -f "$key_path" ]; then
            log INFO "[$platform] 创建 SSH 密钥..."
            ssh_create
        else
            log INFO "[$platform] SSH 密钥已存在，跳过"
        fi
    done

    echo ""

    # Repo 创建
    for platform in github gitee; do
        PLATFORM="$platform"

        local accounts_var="GITHUB_ACCOUNTS"
        if [ "$platform" = "gitee" ]; then
            accounts_var="GITEE_ACCOUNTS"
        fi

        local account_line
        account_line=$(get_account_config "$platform" "$accounts_var" | head -1)

        if [ -z "$account_line" ]; then
            log WARN "跳过 $platform：未配置账户"
            continue
        fi

        log INFO "[$platform] 创建远程仓库..."
        repo_create || log WARN "[$platform] 仓库可能已存在"
    done

    echo ""

    # Git 初始化
    log INFO "初始化 Git 仓库..."
    git_init

    echo ""

    # Git 远程配置
    log INFO "配置 Git remotes..."
    git_remote

    echo ""
    log SUCCESS "一键初始化完成!"
    log INFO "后续操作:"
    log INFO "  git add ."
    log INFO "  git commit -m 'init'"
    log INFO "  git pushall"
}

# ============================================================
# Clean 模块
# ============================================================
clean_module() {
    local operation="$1"
    shift

    case "$operation" in
        reset)
            clean_reset "$@"
            ;;
        clean)
            clean_full "$@"
            ;;
        *)
            log ERROR "未知 Clean 操作: $operation"
            log INFO "支持的 Clean 操作: reset, clean"
            exit 1
            ;;
    esac
}

# ============================================================
# Clean 重置
# ============================================================
clean_reset() {
    log WARN "清理本地 Git 配置..."

    if [ ! -d ".git" ]; then
        log ERROR "Git 仓库未初始化"
        exit 1
    fi

    if [[ "$YES" != "true" ]]; then
        if ! confirm "确定要清理本地 Git 配置吗?"; then
            log INFO "操作已取消"
            return 0
        fi
    fi

    # 移除 remotes
    local existing_remotes
    existing_remotes=$(git remote)
    if [ -n "$existing_remotes" ]; then
        for remote in $existing_remotes; do
            git remote remove "$remote" 2>/dev/null || true
            log INFO "已移除 remote: $remote"
        done
    fi

    # 移除 alias
    git config --local --unset alias.pushall 2>/dev/null || true

    log SUCCESS "本地 Git 配置已清理"
}

# ============================================================
# Clean 完全删除
# ============================================================
clean_full() {
    log ERROR "删除 .git 目录..."

    if [ ! -d ".git" ]; then
        log ERROR "Git 仓库未初始化"
        exit 1
    fi

    if [[ "$YES" != "true" ]]; then
        if ! confirm "确定要完全删除 .git 目录吗? 此操作不可恢复!"; then
            log INFO "操作已取消"
            return 0
        fi
    fi

    rm -rf .git
    log SUCCESS ".git 目录已删除"
}

# ============================================================
# 解析命令行参数
# ============================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -y|--yes)
                YES="true"
                shift
                ;;
            -d|--debug)
                DEBUG_MODE="true"
                shift
                ;;
            -q|--quiet)
                QUIET_MODE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--repo)
                REPO_NAME="$2"
                shift 2
                ;;
            ssh|repo|git|all|clean)
                MODULE="$1"
                ACTION="$2"
                shift 2
                ;;
            *)
                log ERROR "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================
# 主函数
# ============================================================
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # 解析全局参数
    local remaining_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -y|--yes)
                YES="true"
                shift
                ;;
            -d|--debug)
                DEBUG_MODE="true"
                shift
                ;;
            -q|--quiet)
                QUIET_MODE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--repo)
                REPO_NAME="$2"
                shift 2
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#remaining_args[@]} -lt 2 ]; then
        show_help
        exit 0
    fi

    MODULE="${remaining_args[0]}"
    ACTION="${remaining_args[1]}"

    load_config

    log DEBUG "Module: $MODULE, Action: $ACTION, Platform: $PLATFORM"

    case "$MODULE" in
        ssh)
            ssh_module "$ACTION" "${remaining_args[@]:2}"
            ;;
        repo)
            repo_module "$ACTION" "${remaining_args[@]:2}"
            ;;
        git)
            git_module "$ACTION" "${remaining_args[@]:2}"
            ;;
        all)
            all_module "$ACTION" "${remaining_args[@]:2}"
            ;;
        clean)
            clean_module "$ACTION" "${remaining_args[@]:2}"
            ;;
        *)
            log ERROR "未知模块: $MODULE"
            show_help
            exit 1
            ;;
    esac
}

# ============================================================
# 执行
# ============================================================
main "$@"
