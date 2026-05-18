# Git-DevOps 使用手册

**项目：** init-demo
**版本：** 1.0
**更新日期：** 2026-05-18
**支持平台：** Windows (PowerShell) / Linux (Bash)
**支持 Git 平台：** GitHub + Gitee

---

## 一、快速开始

### 1.1 环境要求

| 组件 | Windows 要求 | Linux 要求 |
|------|-------------|------------|
| Git | 已安装并配置 | 已安装并配置 |
| SSH | Git Bash 或 WSL | OpenSSH |
| 配置文件 | `.env` 文件 | `.env` 文件 |

### 1.2 配置文件 (.env)

```env
# GitHub 账户配置
GITHUB_ACCOUNTS=[{"user":"你的用户名","host":"github-你的用户名","token":"ghp_你的token"}]

# Gitee 账户配置
GITEE_ACCOUNTS=[{"user":"你的用户名","host":"gitee-你的用户名","token":"你的token"}]

# Git 用户配置
GIT_USER_NAME=你的用户名
GIT_USER_EMAIL=你的邮箱
```

**获取 Token 方法：**
- GitHub: Settings → Developer settings → Personal access tokens → Generate new token
- Gitee: 个人设置 → 私人令牌 → 创建私人令牌

---

## 二、两种场景下的完整流程

### 场景 A：新电脑（无 Git 环境）

**目标：** 在空目录初始化项目并推送到 GitHub 和 Gitee

```powershell
# 1. 进入项目目录
cd D:\VSCodeWorkSpace\my-project

# 2. 配置 Git 用户信息（如果还没配置）
git config --global user.name "你的用户名"
git config --global user.email "你的邮箱"

# 3. 创建 SSH 密钥（如果还没有）
.\git-devops.ps1 ssh create -p github
.\git-devops.ps1 ssh create -p gitee

# 4. 上传 SSH 公钥到平台（如果还没有）
.\git-devops.ps1 ssh push -p github
.\git-devops.ps1 ssh push -p gitee

# 5. 验证 SSH 连接
.\git-devops.ps1 ssh verify -p github
.\git-devops.ps1 ssh verify -p gitee

# 6. 初始化 Git 仓库
.\git-devops.ps1 git init

# 7. 创建远程仓库
.\git-devops.ps1 repo create -p github -n my-project
.\git-devops.ps1 repo create -p gitee -n my-project

# 8. 配置远程仓库
.\git-devops.ps1 git remote

# 9. 添加代码并提交
echo "# My Project" > README.md
git add .
git commit -m "Initial commit"

# 10. 推送到所有远程
.\git-devops.ps1 git push
```

**或者使用一键初始化（推荐）：**

```powershell
cd D:\VSCodeWorkSpace\my-project
echo "# My Project" > README.md
.\git-devops.ps1 all init -y
.\git-devops.ps1 git push
```

---

### 场景 B：已有 Git 环境的电脑

**目标：** 已有本地仓库，想快速同步到 GitHub 和 Gitee

```powershell
# 1. 进入已有项目目录
cd D:\VSCodeWorkSpace\existing-project

# 2. 一键初始化（自动完成 SSH/Repo/Remote 配置）
.\git-devops.ps1 all init -y

# 3. 推送到远程
.\git-devops.ps1 git push
```

**如果只想添加新的远程平台：**

```powershell
# 添加 GitHub（如果还没有）
.\git-devops.ps1 ssh create -p github
.\git-devops.ps1 ssh push -p github
.\git-devops.ps1 repo create -p github -n project-name
git remote add github git@github-你的用户名:你的用户名/project-name.git

# 添加 Gitee
.\git-devops.ps1 ssh create -p gitee
.\git-devops.ps1 ssh push -p gitee
.\git-devops.ps1 repo create -p gitee -n project-name
git remote add gitee git@gitee-你的用户名:你的用户名/project-name.git
```

---

## 三、常用命令参考

### 3.1 SSH 管理

```powershell
# 创建 SSH 密钥
.\git-devops.ps1 ssh create -p github              # 创建 GitHub SSH 密钥
.\git-devops.ps1 ssh create -p gitee               # 创建 Gitee SSH 密钥

# 上传公钥到平台
.\git-devops.ps1 ssh push -p github                # 上传 GitHub 公钥
.\git-devops.ps1 ssh push -p gitee                 # 上传 Gitee 公钥

# 验证 SSH 连接
.\git-devops.ps1 ssh verify -p github              # 验证 GitHub 连接
.\git-devops.ps1 ssh verify -p gitee               # 验证 Gitee 连接

# 删除平台上的公钥
.\git-devops.ps1 ssh remove -p github -y           # 从 GitHub 删除
.\git-devops.ps1 ssh remove -p gitee -y            # 从 Gitee 删除
```

### 3.2 仓库管理

```powershell
# 创建远程仓库
.\git-devops.ps1 repo create -p github -n my-repo   # 在 GitHub 创建
.\git-devops.ps1 repo create -p gitee -n my-repo    # 在 Gitee 创建

# 删除远程仓库
.\git-devops.ps1 repo delete -p github -n my-repo -y   # 在 GitHub 删除
.\git-devops.ps1 repo delete -p gitee -n my-repo -y    # 在 Gitee 删除
```

### 3.3 Git 本地操作

```powershell
# 初始化 Git 仓库
.\git-devops.ps1 git init                           # 初始化（自动设置 user.name/email）

# 配置远程仓库
.\git-devops.ps1 git remote                         # 配置 github 和 gitee remote

# 推送到远程
.\git-devops.ps1 git push                           # 推送到所有远程
.\git-devops.ps1 git push -p github                 # 仅推送到 GitHub
.\git-devops.ps1 git push -p gitee                  # 仅推送到 Gitee
```

### 3.4 一键初始化

```powershell
# 一键完成所有配置（SSH 创建 → 上传 → 仓库创建 → Git 初始化 → Remote 配置）
.\git-devops.ps1 all init -y                        # 自动执行，无需确认
.\git-devops.ps1 all init                           # 交互式确认
.\git-devops.ps1 all init -DryRun                   # 预览模式，不实际执行
```

### 3.5 清理操作

```powershell
# 清理本地 Git 配置（保留 .git）
.\git-devops.ps1 -c -y

# 删除 .git 目录（重置仓库）
.\git-devops.ps1 -r -y

# 清理 SSH 密钥
.\git-devops.ps1 clean keys -p github -y           # 清理 GitHub SSH 密钥
.\git-devops.ps1 clean keys -y                       # 清理所有平台 SSH 密钥

# 清理远程仓库
.\git-devops.ps1 clean repos -p github -y          # 删除 GitHub 远程仓库

# 完整清理（仓库 + SSH + 本地配置 + .git）
.\git-devops.ps1 clean full -y
```

---

## 四、命令选项说明

### 4.1 全局选项

| 选项 | 说明 |
|------|------|
| `-p, --platform` | 指定平台：`github` 或 `gitee` |
| `-n, --name` | 仓库名称 |
| `-t, --title` | SSH 密钥标题 |
| `-f, --force` | 覆盖已有资源（如强制覆盖 SSH 密钥） |
| `-y, --yes` | 自动确认危险操作（如删除） |
| `-D, --debug` | 显示 DEBUG 级别日志 |
| `-q, --quiet` | 仅显示 WARN 和 ERROR |
| `-h, --help` | 显示帮助信息 |
| `--dry-run` | 预览模式，不实际执行 |

### 4.2 日志级别

| 级别 | 颜色 | 说明 |
|------|------|------|
| DEBUG | 灰色 | 详细调试信息（使用 `-D` 显示） |
| INFO | 青色 | 一般操作信息（默认显示） |
| WARN | 黄色 | 警告信息（如资源已存在） |
| ERROR | 红色 | 错误信息（需要处理） |
| SUCCESS | 绿色 | 成功信息 |

---

## 五、幂等性说明

**幂等性** = 重复执行相同命令会产生相同结果，不会报错。

| 操作 | 重复执行结果 | 说明 |
|------|-------------|------|
| SSH create | ✅ WARN | 密钥已存在时警告但不失败 |
| SSH push | ✅ WARN | 公钥已存在时跳过但不报错 |
| Repo create | ✅ WARN | 仓库已存在时警告但不失败 |
| Repo delete | ✅ WARN | 仓库不存在时警告但继续 |
| Git init | ✅ INFO | 仓库已初始化时跳过 |

**示例：**
```powershell
# 第一次创建仓库
.\git-devops.ps1 repo create -p github -n my-repo
# 输出: [OK] GitHub repo created: my-repo

# 第二次创建（幂等）
.\git-devops.ps1 repo create -p github -n my-repo
# 输出: [WARN] GitHub repo already exists: my-repo
# 不会失败！
```

---

## 六、故障排查

### 6.1 SSH 连接失败

**问题：** `Could not resolve hostname`

**解决：** 检查 `~/.ssh/config` 是否正确配置，或者运行：
```powershell
.\git-devops.ps1 ssh verify -p github -D   # 查看详细错误
```

### 6.2 Token 权限不足

**问题：** `API forbidden` 或 `401 Unauthorized`

**解决：** 确保 Token 有以下权限：
- GitHub: `repo` (完整仓库权限) + `ssh_keys` (SSH 密钥权限)
- Gitee: `projects` (仓库权限)

### 6.3 推送被拒绝

**问题：** `Permission denied`

**解决：**
1. 验证 SSH 连接：`.\git-devops.ps1 ssh verify -p github`
2. 检查公钥是否已上传：`.\git-devops.ps1 ssh push -p github`
3. 检查 GitHub/Gitee 设置中的公钥

### 6.4 仓库删除失败

**问题：** HTTP 404 但脚本退出码 1

**解决：** 这是预期行为（仓库可能已被删除），不影响后续操作。如需跳过此错误，可忽略。

---

## 七、文件结构

```
项目目录/
├── .env                    # 配置文件（包含 Token）
├── git-devops.ps1          # Windows PowerShell 版本
├── git-devops.sh           # Linux Bash 版本
├── README.md               # 项目说明
└── .git/                   # Git 仓库目录
```

**SSH 密钥位置：**
- Windows: `C:\Users\用户名\.ssh\`
- Linux: `/home/用户名/.ssh/`

**密钥命名：**
- GitHub: `id_ed25519_github_用户名`
- Gitee: `id_ed25519_gitee_用户名`

---

## 八、安全注意事项

1. **不要提交 `.env` 文件** - 包含敏感 Token
2. **SSH 私钥文件权限** - Windows 由系统管理，Linux 需设置 `600`
3. **Token 保护** - 不要在代码中硬编码 Token，使用 `.env` 文件
4. **定期清理** - 使用完毕后运行 `clean full` 清理测试资源

---

## 九、命令速查表

| 操作 | Windows 命令 | Linux 命令 |
|------|--------------|------------|
| 帮助 | `.\git-devops.ps1 -h` | `./git-devops.sh -h` |
| 创建 SSH | `.\git-devops.ps1 ssh create -p github` | `./git-devops.sh ssh create -p github` |
| 上传公钥 | `.\git-devops.ps1 ssh push -p github` | `./git-devops.sh ssh push -p github` |
| 验证连接 | `.\git-devops.ps1 ssh verify -p github` | `./git-devops.sh ssh verify -p github` |
| 创建仓库 | `.\git-devops.ps1 repo create -p github -n myrepo` | `./git-devops.sh repo create -p github -n myrepo` |
| 删除仓库 | `.\git-devops.ps1 repo delete -p github -n myrepo -y` | `./git-devops.sh repo delete -p github -n myrepo -y` |
| 初始化 Git | `.\git-devops.ps1 git init` | `./git-devops.sh git init` |
| 配置远程 | `.\git-devops.ps1 git remote` | `./git-devops.sh git remote` |
| 推送代码 | `.\git-devops.ps1 git push` | `./git-devops.sh git push` |
| 一键初始化 | `.\git-devops.ps1 all init -y` | `./git-devops.sh all init -y` |
| 完整清理 | `.\git-devops.ps1 clean full -y` | `./git-devops.sh clean full -y` |
| Dry-Run | `.\git-devops.ps1 ssh create -p github -DryRun` | `./git-devops.sh --dry-run ssh create -p github` |

---

**手册版本：** 1.0
**最后更新：** 2026-05-18
**维护者：** Claude Code