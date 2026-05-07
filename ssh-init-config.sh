#!/bin/bash
# ============================================================
# SSH 密钥与配置生成器 - Git 双平台
# ============================================================
# 功能：
#   - 生成 SSH 密钥对命令
#   - 生成 SSH config 配置
#   - （可选）通过 API 分发公钥到 GitHub/Gitee
#   - （可选）验证 SSH 连接
#   - （可选）列出平台上的公钥
#   - （可选）删除平台上的公钥
#
# 使用方法：
#   ./ssh-init-config.sh                    # 仅显示信息
#   ./ssh-init-config.sh --push-key         # 显示 + 分发公钥
#   ./ssh-init-config.sh --verify-ssh       # 显示 + 验证 SSH
#   ./ssh-init-config.sh --list-keys         # 显示 + 列出平台公钥
#   ./ssh-init-config.sh --delete-key        # 删除平台公钥（需配合参数）
#   ./ssh-init-config.sh --all              # 显示 + 分发公钥 + 验证 SSH
#   ./ssh-init-config.sh --help|-h          # 显示帮助
#
# 支持平台：Linux / macOS
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.env"
SSH_DIR="${HOME}/.ssh"

# ============================================================
# 显示帮助
# ============================================================
show_help() {
    echo ""
    echo -e "\033[36mSSH 密钥与配置生成器 - Git 双平台\033[0m"
    echo ""
    echo -e "\033[33m使用方法：\033[0m"
    echo "  ./ssh-init-config.sh                    # 仅显示信息（默认）"
    echo "  ./ssh-init-config.sh --push-key         # 显示 + 分发公钥到平台"
    echo "  ./ssh-init-config.sh --verify-ssh       # 显示 + 验证 SSH 连接"
    echo "  ./ssh-init-config.sh --list-keys        # 显示 + 列出平台公钥"
    echo "  ./ssh-init-config.sh --delete-key <平台> <密钥ID>  # 删除平台公钥"
    echo "  ./ssh-init-config.sh --all              # 显示 + 分发公钥 + 验证 SSH"
    echo "  ./ssh-init-config.sh --help|-h          # 显示帮助"
    echo ""
    echo -e "\033[33m参数说明：\033[0m"
    echo "  --push-key     通过 API 分发公钥到 GitHub/Gitee（需 Token）"
    echo "  --verify-ssh   验证 SSH 连接是否正常"
    echo "  --list-keys    列出平台已添加的公钥"
    echo "  --delete-key   删除平台上的公钥（需指定平台和密钥ID）"
    echo "  --all          执行全部操作（--push-key + --verify-ssh）"
    echo ""
    echo -e "\033[33m删除公钥示例：\033[0m"
    echo "  ./ssh-init-config.sh --delete-key github 123456"
    echo "  ./ssh-init-config.sh --delete-key gitee 789012"
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
# 显示 SSH 密钥生成命令
# ============================================================
show_commands() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m请执行以下命令生成 SSH 密钥\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # GitHub 用户
    if [ -n "$GITHUB_USER" ]; then
        local key_file="id_ed25519_github_$GITHUB_USER"
        echo "# GitHub - $GITHUB_USER"
        echo "ssh-keygen -t ed25519 -f ~/.ssh/$key_file -C \"$GIT_USER_EMAIL\""
        echo ""
    fi

    # Gitee 用户
    if [ -n "$GITEE_USER" ]; then
        local key_file="id_ed25519_gitee_$GITEE_USER"
        echo "# Gitee - $GITEE_USER"
        echo "ssh-keygen -t ed25519 -f ~/.ssh/$key_file -C \"$GIT_USER_EMAIL\""
        echo ""
    fi
}

# ============================================================
# 显示 SSH config 内容
# ============================================================
show_config() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mSSH config 内容\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""
    echo "将以下内容添加到 ~/.ssh/config："
    echo ""

    # GitHub 用户
    if [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_HOST" ]; then
        local key_file="id_ed25519_github_$GITHUB_USER"

        echo "# GitHub - $GITHUB_USER"
        echo "Host $GITHUB_HOST"
        echo "    HostName github.com"
        echo "    User git"
        echo "    IdentityFile ~/.ssh/$key_file"
        echo "    IdentitiesOnly yes"
        echo ""
    fi

    # Gitee 用户
    if [ -n "$GITEE_USER" ] && [ -n "$GITEE_HOST" ]; then
        local key_file="id_ed25519_gitee_$GITEE_USER"

        echo "# Gitee - $GITEE_USER"
        echo "Host $GITEE_HOST"
        echo "    HostName gitee.com"
        echo "    User git"
        echo "    IdentityFile ~/.ssh/$key_file"
        echo "    IdentitiesOnly yes"
        echo ""
    fi
}

# ============================================================
# 显示公钥内容
# ============================================================
show_public_keys() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m公钥内容\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # GitHub 用户
    if [ -n "$GITHUB_USER" ]; then
        local pub_key="${SSH_DIR}/id_ed25519_github_$GITHUB_USER.pub"

        if [ -f "$pub_key" ]; then
            echo "[GitHub - $GITHUB_USER]"
            cat "$pub_key"
            echo ""
        else
            echo -e "\033[33m[GitHub - $GITHUB_USER] 密钥不存在，请先运行 ssh-keygen 命令\033[0m"
            echo ""
        fi
    fi

    # Gitee 用户
    if [ -n "$GITEE_USER" ]; then
        local pub_key="${SSH_DIR}/id_ed25519_gitee_$GITEE_USER.pub"

        if [ -f "$pub_key" ]; then
            echo "[Gitee - $GITEE_USER]"
            cat "$pub_key"
            echo ""
        else
            echo -e "\033[33m[Gitee - $GITEE_USER] 密钥不存在，请先运行 ssh-keygen 命令\033[0m"
            echo ""
        fi
    fi
}

# ============================================================
# 通过 API 分发公钥到 GitHub
# ============================================================
push_key_to_github() {
    local title="$1"
    local pub_key_file="$2"
    local token="$3"

    if [ ! -f "$pub_key_file" ]; then
        echo -e "  \033[33m[跳过]\033[0m 密钥文件不存在: $pub_key_file"
        return 1
    fi

    local key_content
    key_content=$(cat "$pub_key_file" | tr -d '\n')

    # 检查密钥是否已存在
    local match_result
    match_result=$(test_key_match "github" "$key_content" "$token")
    if [[ "$match_result" == MATCHED:* ]]; then
        local key_id="${match_result##MATCHED:}"
        echo -e "  \033[33m[跳过]\033[0m 密钥已在 GitHub 注册 (ID: $key_id)"
        return 0
    fi

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
        echo -e "  \033[32m[成功]\033[0m 已添加到 GitHub: $title (ID: $id)"
        return 0
    else
        echo -e "  \033[31m[失败]\033[0m GitHub 添加失败"
        return 1
    fi
}

# ============================================================
# 通过 API 分发公钥到 Gitee
# ============================================================
push_key_to_gitee() {
    local title="$1"
    local pub_key_file="$2"
    local token="$3"

    if [ ! -f "$pub_key_file" ]; then
        echo -e "  \033[33m[跳过]\033[0m 密钥文件不存在: $pub_key_file"
        return 1
    fi

    local key_content
    key_content=$(cat "$pub_key_file" | tr -d '\n')

    # 检查密钥是否已存在
    local match_result
    match_result=$(test_key_match "gitee" "$key_content" "$token")
    if [[ "$match_result" == MATCHED:* ]]; then
        local key_id="${match_result##MATCHED:}"
        echo -e "  \033[33m[跳过]\033[0m 密钥已在 Gitee 注册 (ID: $key_id)"
        return 0
    fi

    local response
    response=$(curl -s --max-time 30 -X POST \
        -d "access_token=$token" \
        -d "title=$title" \
        -d "key=$key_content" \
        "https://gitee.com/api/v5/user/keys")

    if echo "$response" | grep -q '"id"'; then
        local id
        id=$(echo "$response" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
        echo -e "  \033[32m[成功]\033[0m 已添加到 Gitee: $title (ID: $id)"
        return 0
    else
        echo -e "  \033[31m[失败]\033[0m Gitee 添加失败"
        return 1
    fi
}

# ============================================================
# 分发公钥到平台
# ============================================================
push_keys() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m通过 API 分发公钥到平台\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # GitHub 用户
    if [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_TOKEN" ]; then
        echo -e "\033[36m[INFO] 正在添加 GitHub 公钥: $GITHUB_USER...\033[0m"
        local pub_key="${SSH_DIR}/id_ed25519_github_$GITHUB_USER.pub"
        push_key_to_github "ssh-init-config $(date +%s) $GITHUB_USER" "$pub_key" "$GITHUB_TOKEN"
    else
        if [ -z "$GITHUB_TOKEN" ]; then
            echo -e "\033[33m[警告] GITHUB_TOKEN 未配置\033[0m"
        fi
    fi

    # Gitee 用户
    if [ -n "$GITEE_USER" ] && [ -n "$GITEE_TOKEN" ]; then
        echo -e "\033[36m[INFO] 正在添加 Gitee 公钥: $GITEE_USER...\033[0m"
        local pub_key="${SSH_DIR}/id_ed25519_gitee_$GITEE_USER.pub"
        push_key_to_gitee "ssh-init-config $(date +%s) $GITEE_USER" "$pub_key" "$GITEE_TOKEN"
    else
        if [ -z "$GITEE_TOKEN" ]; then
            echo -e "\033[33m[警告] GITEE_TOKEN 未配置\033[0m"
        fi
    fi

    echo ""
}

# ============================================================
# 获取 GitHub 已注册公钥
# ============================================================
get_platform_keys_github() {
    local token="$1"

    curl -s --max-time 30 -X GET \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/keys"
}

# ============================================================
# 获取 Gitee 已注册公钥
# ============================================================
get_platform_keys_gitee() {
    local token="$1"

    curl -s --max-time 30 -X GET \
        "https://gitee.com/api/v5/user/keys?access_token=$token"
}

# ============================================================
# 检测本地公钥是否在平台上注册
# ============================================================
test_key_match() {
    local platform="$1"
    local local_key="$2"
    local token="$3"

    # GitHub API returns keys WITHOUT comment, Gitee WITH comment
    local key_to_compare
    if [ "$platform" = "github" ]; then
        key_to_compare=$(echo "$local_key" | awk '{print $1 " " $2}')
    else
        key_to_compare="$local_key"
    fi

    local response
    local key_list

    if [ "$platform" = "github" ]; then
        response=$(get_platform_keys_github "$token")
        key_list=$(echo "$response" | grep -oE '"key":[[:space:]]*"[^"]*"' | sed 's/"key":[[:space:]]*"//;s/"$//')
    else
        response=$(get_platform_keys_gitee "$token")
        key_list=$(echo "$response" | grep -oE '"key":"[^"]*"' | sed 's/"key":"//;s/"$//')
    fi

    while IFS= read -r platform_key; do
        if [ "$platform_key" = "$key_to_compare" ]; then
            # 提取 ID
            local key_id
            if [ "$platform" = "github" ]; then
                key_id=$(echo "$response" | grep -B20 "key\":\"$platform_key" 2>/dev/null | grep -oE '"id":[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
            else
                key_id=$(echo "$response" | grep -B20 "key\":\"$platform_key" 2>/dev/null | grep -oE '"id":[0-9]+' | head -1 | cut -d':' -f2)
            fi
            echo "MATCHED:$key_id"
            return 0
        fi
    done <<< "$key_list"

    echo "NOT_MATCHED"
    return 1
}

# ============================================================
# 验证 SSH 连接
# ============================================================
verify_ssh() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m验证 SSH 连接\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # GitHub 用户
    if [ -n "$GITHUB_HOST" ]; then
        local pub_key="${SSH_DIR}/id_ed25519_github_$GITHUB_USER.pub"

        echo -e "\033[36m[GitHub - $GITHUB_USER]\033[0m"
        local local_key=""
        if [ -f "$pub_key" ]; then
            local_key=$(cat "$pub_key" | tr -d '\n')
            echo "  本地公钥: $local_key"
        else
            echo -e "  \033[33m[警告] 公钥不存在: $pub_key\033[0m"
        fi

        echo -e "\033[36m[INFO] 测试 $GITHUB_HOST ...\033[0m"

        local result
        local ssh_ok="false"
        if result=$(timeout 10 ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$GITHUB_HOST" 2>&1); then
            :
        fi

        if echo "$result" | grep -qE "(Hi|successfully authenticated)"; then
            echo -e "  \033[32m[成功]\033[0m $GITHUB_HOST SSH 连接正常"
            ssh_ok="true"
        else
            echo -e "  \033[35m[警告]\033[0m $GITHUB_HOST 响应异常: $result"
        fi

        # 密钥匹配检查
        if [ "$ssh_ok" = "false" ] && [ -n "$local_key" ] && [ -n "$GITHUB_TOKEN" ]; then
            local match_result
            match_result=$(test_key_match "github" "$local_key" "$GITHUB_TOKEN")
            if [[ "$match_result" == MATCHED:* ]]; then
                local key_id="${match_result##MATCHED:}"
                echo -e "  \033[35m[不匹配]\033[0m 本地密钥在 GitHub 上注册为 ID:$key_id"
            else
                echo -e "  \033[35m[不匹配]\033[0m 本地密钥未在 GitHub 上注册"
            fi
        fi
        echo ""
    fi

    # Gitee 用户
    if [ -n "$GITEE_HOST" ]; then
        local pub_key="${SSH_DIR}/id_ed25519_gitee_$GITEE_USER.pub"

        echo -e "\033[36m[Gitee - $GITEE_USER]\033[0m"
        local local_key=""
        if [ -f "$pub_key" ]; then
            local_key=$(cat "$pub_key" | tr -d '\n')
            echo "  本地公钥: $local_key"
        else
            echo -e "  \033[33m[警告] 公钥不存在: $pub_key\033[0m"
        fi

        echo -e "\033[36m[INFO] 测试 $GITEE_HOST ...\033[0m"

        local result
        local ssh_ok="false"
        if result=$(timeout 10 ssh -T -o StrictHostKeyChecking=no -o ConnectTimeout=10 "git@$GITEE_HOST" 2>&1); then
            :
        fi

        if echo "$result" | grep -qE "(Hi|successfully authenticated)"; then
            echo -e "  \033[32m[成功]\033[0m $GITEE_HOST SSH 连接正常"
            ssh_ok="true"
        else
            echo -e "  \033[35m[警告]\033[0m $GITEE_HOST 响应异常: $result"
        fi

        # 密钥匹配检查
        if [ "$ssh_ok" = "false" ] && [ -n "$local_key" ] && [ -n "$GITEE_TOKEN" ]; then
            local match_result
            match_result=$(test_key_match "gitee" "$local_key" "$GITEE_TOKEN")
            if [[ "$match_result" == MATCHED:* ]]; then
                local key_id="${match_result##MATCHED:}"
                echo -e "  \033[35m[不匹配]\033[0m 本地密钥在 Gitee 上注册为 ID:$key_id"
            else
                echo -e "  \033[35m[不匹配]\033[0m 本地密钥未在 Gitee 上注册"
            fi
        fi
        echo ""
    fi
}

# ============================================================
# 列出平台上的公钥 - GitHub
# ============================================================
list_keys_github() {
    local token="$1"

    echo -e "\033[36m[INFO] GitHub 公钥列表\033[0m"

    local response
    response=$(curl -s --max-time 30 -X GET \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user/keys")

    if echo "$response" | grep -q '"id"'; then
        local count
        count=$(echo "$response" | grep -oE '"id":[[:space:]]*[0-9]+' | wc -l)
        local i=1
        while [ "$i" -le "$count" ]; do
            local id
            id=$(echo "$response" | grep -oE '"id":[[:space:]]*[0-9]+' | sed -n "${i}p" | grep -oE '[0-9]+')
            local title
            title=$(echo "$response" | grep -oE '[[:space:]]*"title":[[:space:]]*"[^"]*"' | sed -n "${i}p" | sed 's/.*"title":[[:space:]]*"//;s/"$//')
            echo "  ID: $id | Title: $title"
            i=$((i + 1))
        done
        echo ""
    else
        echo -e "  \033[33m[警告] 无法获取 GitHub 公钥列表\033[0m"
        echo ""
    fi
}

# ============================================================
# 列出平台上的公钥 - Gitee
# ============================================================
list_keys_gitee() {
    local token="$1"

    echo -e "\033[36m[INFO] Gitee 公钥列表\033[0m"

    local response
    response=$(curl -s --max-time 30 -X GET \
        "https://gitee.com/api/v5/user/keys?access_token=$token")

    if echo "$response" | grep -q '"id"'; then
        local count
        count=$(echo "$response" | grep -o '"id":[0-9]*' | wc -l)
        local i=1
        while [ "$i" -le "$count" ]; do
            local id
            id=$(echo "$response" | grep -o '"id":[0-9]*' | sed -n "${i}p" | cut -d':' -f2)
            local title
            title=$(echo "$response" | grep -o "\"title\":\"[^\"]*\"" | sed -n "${i}p" | sed 's/"title":"//;s/"$//')
            echo "  ID: $id | Title: $title"
            i=$((i + 1))
        done
        echo ""
    else
        echo -e "  \033[33m[警告] 无法获取 Gitee 公钥列表\033[0m"
        echo ""
    fi
}

# ============================================================
# 列出平台公钥
# ============================================================
list_keys() {
    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m列出平台 SSH 公钥\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    # GitHub
    if [ -n "$GITHUB_TOKEN" ]; then
        list_keys_github "$GITHUB_TOKEN"
    else
        echo -e "\033[33m[警告] GITHUB_TOKEN 未配置\033[0m"
    fi

    # Gitee
    if [ -n "$GITEE_TOKEN" ]; then
        list_keys_gitee "$GITEE_TOKEN"
    else
        echo -e "\033[33m[警告] GITEE_TOKEN 未配置\033[0m"
    fi
}

# ============================================================
# 删除平台公钥 - GitHub
# ============================================================
delete_key_github() {
    local key_id="$1"
    local token="$2"

    echo -e "\033[36m[INFO] 删除 GitHub 公钥: $key_id\033[0m"

    local http_code
    http_code=$(curl -s --max-time 30 -X DELETE \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/vnd.github.v3+json" \
        -o /dev/null -w "%{http_code}" \
        "https://api.github.com/user/keys/$key_id")

    if [ "$http_code" = "204" ]; then
        echo -e "\033[32m[成功]\033[0m GitHub 公钥已删除 (ID: $key_id)"
        return 0
    else
        echo -e "\033[31m[失败]\033[0m GitHub 公钥删除失败 (HTTP $http_code)"
        return 1
    fi
}

# ============================================================
# 删除平台公钥 - Gitee
# ============================================================
delete_key_gitee() {
    local key_id="$1"
    local token="$2"

    echo -e "\033[36m[INFO] 删除 Gitee 公钥: $key_id\033[0m"

    local http_code
    http_code=$(curl -s --max-time 30 -X DELETE \
        -o /dev/null -w "%{http_code}" \
        "https://gitee.com/api/v5/user/keys/$key_id?access_token=$token")

    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        echo -e "\033[32m[成功]\033[0m Gitee 公钥已删除 (ID: $key_id)"
        return 0
    else
        echo -e "\033[31m[失败]\033[0m Gitee 公钥删除失败 (HTTP $http_code)"
        return 1
    fi
}

# ============================================================
# 删除平台公钥
# ============================================================
delete_key() {
    local platform="$1"
    local key_id="$2"

    if [ -z "$platform" ] || [ -z "$key_id" ]; then
        echo -e "\033[31m[错误] 使用方法: ./ssh-init-config.sh --delete-key <平台> <密钥ID>\033[0m"
        echo "  平台: github 或 gitee"
        echo "  密钥ID: 从 --list-keys 获取"
        return 1
    fi

    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36m删除平台 SSH 公钥\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    case "$platform" in
        github)
            if [ -z "$GITHUB_TOKEN" ]; then
                echo -e "\033[31m[错误] GITHUB_TOKEN 未配置\033[0m"
                return 1
            fi
            delete_key_github "$key_id" "$GITHUB_TOKEN"
            ;;
        gitee)
            if [ -z "$GITEE_TOKEN" ]; then
                echo -e "\033[31m[错误] GITEE_TOKEN 未配置\033[0m"
                return 1
            fi
            delete_key_gitee "$key_id" "$GITEE_TOKEN"
            ;;
        *)
            echo -e "\033[31m[错误] 未知平台: $platform\033[0m"
            echo "  平台必须是: github 或 gitee"
            return 1
            ;;
    esac

    echo ""
}

# ============================================================
# 主函数
# ============================================================
main() {
    # list-keys, verify-ssh, delete-key 只显示各自结果，跳过默认显示
    if [ "$ACTION" = "list-keys" ] || [ "$ACTION" = "verify-ssh" ] || [ "$ACTION" = "delete-key" ]; then
        if [ "$ACTION" = "list-keys" ]; then
            list_keys
        elif [ "$ACTION" = "verify-ssh" ]; then
            verify_ssh
        else
            delete_key "$DELETE_PLATFORM" "$DELETE_KEY_ID"
        fi
        echo ""
        echo -e "\033[32m[完成]\033[0m"
        return
    fi

    echo -e "\033[36m========================================\033[0m"
    echo -e "\033[36mSSH 密钥与配置生成器 - Git 双平台\033[0m"
    echo -e "\033[36m========================================\033[0m"
    echo ""

    show_commands
    show_config
    show_public_keys

    case "$ACTION" in
        all)
            push_keys
            verify_ssh
            ;;
        push-key)
            push_keys
            ;;
        delete-key)
            delete_key "$DELETE_PLATFORM" "$DELETE_KEY_ID"
            ;;
        *)
            if [ "$ACTION" = "display" ]; then
                echo ""
                echo -e "\033[33m[提示] 如需其他操作，请使用以下参数：\033[0m"
                echo "  ./ssh-init-config.sh --push-key      # 分发公钥到平台"
                echo "  ./ssh-init-config.sh --verify-ssh    # 验证 SSH 连接"
                echo "  ./ssh-init-config.sh --list-keys     # 列出平台公钥"
                echo "  ./ssh-init-config.sh --delete-key <平台> <密钥ID>  # 删除公钥"
                echo "  ./ssh-init-config.sh --all          # 全部执行"
            fi
            ;;
    esac

    echo ""
    echo -e "\033[32m[完成]\033[0m"
}

# ============================================================
# 解析命令行参数
# ============================================================
ACTION="display"
DELETE_PLATFORM=""
DELETE_KEY_ID=""
for arg in "$@"; do
    case "$arg" in
        --push-key)
            ACTION="push-key"
            ;;
        --verify-ssh)
            ACTION="verify-ssh"
            ;;
        --list-keys)
            ACTION="list-keys"
            ;;
        --delete-key)
            ACTION="delete-key"
            ;;
        --all)
            ACTION="all"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        github|gitee)
            if [ "$ACTION" = "delete-key" ] && [ -z "$DELETE_PLATFORM" ]; then
                DELETE_PLATFORM="$arg"
            fi
            ;;
        *)
            if [ "$ACTION" = "delete-key" ] && [ -n "$DELETE_PLATFORM" ] && [ -z "$DELETE_KEY_ID" ]; then
                DELETE_KEY_ID="$arg"
            fi
            ;;
    esac
done

# 加载配置
load_config

# 执行
main
