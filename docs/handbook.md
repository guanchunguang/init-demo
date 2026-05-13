# Git DevOps CLI 使用手册

> 本手册面向两种用户场景：新环境初始化 和 现有环境维护

---

## 场景一：新环境初始化

**适用用户**：首次使用 Git DevOps CLI 的用户，电脑上没有配置过 Git 环境

**目标**：从零开始，完成 SSH 配置、仓库创建、本地 Git 初始化

### 操作流程

#### Step 1: 准备工作目录

```powershell
# Windows PowerShell
mkdir test
cd test

# Linux/macOS Bash
mkdir test
cd test
```

**目的**：创建项目目录

---

#### Step 2: 复制配置文件

将 `.env.example` 复制为 `.env`，并配置你的账户信息：

```ini
GITHUB_ACCOUNTS=[{"user":"your-username","host":"github-yourname","token":"ghp_xxx"}]
GITEE_ACCOUNTS=[{"user":"your-username","host":"gitee-yourname","token":"xxx"}]
GIT_USER_NAME=your-username
GIT_USER_EMAIL=your@email.com
```

**目的**：存储平台 Token 和 Git 用户信息

---

#### Step 3: 配置 SSH（如果还没有配置过）

```powershell
# Windows
.\git-devops.ps1 ssh create -p github -f

# Linux/macOS
./git-devops.sh ssh create -p github -f
```

**目的**：
- 生成 SSH 密钥对
- 将公钥推送到 GitHub/Gitee
- 验证 SSH 连接是否正常

**预期输出**：
```
[INFO] Creating SSH key...
[OK] SSH key created: ~/.ssh/id_ed25519_github_yourname
[INFO] Pushing SSH public key to platform...
[OK] Added to GitHub (ID: xxxxxxxx)
[INFO] Verifying SSH connection...
[OK] github-yourname SSH connection OK
```

---

#### Step 4: 一键初始化（创建仓库 + 配置 Git）

```powershell
# Windows - 单平台
.\git-devops.ps1 all init -p github -y

# Windows - 双平台
.\git-devops.ps1 all init -p github -p gitee -y

# Linux/macOS - 单平台
./git-devops.sh all init -p github -y

# Linux/macOS - 双平台
./git-devops.sh all init -p github -p gitee -y
```

**目的**：
- 在 GitHub/Gitee 创建远程仓库
- 初始化本地 Git 仓库
- 配置双平台 remote
- 设置 `pushall` 别名

**预期输出**：
```
[INFO] ========================================
[INFO] Git DevOps One-Command Init
[INFO] ========================================
[INFO] [github] SSH key exists, skipping
[INFO] [github] Creating remote repo...
[OK] GitHub repo created: test
[INFO] [github] Initializing Git repo...
[OK] Git repo created
[INFO] [github] Configuring remotes...
[OK] GitHub remote: github -> git@github-yourname:username/test.git
[OK] Gitee remote: gitee -> git@gitee-yourname:username/test.git
[OK] pushall alias configured
```

---

#### Step 5: 提交代码

```bash
echo "# test" > README.md
git add .
git commit -m "Initial commit"
git pushall
```

**目的**：验证完整流程，提交并推送到双平台

---

## 场景二：现有环境维护

**适用用户**：已有 Git 环境，需要重新配置或清理的用户

**目标**：清理现有配置、重新初始化、或者完全重置

### 操作流程

#### 场景 2A：清理本地配置（保留 .git 历史）

**适用情况**：
- 想保留 git 历史，只清理 remote 配置
- 重新开始但不想丢失提交记录

```powershell
# Windows
.\git-devops.ps1 -c -y

# Linux/macOS
./git-devops.sh -c -y
```

**目的**：
- 移除所有 remote 配置
- 删除 `pushall` 别名
- 保留 `.git` 目录和历史记录

**预期输出**：
```
[WARN] Cleaning local Git config (keeping .git)...
[INFO] Removed remote: gitee
[INFO] Removed remote: github
[OK] Local Git config cleaned (git history preserved)
```

---

#### 场景 2B：完全重置（删除 .git 目录）

**适用情况**：
- 想完全重新开始
- 不需要保留任何提交记录

```powershell
# Windows
.\git-devops.ps1 -r -y

# Linux/macOS
./git-devops.sh -r -y
```

**目的**：
- 删除整个 `.git` 目录
- 相当于从未使用过 Git

**预期输出**：
```
[WARN] Resetting local Git repo (delete .git)...
[OK] .git directory deleted
```

---

#### 场景 2C：清理平台资源（平台密钥 + 仓库）

**适用情况**：
- 想完全清空所有资源
- 需要重新创建

```powershell
# Windows - 预览模式（先看会做什么）
.\git-devops.ps1 --dry-run clean keys -p github -y

# Windows - 执行清理
.\git-devops.ps1 clean keys -p github -y
.\git-devops.ps1 clean repos -p github -y

# Linux/macOS - 执行清理
./git-devops.sh clean keys -p github -y
./git-devops.sh clean repos -p github -y
```

**目的**：
- 从平台删除 SSH 公钥
- 删除本地 SSH 密钥文件
- 删除远程仓库

**注意**：使用 `--dry-run` 可以先预览将要执行的操作，确认无误后再执行

---

#### 场景 2D：重新初始化

**适用情况**：
- 清理完成后，需要重新配置

```powershell
# Windows
.\git-devops.ps1 all init -p github -y

# Linux/macOS
./git-devops.sh all init -p github -y
```

**目的**：重新创建仓库、配置 remote

---

## 参数速查表

### 全局控制类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-y` | `--yes` | 开关 | 自动确认所有提示 |
| `-h` | `--help` | 开关 | 显示帮助 |
| `-D` | `--debug` | 开关 | 调试模式（显示详细信息） |
| `-q` | `--quiet` | 开关 | 安静模式（只显示警告和错误） |

### 平台/操作类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-p` | `--platform` | 值 | 平台：github 或 gitee |
| `-n` | `--name` | 值 | 仓库名称 |
| `-t` | `--title` | 值 | SSH 密钥标题 |
| `-f` | `--force` | 开关 | 强制覆盖已存在的资源 |

### 危险操作类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-c` | `--clean` | 开关 | 清理本地 Git 配置（保留 .git） |
| `-r` | `--reset` | 开关 | 删除 .git 目录 |
| (无) | `--dry-run` | 开关 | 预览模式（只显示，不执行） |

### 子命令

| 子命令 | 说明 |
|--------|------|
| `ssh create` | 创建 SSH 密钥对 |
| `ssh push` | 推送公钥到平台 |
| `ssh verify` | 验证 SSH 连接 |
| `ssh remove` | 从平台删除公钥 |
| `repo create` | 创建远程仓库 |
| `repo delete` | 删除远程仓库 |
| `git init` | 初始化本地 Git 仓库 |
| `git remote` | 配置远程仓库 |
| `git push` | 推送到远程仓库 |
| `all init` | 一键初始化（SSH + 仓库 + Git） |
| `clean keys` | 清理 SSH 密钥（平台 + 本地） |
| `clean repos` | 清理远程仓库 |

---

## 命令示例

### 从零开始（新用户）

```powershell
# 1. 创建目录
mkdir test
cd test

# 2. 配置 .env 文件

# 3. 创建 SSH 密钥并推送到平台
.\git-devops.ps1 ssh create -p github -f
.\git-devops.ps1 ssh verify -p github

# 4. 一键初始化
.\git-devops.ps1 all init -p github -y

# 5. 提交代码
echo "# test" > README.md
git add .
git commit -m "Initial commit"
git pushall
```

### 预览危险操作（推荐先执行）

```powershell
# 预览清理操作，不会真正执行
.\git-devops.ps1 --dry-run clean keys -p github -y
.\git-devops.ps1 --dry-run clean repos -p github -y
```

### 完全重新开始

```powershell
# 1. 完全重置（删除 .git）
.\git-devops.ps1 -r -y

# 2. 清理平台资源
.\git-devops.ps1 clean keys -p github -y
.\git-devops.ps1 clean repos -p github -y

# 3. 重新初始化
.\git-devops.ps1 all init -p github -y
```

---

## 故障处理

### 问题：SSH 连接失败

**检查**：
```powershell
.\git-devops.ps1 ssh verify -p github
```

**解决**：确认公钥已添加到 GitHub/Gitee 设置中

---

### 问题：仓库已存在

**解决**：使用 `-f` 强制覆盖，或 `-y` 自动跳过
```powershell
.\git-devops.ps1 all init -p github -y -f
```

---

### 问题：执行 `--dry-run` 后想真正执行

**解决**：去掉 `--dry-run` 参数重新执行
```powershell
.\git-devops.ps1 clean keys -p github -y
```

---

## 快速命令卡片

### 新环境初始化
```
1. mkdir test && cd test
2. 配置 .env
3. ssh create -p github -f
4. all init -p github -y
5. git add . && git commit -m "init" && git pushall
```

### 清理（保留 .git）
```
-c -y
```

### 完全重置
```
-r -y
```

### 预览清理
```
--dry-run clean keys -p github -y
```