#!/bin/bash
# ============================================================
# Git 本地初始化工具 - Git 双平台
# ============================================================
# 功能：
#   - 初始化 Git 仓库（main 分支）
#   - 配置项目级 Git 用户信息
#   - 配置双平台 remote（GitHub + Gitee）
#   - 设置 pushall 命令别名
#
# 使用方法：
#   ./git-init-local.sh                    # 执行初始化
#   ./git-init-local.sh --help|-h         # 显示帮助
#
# 支持平台：Linux / macOS
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"

# ============================================================
# 显示帮助
# ============================================================
show_help() {
    echo ""
    echo -e "\033[36mGit 本地初始化工具 - Git 双平台\033[0m"
    echo ""
    echo -e "\033[33m使用方法：\033[0m"
    echo "  ./git-init-local.sh                    # 执行初始化"
    echo "  ./git-init-local.sh --help|-h         # 显示帮助"
    echo ""
    echo -e "\033[33m功能：\033[0m"
    echo "  - 初始化 Git 仓库（main 分支）"
    echo "  - 配置项目级 Git 用户信息"
    echo "  - 配置双平台 remote（GitHub + Gitee）"
    echo "  - 设置 pushall 命令别名"
    echo ""
}

# ============================================================
# 加载配置
# ============================================================
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "\033[31m[错误] 配置文件不存在: $CONFIG_FILE\033[0m"
        echo -e "\033[31m[错误] 请先复制 env.example 为 .env\033[0m"
        exit 1
    fi

    # 读取配置文件
    GITHUB_USER=""
    GITHUB_HOST=""
    GITEE_USER=""
    GITEE_HOST=""
    GIT_USER_NAME=""
    GIT_USER_EMAIL=""

    while IFS= read -r line; do
        # 跳过注释和空行
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        # 解析 KEY=value
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # 去除首尾空白
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            case "$key" in
                GITHUB_USER) GITHUB_USER="$value" ;;
                GITHUB_HOST) GITHUB_HOST="$value" ;;
                GITEE_USER) GITEE_USER="$value" ;;
                GITEE_HOST) GITEE_HOST="$value" ;;
                GIT_USER_NAME) GIT_USER_NAME="$value" ;;
                GIT_USER_EMAIL) GIT_USER_EMAIL="$value" ;;
            esac
        fi
    done < "$CONFIG_FILE"
}

# ============================================================
# 获取项目名称
# ============================================================
get_project_name() {
    basename "$(pwd)"
}

# ============================================================
# 初始化 Git 仓库
# ============================================================
init_git() {
    if [ ! -d ".git" ]; then
        echo -e "\033[36m[INFO] 初始化 Git 仓库...\033[0m"
        git init -b main
        echo -e "\033[32m[成功] Git 仓库已创建\033[0m"
    else
        echo -e "\033[36m[INFO] Git 仓库已存在，跳过初始化\033[0m"
        # 检查是否有 master 分支
        if git branch | grep -q "^  master$"; then
            git branch -m master main
            echo -e "\033[33m[INFO] 分支已从 master 改为 main\033[0m"
        fi
    fi
}

# ============================================================
# 配置 Git 用户信息
# ============================================================
setup_git_config() {
    # 清除可能存在的旧配置
    git config --local --unset-all user.email 2>/dev/null || true
    git config --local --unset-all user.name 2>/dev/null || true

    if [ -n "$GIT_USER_NAME" ]; then
        git config --local user.name "$GIT_USER_NAME"
        echo -e "\033[32m[成功] Git 用户名: $GIT_USER_NAME\033[0m"
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --local user.email "$GIT_USER_EMAIL"
        echo -e "\033[32m[成功] Git 用户邮箱: $GIT_USER_EMAIL\033[0m"
    fi
}

# ============================================================
# 配置 Remote
# ============================================================
setup_remotes() {
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

    # 添加 GitHub remote（使用第一个用户）
    if [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_HOST" ]; then
        local remote_url="git@${GITHUB_HOST}:${GITHUB_USER}/$project.git"
        git remote add github "$remote_url"
        echo -e "\033[32m[成功] GitHub remote: github -> $remote_url\033[0m"
    fi

    # 添加 Gitee remote（使用第一个用户）
    if [ -n "$GITEE_USER" ] && [ -n "$GITEE_HOST" ]; then
        local remote_url="git@${GITEE_HOST}:${GITEE_USER}/$project.git"
        git remote add gitee "$remote_url"
        echo -e "\033[32m[成功] Gitee remote: gitee -> $remote_url\033[0m"
    fi
}

# ============================================================
# 设置 pushall 别名
# ============================================================
setup_pushall_alias() {
    local has_github
    local has_gitee

    has_github=$(git remote | grep -c "^github$" || true)
    has_gitee=$(git remote | grep -c "^gitee$" || true)

    # 删除已有的 alias 块
    if [ -f .git/config ]; then
        sed -i '/^\[alias\]/,/^[^[]/d' .git/config 2>/dev/null || true
    fi

    if [ "$has_github" -gt 0 ] && [ "$has_gitee" -gt 0 ]; then
        git config alias.pushall '!git push github main && git push gitee main'
        echo -e "\033[32m[成功] pushall 别名已配置\033[0m"
    elif [ "$has_github" -gt 0 ]; then
        git config alias.pushall '!git push github main'
        echo -e "\033[33m[成功] pushall 别名已配置（仅 GitHub）\033[0m"
    elif [ "$has_gitee" -gt 0 ]; then
        git config alias.pushall '!git push gitee main'
        echo -e "\033[33m[成功] pushall 别名已配置（仅 Gitee）\033[0m"
    else
        echo -e "\033[33m[警告] 未配置任何 remote，无法设置 pushall\033[0m"
    fi
}

# ============================================================
# 显示状态
# ============================================================
show_status() {
    echo ""
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m当前状态\033[0m"
    echo -e "\033[36m========================================\033[0m"

    echo ""
    echo -e "\033[33m[Git 配置]\033[0m"
    git config --local user.name
    git config --local user.email

    echo ""
    echo -e "\033[33m[Remote 配置]\033[0m"
    git remote -v

    echo ""
    echo -e "\033[33m[pushall 别名]\033[0m"
    git config --get alias.pushall

    echo ""
    echo -e "\033[33m[后续操作]\033[0m"
    echo "  git add ."
    echo "  git commit -m 'init'"
    echo "  git pushall"
}

# ============================================================
# 主函数
# ============================================================
main() {
    # 检查是否配置了用户
    if [ -z "$GITHUB_USER" ] && [ -z "$GITEE_USER" ]; then
        echo -e "\033[31m[错误] 未配置任何用户，请检查 .env 文件\033[0m"
        exit 1
    fi

    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mGit 本地初始化工具 - Git 双平台\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    init_git
    setup_git_config
    setup_remotes
    setup_pushall_alias

    show_status

    echo ""
    echo -e "\033[32m[完成] 本地 Git 配置完成\033[0m"
}

# ============================================================
# 解析命令行参数
# ============================================================
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            show_help
            exit 0
            ;;
    esac
done

# 加载配置
load_config

# 执行
main
