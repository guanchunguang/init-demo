#!/bin/bash
# ============================================================
# Git 完整初始化工具 - Git 双平台
# ============================================================
# 功能：
#   - 创建远程仓库（GitHub + Gitee）
#   - 初始化本地 Git 并推送到双平台
#   - 设置 pushall 命令别名
#   - 支持 --delete 删除远程仓库
#   - 支持 --reset 清理本地 git 配置
#   - 支持 --clean 删除 .git 目录
#
# 使用方法：
#   ./git-full-local.sh                    # 执行初始化
#   ./git-full-local.sh --delete           # 删除远程仓库
#   ./git-full-local.sh --reset            # 清理本地 git 配置
#   ./git-full-local.sh --clean            # 删除 .git 目录
#   ./git-full-local.sh --help|-h          # 显示帮助
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
    echo -e "\033[36mGit 完整初始化工具 - Git 双平台\033[0m"
    echo ""
    echo -e "\033[33m使用方法：\033[0m"
    echo "  ./git-full-local.sh                    # 执行初始化"
    echo "  ./git-full-local.sh --delete           # 删除远程仓库"
    echo "  ./git-full-local.sh --reset            # 清理本地 git 配置"
    echo "  ./git-full-local.sh --clean            # 删除 .git 目录"
    echo "  ./git-full-local.sh --help|-h          # 显示帮助"
    echo ""
    echo -e "\033[33m功能：\033[0m"
    echo "  - 创建远程仓库（GitHub + Gitee）"
    echo "  - 初始化本地 Git 并推送到双平台"
    echo "  - 设置 pushall 命令别名"
    echo "  - --delete: 删除远程仓库（保留本地配置）"
    echo "  - --reset: 清理本地 git 配置（remotes、别名）"
    echo "  - --clean: 删除 .git 目录（完全重置）"
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
    GITHUB_TOKEN=""
    GITEE_USER=""
    GITEE_HOST=""
    GITEE_TOKEN=""
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
                GITHUB_TOKEN) GITHUB_TOKEN="$value" ;;
                GITEE_USER) GITEE_USER="$value" ;;
                GITEE_HOST) GITEE_HOST="$value" ;;
                GITEE_TOKEN) GITEE_TOKEN="$value" ;;
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
# 检查 Token 有效性
# ============================================================
check_tokens() {
    # GitHub Token 检查
    if [ -n "$GITHUB_TOKEN" ]; then
        echo -e "\033[36m[INFO] 检查 GitHub Token...\033[0m"
        local github_code
        github_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/user")

        if [ "$github_code" = "200" ]; then
            echo -e "\033[32m[成功] GitHub Token 有效\033[0m"
        else
            echo -e "\033[31m[错误] GitHub Token 无效 (HTTP $github_code)\033[0m"
            return 1
        fi
    fi

    # Gitee Token 检查
    if [ -n "$GITEE_TOKEN" ]; then
        echo -e "\033[36m[INFO] 检查 Gitee Token...\033[0m"
        local gitee_code
        gitee_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
            "https://gitee.com/api/v5/user/repos?access_token=$GITEE_TOKEN&per_page=1")

        if [ "$gitee_code" = "200" ]; then
            echo -e "\033[32m[成功] Gitee Token 有效\033[0m"
        else
            echo -e "\033[31m[错误] Gitee Token 无效 (HTTP $gitee_code)\033[0m"
            return 1
        fi
    fi

    return 0
}

# ============================================================
# 测试 SSH 连接
# ============================================================
check_ssh() {
    # GitHub SSH 检查
    if [ -n "$GITHUB_HOST" ]; then
        echo -e "\033[36m[INFO] 测试 $GITHUB_HOST ...\033[0m"

        local result
        if result=$(timeout 10 ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$GITHUB_HOST" 2>&1); then
            :
        fi

        if echo "$result" | grep -qE "(Hi|successfully authenticated)"; then
            echo -e "\033[32m[成功] $GITHUB_HOST SSH 连接正常\033[0m"
        else
            echo -e "\033[33m[警告] $GITHUB_HOST 响应异常: $result\033[0m"
        fi
    fi

    # Gitee SSH 检查
    if [ -n "$GITEE_HOST" ]; then
        echo -e "\033[36m[INFO] 测试 $GITEE_HOST ...\033[0m"

        local result
        if result=$(timeout 10 ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$GITEE_HOST" 2>&1); then
            :
        fi

        if echo "$result" | grep -qE "(Hi|successfully authenticated)"; then
            echo -e "\033[32m[成功] $GITEE_HOST SSH 连接正常\033[0m"
        else
            echo -e "\033[33m[警告] $GITEE_HOST 响应异常: $result\033[0m"
        fi
    fi
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
        if git branch | grep -q "^  master$"; then
            git branch -m master main
            echo -e "\033[33m[INFO] 分支已从 master 改为 main\033[0m"
        fi
    fi

    # 配置 Git 用户信息
    git config --local --unset-all user.email 2>/dev/null || true
    git config --local --unset-all user.name 2>/dev/null || true

    if [ -n "$GIT_USER_NAME" ]; then
        git config --local user.name "$GIT_USER_NAME"
    fi

    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --local user.email "$GIT_USER_EMAIL"
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

    # 添加 GitHub remote（仅当 USER 和 HOST 都配置时）
    if [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_HOST" ]; then
        local remote_url="git@${GITHUB_HOST}:${GITHUB_USER}/$project.git"
        git remote add github "$remote_url"
        echo -e "\033[32m[成功] GitHub remote: github -> $remote_url\033[0m"
    fi

    # 添加 Gitee remote（仅当 USER 和 HOST 都配置时）
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
    fi
}

# ============================================================
# 创建 GitHub 仓库
# ============================================================
create_github_repo() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "\033[33m[INFO] GitHub Token 未配置，跳过\033[0m"
        return 0
    fi

    local project
    project=$(get_project_name)

    echo -e "\033[36m[INFO] 创建 GitHub 仓库: $project\033[0m"

    local response
    response=$(curl -s -X POST "https://api.github.com/user/repos" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"name\":\"$project\",\"private\":true,\"auto_init\":false,\"description\":\"Auto initialized by git-full-local.sh\"}")

    if echo "$response" | grep -q '"html_url"'; then
        local url
        url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
        echo -e "\033[32m[成功] GitHub 仓库已创建: $url\033[0m"
        return 0
    fi

    if echo "$response" | grep -qE "(already exists|409|422)"; then
        echo -e "\033[32m[成功] GitHub 仓库已存在，跳过创建\033[0m"
        return 0
    fi

    echo -e "\033[31m[错误] GitHub 仓库创建失败\033[0m"
    echo -e "\033[31m[错误] 响应: $response\033[0m"
    return 1
}

# ============================================================
# 创建 Gitee 仓库
# ============================================================
create_gitee_repo() {
    if [ -z "$GITEE_TOKEN" ]; then
        echo -e "\033[33m[INFO] Gitee Token 未配置，跳过\033[0m"
        return 0
    fi

    local project
    project=$(get_project_name)

    echo -e "\033[36m[INFO] 创建 Gitee 仓库: $project\033[0m"

    local response
    response=$(curl -s -X POST "https://gitee.com/api/v5/user/repos" \
        -d "access_token=$GITEE_TOKEN" \
        -d "name=$project" \
        -d "private=true" \
        -d "description=Auto initialized by git-full-local.sh")

    if echo "$response" | grep -q '"html_url"'; then
        local url
        url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
        echo -e "\033[32m[成功] Gitee 仓库已创建: $url\033[0m"
        return 0
    fi

    if echo "$response" | grep -qE "(already exists|already been taken|422)"; then
        echo -e "\033[32m[成功] Gitee 仓库已存在，跳过创建\033[0m"
        return 0
    fi

    echo -e "\033[31m[错误] Gitee 仓库创建失败\033[0m"
    echo -e "\033[31m[错误] 响应: $response\033[0m"
    return 1
}

# ============================================================
# 初始提交
# ============================================================
initial_commit() {
    local project
    project=$(get_project_name)

    if [ ! -f "README.md" ]; then
        echo "# $project" > README.md
        echo -e "\033[36m[INFO] 已创建 README.md\033[0m"
    fi

    git add .

    local status_output
    status_output=$(git status 2>&1)
    if echo "$status_output" | grep -q "have diverged"; then
        echo -e "\033[36m[INFO] 远程有变更，先拉取...\033[0m"
        git pull --rebase origin main 2>&1 || true
    fi

    local result
    result=$(git commit -m "Initial commit (auto by git-full-local.sh)" 2>&1) || true

    if echo "$result" | grep -q "nothing to commit"; then
        echo -e "\033[36m[INFO] 暂无新文件需要提交，跳过\033[0m"
        return 0
    fi

    if echo "$result" | grep -q "main" || echo "$result" | grep -q "master"; then
        echo -e "\033[32m[成功] 初始提交完成\033[0m"
        return 0
    fi

    echo -e "\033[36m[INFO] 提交状态: $result\033[0m"
    return 0
}

# ============================================================
# 推送到所有平台（带 force push 降级策略）
# ============================================================
push_all() {
    local has_github
    local has_gitee

    has_github=$(git remote | grep -c "^github$" || true)
    has_gitee=$(git remote | grep -c "^gitee$" || true)

    if [ "$has_github" -gt 0 ]; then
        echo -e "\033[36m[INFO] 推送到 GitHub...\033[0m"
        if git push github main 2>&1; then
            echo -e "\033[32m[成功] GitHub 推送成功\033[0m"
        else
            echo -e "\033[33m[警告] GitHub 推送失败，尝试 pull --rebase...\033[0m"
            if git pull --rebase github main 2>&1; then
                echo -e "\033[36m[INFO] pull --rebase 成功，重试推送...\033[0m"
                if git push github main 2>&1; then
                    echo -e "\033[32m[成功] GitHub 推送成功\033[0m"
                else
                    echo -e "\033[31m[错误] GitHub 推送失败\033[0m"
                    return 1
                fi
            else
                echo -e "\033[31m[错误] GitHub pull --rebase 失败\033[0m"
                return 1
            fi
        fi
    fi

    if [ "$has_gitee" -gt 0 ]; then
        echo -e "\033[36m[INFO] 推送到 Gitee...\033[0m"
        if git push gitee main 2>&1; then
            echo -e "\033[32m[成功] Gitee 推送成功\033[0m"
        else
            echo -e "\033[33m[警告] Gitee 推送失败，尝试 pull --rebase...\033[0m"
            if git pull --rebase gitee main 2>&1; then
                echo -e "\033[36m[INFO] pull --rebase 成功，重试推送...\033[0m"
                if git push gitee main 2>&1; then
                    echo -e "\033[32m[成功] Gitee 推送成功\033[0m"
                else
                    # 场景：远程已删除但仓库重建，本地无历史
                    echo -e "\033[33m[警告] Gitee 推送失败，尝试强制推送...\033[0m"
                    if git push gitee main --force 2>&1; then
                        echo -e "\033[32m[成功] Gitee 强制推送成功\033[0m"
                    else
                        echo -e "\033[33m[警告] Gitee 强制推送失败，重置本地...\033[0m"
                        git fetch gitee 2>&1 || true
                        git reset --hard gitee/main 2>&1 || true
                        if git push gitee main --force 2>&1; then
                            echo -e "\033[32m[成功] Gitee 强制推送成功\033[0m"
                        else
                            echo -e "\033[31m[错误] Gitee 推送失败\033[0m"
                            return 1
                        fi
                    fi
                fi
            else
                # 场景：远程有历史但本地是全新的
                echo -e "\033[33m[警告] Gitee pull --rebase 失败，尝试强制推送...\033[0m"
                git fetch gitee 2>&1 || true
                git reset --hard gitee/main 2>&1 || true
                if git push gitee main --force 2>&1; then
                    echo -e "\033[32m[成功] Gitee 强制推送成功\033[0m"
                else
                    echo -e "\033[31m[错误] Gitee 推送失败\033[0m"
                    return 1
                fi
            fi
        fi
    fi

    return 0
}

# ============================================================
# 清理 Remote
# ============================================================
cleanup_remotes() {
    echo -e "\033[33m[INFO] 清理 remotes...\033[0m"

    local existing_remotes
    existing_remotes=$(git remote 2>/dev/null || true)
    if [ -n "$existing_remotes" ]; then
        for remote in $existing_remotes; do
            git remote remove "$remote" 2>/dev/null || true
        done
    fi

    echo -e "\033[33m[INFO] Remote 清理完成\033[0m"
}

# ============================================================
# 检查仓库是否存在
# ============================================================
check_repo_exists() {
    local platform=$1

    local project
    project=$(get_project_name)

    if [ "$platform" = "github" ]; then
        if [ -z "$GITHUB_TOKEN" ]; then
            return 1
        fi

        local http_code
        http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$GITHUB_USER/$project")

        if [ "$http_code" = "200" ]; then
            return 0
        else
            return 1
        fi
    else
        if [ -z "$GITEE_TOKEN" ]; then
            return 1
        fi

        local http_code
        http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
            "https://gitee.com/api/v5/repos/$GITEE_USER/$project?access_token=$GITEE_TOKEN")

        if [ "$http_code" = "200" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# ============================================================
# 删除 GitHub 仓库
# ============================================================
delete_github_repo() {
    if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USER" ]; then
        return 0
    fi

    local project
    project=$(get_project_name)

    echo -e "\033[36m[INFO] 删除 GitHub 仓库: $project\033[0m"

    local http_code
    http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_USER/$project")

    if [ "$http_code" = "204" ] || [ "$http_code" = "404" ]; then
        echo -e "\033[32m[成功] GitHub 仓库已删除 (HTTP $http_code)\033[0m"
        return 0
    fi

    echo -e "\033[31m[错误] GitHub 仓库删除失败 (HTTP $http_code)\033[0m"
    return 1
}

# ============================================================
# 删除 Gitee 仓库
# ============================================================
delete_gitee_repo() {
    if [ -z "$GITEE_TOKEN" ] || [ -z "$GITEE_USER" ]; then
        return 0
    fi

    local project
    project=$(get_project_name)

    echo -e "\033[36m[INFO] 删除 Gitee 仓库: $project\033[0m"

    local http_code
    http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Accept: application/json" \
        "https://gitee.com/api/v5/repos/$GITEE_USER/$project?access_token=$GITEE_TOKEN")

    if [ "$http_code" = "204" ] || [ "$http_code" = "404" ]; then
        echo -e "\033[32m[成功] Gitee 仓库已删除 (HTTP $http_code)\033[0m"
        return 0
    fi

    echo -e "\033[31m[错误] Gitee 仓库删除失败 (HTTP $http_code)\033[0m"
    return 1
}

# ============================================================
# 执行删除
# ============================================================
do_delete() {
    local project
    project=$(get_project_name)

    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mGit 双平台 - 删除远程仓库\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    echo -e "\033[33m警告：这将删除以下仓库：\033[0m"
    if [ -n "$GITHUB_USER" ]; then
        echo -e "\033[33m  - GitHub: https://github.com/$GITHUB_USER/$project\033[0m"
    fi
    if [ -n "$GITEE_USER" ]; then
        echo -e "\033[33m  - Gitee: https://gitee.com/$GITEE_USER/$project\033[0m"
    fi
    echo ""

    read -p "Confirm delete? Enter YES to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "\033[36m[INFO] Cancelled\033[0m"
        exit 0
    fi

    if ! check_tokens; then
        echo -e "\033[31m[错误] Token 检查失败，退出\033[0m"
        exit 1
    fi

    if [ -n "$GITHUB_TOKEN" ]; then
        if ! delete_github_repo; then
            echo -e "\033[31m[错误] GitHub 删除失败\033[0m"
        fi
    fi

    if [ -n "$GITEE_TOKEN" ]; then
        if ! delete_gitee_repo; then
            echo -e "\033[31m[错误] Gitee 删除失败\033[0m"
        fi
    fi

    cleanup_remotes

    echo ""
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[32m[完成] 远程仓库已删除!\033[0m"
    echo -e "\033[36m========================================\033[0m"
}

# ============================================================
# 执行 Reset
# ============================================================
do_reset() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mGit 双平台 - 重置本地配置\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    echo -e "\033[33m警告：这将清理本地 git 配置：\033[0m"
    echo "  - 删除所有 remotes (github, gitee)"
    echo "  - 删除 pushall 别名"
    echo "  - 本地文件不会被删除"
    echo ""

    read -p "Confirm reset? Enter YES to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "\033[36m[INFO] Cancelled\033[0m"
        exit 0
    fi

    # 删除所有 remotes
    local existing_remotes
    existing_remotes=$(git remote 2>/dev/null || true)
    if [ -n "$existing_remotes" ]; then
        for remote in $existing_remotes; do
            git remote remove "$remote" 2>/dev/null || true
            echo -e "\033[32m[成功] 已删除 remote: $remote\033[0m"
        done
    else
        echo -e "\033[36m[INFO] 没有 remotes 需要删除\033[0m"
    fi

    # 删除 pushall 别名
    git config --local --unset-all alias.pushall 2>/dev/null || true
    echo -e "\033[32m[成功] 已删除 pushall 别名\033[0m"

    echo ""
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[32m[完成] 本地 git 配置已重置!\033[0m"
    echo -e "\033[36m运行 './git-full-local.sh' 重新初始化\033[0m"
    echo -e "\033[36m========================================\033[0m"
}

# ============================================================
# 执行 Clean
# ============================================================
do_clean() {
    local project
    project=$(get_project_name)

    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mGit 双平台 - 完全清理\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    echo -e "\033[31m警告：这将完全删除本地 git 仓库：\033[0m"
    echo "  - 删除 .git 目录"
    echo "  - 删除所有 remotes 和别名"
    echo "  - 警告：此操作无法撤销！\033[0m"
    echo ""

    # 检查远程仓库状态
    local github_exists=0
    local gitee_exists=0

    if [ -n "$GITHUB_USER" ]; then
        echo -e "\033[36m[INFO] 检查 GitHub 仓库状态...\033[0m"
        if check_repo_exists "github"; then
            github_exists=1
            echo -e "\033[33m[警告] GitHub 仓库仍存在: https://github.com/$GITHUB_USER/$project\033[0m"
        else
            echo -e "\033[32m[成功] GitHub 仓库已删除\033[0m"
        fi
    fi

    if [ -n "$GITEE_USER" ]; then
        echo -e "\033[36m[INFO] 检查 Gitee 仓库状态...\033[0m"
        if check_repo_exists "gitee"; then
            gitee_exists=1
            echo -e "\033[33m[警告] Gitee 仓库仍存在: https://gitee.com/$GITEE_USER/$project\033[0m"
        else
            echo -e "\033[32m[成功] Gitee 仓库已删除\033[0m"
        fi
    fi

    if [ "$github_exists" -eq 1 ] || [ "$gitee_exists" -eq 1 ]; then
        echo ""
        echo -e "\033[33m[警告] 远程仓库仍存在。清理本地后，\033[0m"
        echo -e "\033[33m[警告] 请运行 './git-full-local.sh --delete' 先删除远程仓库。\033[0m"
        echo ""
    fi

    read -p "Type 'yes' to confirm complete removal: " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "\033[36m[INFO] Cancelled\033[0m"
        exit 0
    fi

    # 检查 .git 是否存在
    if [ -d ".git" ]; then
        # 删除 .git 目录
        rm -rf .git
        echo -e "\033[32m[成功] 已删除 .git 目录\033[0m"
    else
        echo -e "\033[36m[INFO] 没有 .git 目录需要删除\033[0m"
    fi

    echo ""
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[32m[完成] 本地 git 仓库已删除!\033[0m"
    if [ "$github_exists" -eq 1 ] || [ "$gitee_exists" -eq 1 ]; then
        echo -e "\033[33m重要提示: 请运行 './git-full-local.sh --delete' 清理远程仓库\033[0m"
    fi
    echo -e "\033[36m运行 './git-full-local.sh' 开始全新初始化\033[0m"
    echo -e "\033[36m========================================\033[0m"
}

# ============================================================
# 执行初始化
# ============================================================
do_init() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mGit 完整初始化工具 - Git 双平台\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # 检查是否配置了用户
    if [ -z "$GITHUB_USER" ] && [ -z "$GITEE_USER" ]; then
        echo -e "\033[31m[错误] 未配置任何用户，请检查 .env 文件\033[0m"
        exit 1
    fi

    # 检查 Token
    if ! check_tokens; then
        exit 1
    fi

    # 测试 SSH
    check_ssh

    # 初始化 Git
    init_git

    # 创建仓库
    if ! create_github_repo; then
        echo -e "\033[31m[错误] GitHub 仓库创建失败，退出\033[0m"
        exit 1
    fi

    if ! create_gitee_repo; then
        echo -e "\033[31m[错误] Gitee 仓库创建失败，回滚...\033[0m"
        cleanup_remotes
        exit 1
    fi

    # 配置 Remote
    setup_remotes

    # 初始提交
    if ! initial_commit; then
        echo -e "\033[31m[错误] 提交失败，回滚...\033[0m"
        cleanup_remotes
        exit 1
    fi

    # 推送
    if ! push_all; then
        echo -e "\033[31m[错误] 推送失败，可能需要手动干预\033[0m"
        exit 1
    fi

    # 设置别名
    setup_pushall_alias

    echo ""
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[32m[完成] 双平台项目已就绪!\033[0m"
    echo -e "\033[36m----------------------------------------\033[0m"
    echo "使用说明:"
    echo "  git add ."
    echo "  git commit -m 'update'"
    echo "  git pushall"
    echo -e "\033[36m========================================\033[0m"
}

# ============================================================
# 解析命令行参数
# ============================================================
ACTION="init"
for arg in "$@"; do
    case "$arg" in
        --delete)
            ACTION="delete"
            ;;
        --reset)
            ACTION="reset"
            ;;
        --clean)
            ACTION="clean"
            ;;
        --help|-h)
            ACTION="help"
            ;;
    esac
done

# 执行
case "$ACTION" in
    help)
        show_help
        ;;
    delete)
        load_config
        do_delete
        ;;
    reset)
        load_config
        do_reset
        ;;
    clean)
        load_config
        do_clean
        ;;
    init)
        load_config
        do_init
        ;;
esac