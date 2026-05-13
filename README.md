# Git DevOps CLI

跨平台 Git 双平台管理工具，统一管理 GitHub 和 Gitee 的 Git 操作。

## 功能特性

- **SSH 管理**: 创建、推送、验证 SSH 密钥
- **仓库管理**: 创建、删除远程仓库
- **Git 初始化**: 初始化本地仓库，配置双平台远程仓库
- **一键初始化**: `all init` 完成所有初始化步骤
- **清理功能**: 清理本地 Git 配置

## 平台支持

- Windows PowerShell
- Linux/macOS Bash

---

## 快速开始

### 1. 配置文件

复制 `.env.example` 为 `.env`，配置您的账户信息：

```ini
# GitHub 多账户配置
GITHUB_ACCOUNTS=[{"user":"your-username","host":"github-yourname","token":"ghp_xxx"}]

# Gitee 多账户配置
GITEE_ACCOUNTS=[{"user":"your-username","host":"gitee-yourname","token":"xxx"}]

# Git 用户配置
GIT_USER_NAME=your-username
GIT_USER_EMAIL=your@email.com
```

### 2. SSH 配置

确保 `~/.ssh/config` 配置了平台别名：

```ssh-config
# GitHub
Host github-yourname
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_yourname

# Gitee
Host gitee-yourname
    HostName gitee.com
    User git
    IdentityFile ~/.ssh/id_ed25519_gitee_yourname
```

---

## 使用方法

### Windows PowerShell

```powershell
# SSH 管理
.\git-devops.ps1 ssh create -Platform github     # 创建 SSH 密钥
.\git-devops.ps1 ssh push -Platform github       # 推送公钥到平台
.\git-devops.ps1 ssh verify -Platform github     # 验证 SSH 连接

# 仓库管理
.\git-devops.ps1 repo create -Platform github -Project myrepo   # 创建仓库
.\git-devops.ps1 repo delete -Platform github -Project myrepo -y # 删除仓库

# Git 初始化
.\git-devops.ps1 git init           # 初始化本地仓库
.\git-devops.ps1 git remote         # 配置双平台远程仓库
.\git-devops.ps1 git push -Platform github  # 推送到指定平台

# 一键初始化
.\git-devops.ps1 all init           # 完成所有初始化

# 清理
.\git-devops.ps1 clean reset -y    # 清理本地 Git 配置

# 帮助
.\git-devops.ps1 -Help
```

### Linux/macOS Bash

```bash
# 转换行结尾（如果是 Windows 传输过来的脚本）
sed -i 's/\r$//' git-devops.sh

# SSH 管理
./git-devops.sh -p github ssh create     # 创建 SSH 密钥
./git-devops.sh -p github ssh push       # 推送公钥到平台
./git-devops.sh -p github ssh verify     # 验证 SSH 连接

# 仓库管理
./git-devops.sh -p github repo create -n myrepo   # 创建仓库
./git-devops.sh -p github repo delete -n myrepo -y # 删除仓库

# Git 初始化
./git-devops.sh git init           # 初始化本地仓库
./git-devops.sh git remote         # 配置双平台远程仓库
./git-devops.sh -p github git push # 推送到指定平台

# 一键初始化
./git-devops.sh all init           # 完成所有初始化

# 清理
./git-devops.sh clean reset -y     # 清理本地 Git 配置

# 帮助
./git-devops.sh --help
```

---

## 测试方法

### Windows 测试

```powershell
# 1. 测试 SSH 创建和推送
.\git-devops.ps1 ssh create -Platform github -Force
.\git-devops.ps1 ssh push -Platform github -Title "test key"
.\git-devops.ps1 ssh verify -Platform github

# 2. 测试仓库创建和删除
.\git-devops.ps1 repo create -Platform github -Project test-repo
.\git-devops.ps1 repo delete -Platform github -Project test-repo -y

# 3. 测试 Git 初始化
.\git-devops.ps1 git init
.\git-devops.ps1 git remote

# 4. 测试完整流程
.\git-devops.ps1 all init
git add .
git commit -m "test"
git pushall

# 5. 测试清理
.\git-devops.ps1 clean reset -y
```

### Linux 本地测试

```bash
# 1. 转换行结尾（如果是 Windows 传输过来的脚本）
sed -i 's/\r$//' git-devops.sh

# 2. 测试 SSH
./git-devops.sh -p github ssh create
./git-devops.sh -p github ssh push
./git-devops.sh -p github ssh verify

# 3. 测试仓库
./git-devops.sh -p github repo create -n test-repo
./git-devops.sh -p github repo delete -n test-repo -y

# 4. 测试 Git 初始化
./git-devops.sh git init
./git-devops.sh git remote

# 5. 测试完整流程
./git-devops.sh all init
echo "test" > test.txt
git add .
git commit -m "test"
git pushall

# 6. 测试清理
./git-devops.sh clean reset -y
```

### 远程 Linux 测试（通过 SSH）

```bash
# 1. 从 Windows 连接到 Linux
ssh -i ~/.ssh/windows-to-linux user@192.168.80.132

# 2. 在 Linux 上创建测试目录
mkdir -p ~/git-devops-test
cd ~/git-devops-test

# 3. 上传文件（Windows 本地执行）
scp -i ~/.ssh/windows-to-linux git-devops.sh .env user@192.168.80.132:~/git-devops-test/

# 4. 在 Linux 上测试
sed -i 's/\r$//' git-devops.sh
chmod +x git-devops.sh
./git-devops.sh all init
git pushall
```

---

## 参数说明

| 参数 | 说明 |
|------|------|
| `-Platform`, `-p` | 平台: `github` 或 `gitee` |
| `-Project`, `-n` | 仓库名称 |
| `-User`, `-u` | 用户名 |
| `-Title` | SSH 密钥标题 |
| `-Force`, `-f` | 强制覆盖已存在的资源 |
| `-Yes`, `-y` | 自动确认所有提示 |
| `-Debug`, `-d` | 调试模式 |
| `-Quiet`, `-q` | 安静模式 |

---

## 项目结构

```
.
├── git-devops.ps1      # Windows PowerShell 版本
├── git-devops.sh       # Linux/macOS Bash 版本
├── .env                # 配置文件（包含敏感信息，不要提交）
├── .env.example        # 配置模板
├── .gitignore          # Git 忽略配置
└── README.md
```

---

## 注意事项

1. **Token 安全**: `.env` 文件包含平台 token，切勿提交到版本库
2. **SSH 密钥**: 建议为每个平台创建独立的 SSH 密钥对
3. **幂等性**: 脚本支持幂等操作，已存在的资源会提示确认
4. **行结尾**: Windows 传输到 Linux 后需执行 `sed -i 's/\r$//' script.sh`

---

## 故障处理

### GH013 Push cannot contain secrets

原因：`.env` 中的 Token 被提交到 Git 历史。

解决：
1. 访问 https://github.com/{owner}/{repo}/security/secret-scanning 允许 secret
2. 或从历史中清除（参考 git-filter-branch 或 git-filter-repo）

预防：确保 `.env` 在 `.gitignore` 中。

### SSH 连接失败

1. 确认公钥已添加到 GitHub/Gitee
2. 使用 `ssh verify` 验证连接
3. 检查 `~/.ssh/config` 配置

### 仓库已存在

脚本会检测仓库是否已存在，使用 `-Force` 或 `-y` 跳过确认。
