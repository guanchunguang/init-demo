# Git 双平台自动初始化工具

自动初始化 Git 项目，同步到 GitHub + Gitee。

---

## 目录

1. [概述](#概述)
2. [SSH 密钥与平台交互原理](#ssh-密钥与平台交互原理)
3. [配置文件](#配置文件)
4. [SSH 配置](#ssh-配置)
5. [ssh-init-config 密钥管理工具](#ssh-init-config-密钥管理工具)
6. [git-init-local 基础版](#git-init-local-基础版)
7. [git-full-local 完整版](#git-full-local-完整版)
8. [故障处理](#故障处理)

---

## 概述

### 完整流程

```
┌─────────────────────────────────────────────────────────────┐
│  第一阶段：SSH 配置（仅需执行一次）                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  .env ──→ ssh-init-config ──→ ssh-keygen ──→ 公钥分发        │
│                              │              │                │
│                              ↓              ↓                │
│                         生成 config    验证 SSH               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│  第二阶段：项目初始化（每个项目执行一次）                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  git-init-local.sh ──→ 本地 Git + 双 remote + pushall       │
│                                                             │
│  或                                                          │
│                                                             │
│  git-full-local.sh ──→ 创建仓库 + 推送代码                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## SSH 密钥与平台交互原理

### SSH 密钥格式

SSH 公钥文件格式为：`{类型} {Base64编码} {注释}`，例如：

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINeTu252u01KBsrTo1Enz62HF776cbumeY8X46A+BMRw guanchunguang@163.com
```

- **类型**：ssh-ed25519
- **Base64编码**：AAAAC3NzaC1lZDI1NTE5AAAA...
- **注释**：guanchunguang@163.com（通常为邮箱）

### 平台 API 密钥格式差异

| 平台 | API 返回格式 | 说明 |
|------|-------------|------|
| **GitHub** | `ssh-ed25519 AAA...XXX` | **不包含注释** |
| **Gitee** | `ssh-ed25519 AAA...XXX user@email.com` | **包含注释** |

这是因为两个平台的 API 设计不同导致的。

### 密钥匹配原理

本地公钥需要与平台上注册的公钥匹配才能通过 SSH 认证。

**匹配逻辑：**

```
本地公钥文件:  ssh-ed25519 AAA...XXX guanchunguang@163.com
                                ↓ 提取前两部分（去注释）
                 ssh-ed25519 AAA...XXX
                                ↓ 与平台密钥比较
GitHub API 返回: ssh-ed25519 AAA...XXX  → 匹配成功
Gitee API 返回:  ssh-ed25519 AAA...XXX guanchunguang@163.com  → 匹配成功
```

### Token 的作用

| Token | 用途 | 获取地址 |
|-------|------|---------|
| `GITHUB_TOKEN` | 通过 GitHub API 操作：创建仓库、添加/删除 SSH 公钥、查询密钥列表 | https://github.com/settings/tokens |
| `GITEE_TOKEN` | 通过 Gitee API 操作：创建仓库、添加/删除 SSH 公钥、查询密钥列表 | https://gitee.com/profile/personal_access_tokens |

### SSH 认证流程

```
本地 Git 操作 (git push)
        ↓
    读取 ~/.ssh/config 中的 IdentityFile
        ↓
    使用私钥对 SSH 服务器签名
        ↓
    SSH 服务器使用平台上的公钥验证签名
        ↓
    认证成功 → 推送代码
```

**前提条件：** 本地 SSH 私钥对应的公钥必须在平台上注册。

---

## 配置文件

### env.example 格式

```ini
# ---- GitHub 配置 ----
GITHUB_USER=guanchunguang
GITHUB_HOST=github-guanchunguang
GITHUB_TOKEN=your_github_token_here

# ---- Gitee 配置 ----
GITEE_USER=guanchunguang
GITEE_HOST=gitee-guanchunguang
GITEE_TOKEN=your_gitee_token_here

# ---- Git 用户配置 ----
GIT_USER_NAME=guanchunguang
GIT_USER_EMAIL=guanchunguang@163.com
```

### Token 获取

| 平台 | 地址 | 权限 |
|------|------|------|
| GitHub | https://github.com/settings/tokens | `repo` |
| Gitee | https://gitee.com/profile/personal_access_tokens | `projects` |

### 使用步骤

```bash
# 1. 复制配置文件模板
cp env.example .env

# 2. 编辑 .env，填入真实配置
nano .env

# 3. 确保 .env 不会被提交
#    项目已配置 .gitignore
```

---

## SSH 配置

### 功能说明

`ssh-init-config` 脚本用于：
- 生成 SSH 密钥对命令
- 生成 SSH config 配置模板
- **（可选）** 通过 API 分发公钥到 GitHub/Gitee
- **（可选）** 验证 SSH 连接（并检查本地密钥是否与平台匹配）
- **（可选）** 列出平台已注册的公钥
- **（可选）** 删除平台上的公钥

### SSH config 示例

根据 .env 配置，自动生成如下内容：

```ini
# GitHub - guanchunguang
Host github-guanchunguang
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_guanchunguang
    IdentitiesOnly yes

# Gitee - guanchunguang
Host gitee-guanchunguang
    HostName gitee.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitee_guanchunguang
    IdentitiesOnly yes
```

---

## ssh-init-config 密钥管理工具

### 使用方法

```bash
# Linux/macOS
./ssh-init-config.sh                    # 仅显示本地信息
./ssh-init-config.sh --push-key         # 显示 + 推送公钥到平台
./ssh-init-config.sh --verify-ssh       # 显示 + 验证 SSH 连接
./ssh-init-config.sh --list-keys        # 显示 + 列出平台公钥
./ssh-init-config.sh --delete-key <平台> <ID>  # 删除平台公钥
./ssh-init-config.sh --all              # 显示 + 推送 + 验证 SSH

# Windows (PowerShell)
.\ssh-init-config.ps1                   # 仅显示本地信息
.\ssh-init-config.ps1 --push-key        # 显示 + 推送公钥到平台
.\ssh-init-config.ps1 --verify-ssh      # 显示 + 验证 SSH 连接
.\ssh-init-config.ps1 --list-keys       # 显示 + 列出平台公钥
.\ssh-init-config.ps1 --delete-key <平台> <ID>  # 删除平台公钥
.\ssh-init-config.ps1 --all             # 显示 + 推送 + 验证 SSH
```

### 完整使用流程

```bash
# 1. 运行脚本，显示密钥生成命令和配置模板
./ssh-init-config.sh

# 2. 手动执行 ssh-keygen 命令生成密钥
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_guanchunguang -C "guanchunguang@163.com"
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_gitee_guanchunguang -C "guanchunguang@163.com"

# 3. 将 SSH config 内容添加到 ~/.ssh/config（参考脚本输出）

# 4. 推送公钥到平台（自动通过 API 分发）
./ssh-init-config.sh --push-key

# 5. 验证 SSH 连接
./ssh-init-config.sh --verify-ssh

# 6. 查看平台上已注册的公钥
./ssh-init-config.sh --list-keys

# 7. 删除平台上的公钥（如需重新配置）
./ssh-init-config.sh --delete-key github 123456
```

### 各功能详解

#### --push-key（推送公钥到平台）

**原理：**

```
1. 读取本地公钥文件内容
2. 调用平台 API 检查密钥是否已存在
   - GitHub: 比较 "ssh-ed25519 AAA...XXX"（无注释）
   - Gitee: 比较 "ssh-ed25519 AAA...XXX user@email.com"（有注释）
3. 如已存在，显示 [SKIP] 并跳过
4. 如不存在，通过 API 添加到平台
```

**幂等性：** 重复执行不会重复添加，平台已有密钥会被跳过。

#### --verify-ssh（验证 SSH 连接）

**原理：**

```
1. 读取本地公钥文件内容
2. 执行 ssh -T git@github-guanchunguang 测试连接
3. 如果连接成功 → 显示 [OK]
4. 如果连接失败 → 调用 API 检查本地密钥是否在平台注册
   - 已注册但 SSH 失败 = 密钥被其他设备推送过（多设备场景）
   - 未注册 = 本地密钥和平台不匹配
```

**多设备场景说明：**

如果同时在 Windows 和 Linux 上使用 ssh-init-config，每个设备会生成不同的密钥对。当在某一设备上执行 `--push-key` 时，只有该设备的公钥会被添加到平台。其他设备虽然 SSH config 指向同名密钥文件，但实际内容不同，导致 SSH 失败。

此时 `--verify-ssh` 会检测到密钥不匹配并提示。

#### --list-keys（列出平台公钥）

**原理：**

```
调用 GitHub API: GET https://api.github.com/user/keys
调用 Gitee API:  GET https://gitee.com/api/v5/user/keys?access_token=xxx
解析 JSON 响应，显示 ID 和标题
```

#### --delete-key（删除平台公钥）

**原理：**

```
调用 GitHub API: DELETE https://api.github.com/user/keys/{id}
调用 Gitee API:  DELETE https://gitee.com/api/v5/user/keys/{id}?access_token=xxx
```

### API 端点汇总

| 平台 | 操作 | API 端点 | 方法 |
|------|------|---------|------|
| GitHub | 列出密钥 | `https://api.github.com/user/keys` | GET |
| GitHub | 添加密钥 | `https://api.github.com/user/keys` | POST |
| GitHub | 删除密钥 | `https://api.github.com/user/keys/{id}` | DELETE |
| Gitee | 列出密钥 | `https://gitee.com/api/v5/user/keys?access_token=xxx` | GET |
| Gitee | 添加密钥 | `https://gitee.com/api/v5/user/keys` | POST |
| Gitee | 删除密钥 | `https://gitee.com/api/v5/user/keys/{id}?access_token=xxx` | DELETE |

---

## git-init-local 基础版

仅配置本地 Git + 双 remote，不创建远程仓库。

### 功能

- `git init -b main`
- 设置项目级 Git 用户信息
- 配置 GitHub + Gitee 双 remote
- 设置 `pushall` 命令别名

### 使用

```bash
# Linux/macOS
./git-init-local.sh

# Windows
.\git-init-local.ps1

# 后续操作
git add .
git commit -m "init"
git pushall
```

---

## git-full-local 完整版

创建远程仓库 + 初始化 + 推送。

### 功能

- 创建 GitHub 仓库（API）
- 创建 Gitee 仓库（API）
- 提交初始代码
- 推送到双平台
- 自动处理分支冲突（pull --rebase）

### 使用

```bash
# Linux/macOS
./git-full-local.sh                 # 初始化
./git-full-local.sh --delete        # 删除远程仓库

# Windows
.\git-full-local.ps1                 # 初始化
.\git-full-local.ps1 --delete        # 删除远程仓库
```

---

## 故障处理

### 推送被拒绝 (fetch first)

```bash
git pull --rebase origin main
git pushall
```

### GH013 Push cannot contain secrets

原因：`.env` 中的 Token 被提交到 Git 历史。

解决：在 GitHub 允许 secret
- https://github.com/{owner}/{repo}/security/secret-scanning

预防：确保 `.env` 在 `.gitignore` 中。

### SSH 连接失败

1. 确认公钥已添加到 GitHub/Gitee
2. 使用 ssh-init-config 验证：`./ssh-init-config.sh --verify-ssh`
3. 检查 `~/.ssh/config` 配置
4. 如果显示"密钥不匹配"，说明本地密钥和平台注册的密钥不一致

### 密钥不匹配处理

当 `--verify-ssh` 显示 `[MISMATCH]` 时，说明本地公钥和平台上注册的密钥不同。可能原因：

1. **多设备场景**：在不同设备上执行过 `--push-key`，每台设备的密钥不同
2. **手动配置**：在平台上手动添加了其他密钥

解决方案：
- 删除平台上不匹配的密钥，重新执行 `--push-key`
- 或使用平台上手动添加的密钥对应的私钥

---

## 项目结构

```
.
├── git-init-local.ps1      # 基础版 (Windows)
├── git-init-local.sh       # 基础版 (Linux/macOS)
├── git-full-local.ps1      # 完整版 (Windows)
├── git-full-local.sh       # 完整版 (Linux/macOS)
├── ssh-init-config.ps1     # SSH 配置 (Windows)
├── ssh-init-config.sh      # SSH 配置 (Linux/macOS)
├── env.example              # 配置模板
├── .env                     # 实际配置（不提交）
├── .gitignore               # 忽略 .env
└── README.md
```

---

## 设计原则

| 原则 | 说明 |
|------|------|
| 幂等设计 | 重复执行不会报错 |
| 失败回滚 | 出错时清理已创建的资源 |
| 项目级配置 | Git 配置使用 `--local` |
| 配置外置 | Token 放在 `.env` |
| main 分支 | 所有操作使用 `main` |
| 安全优先 | 敏感操作（如公钥分发）需明确授权 |
| 平台适配 | GitHub/Gitee 密钥格式差异自动处理 |