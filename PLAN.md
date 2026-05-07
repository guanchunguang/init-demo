# Git 双平台初始化 - 使用场景与执行计划

---

## 场景分类

| 场景 | 适用情况 | 使用的脚本 |
|------|---------|-----------|
| **A** | 首次配置，从零开始 | ssh-init-config → git-full-local |
| **B** | 本地已有 Git 仓库，只需添加双平台 remote | git-init-local → 手动 push |
| **C** | 远程仓库已创建，只需推送代码 | git-init-local → git push |
| **D** | 清理重新开始 | git-full-local --delete → 重新 A 或 C |

---

## 场景 A：首次配置（从零开始）

### 前提条件
- 已安装 Git
- 已生成 SSH 密钥并添加到平台（通过 ssh-init-config 或手动）

### 执行顺序

```
1. ssh-init-config --push-key     # 推送公钥到 GitHub + Gitee
2. git-full-local                 # 创建远程仓库 + 推送代码
```

### 详细步骤

**Step 1: 推送 SSH 公钥**
```bash
# Windows
.\ssh-init-config.ps1 --push-key

# Linux/macOS
./ssh-init-config.sh --push-key
```

**预期输出：**
```
[INFO] Adding GitHub public key: guanchunguang...
  [SKIP] Key already registered on GitHub (ID: 150528298)
[INFO] Adding Gitee public key: guanchunguang...
  [SKIP] Key already registered on Gitee (ID: 5757822)
```

**Step 2: 初始化项目**
```bash
# Windows
.\git-full-local.ps1

# Linux/macOS
./git-full-local.sh
```

**预期输出：**
```
[OK] GitHub repo created: https://github.com/guanchunguang/init-demo
[OK] Gitee repo created: https://gitee.com/guanchunguang/init-demo
[OK] GitHub remote: github -> git@github-guanchunguang:...
[OK] Gitee remote: gitee -> git@gitee-guanchunguang:...
[INFO] Pushing to GitHub...
[OK] GitHub push OK
[INFO] Pushing to Gitee...
[OK] Gitee push OK
```

### 异常情况处理

| 异常 | 表现 | 处理方法 |
|------|------|---------|
| **SSH 连接失败** | `Permission denied (publickey)` | 执行 `ssh-init-config.ps1 --verify-ssh` 检查密钥匹配 |
| **仓库已存在** | `GitHub repo already exists` | 正常，说明之前已创建，可忽略 |
| **推送被拒绝** | `fetch first` | 执行 `git pull --rebase origin main && git pushall` |
| **Token 无效** | `401 Unauthorized` | 检查 .env 中的 GITHUB_TOKEN / GITEE_TOKEN |

---

## 场景 B：本地已有 Git 仓库

### 前提条件
- 本地已执行 `git init`
- SSH 公钥已添加到平台

### 执行顺序

```
1. git-init-local              # 配置双 remote + pushall 别名
2. git add . && git commit      # 提交代码
3. git pushall                  # 推送到双平台
```

### 详细步骤

```bash
# 1. 配置双平台 remote（不创建远程仓库）
.\git-init-local.ps1

# 2. 提交代码
git add .
git commit -m "init"

# 3. 推送到双平台
git pushall
```

### 异常情况处理

| 异常 | 表现 | 处理方法 |
|------|------|---------|
| **remote 已存在** | `remote github already exists` | 正常，脚本已处理 |
| **分支名错误** | Git 提示分支不存在 | 检查本地分支是否为 main |

---

## 场景 C：远程仓库已创建，只推送代码

### 前提条件
- GitHub 和 Gitee 仓库已存在
- 本地已配置好 SSH

### 执行顺序

```
1. git clone 或 已有本地仓库
2. git remote -v 确认 remote 配置正确
3. git push 推送到任一平台即可
```

### 详细步骤

```bash
# 如果需要添加 remote
git remote add github git@github-guanchunguang:guanchunguang/repo.git
git remote add gitee git@gitee-guanchunguang:guanchunguang/repo.git

# 推送
git push github main
git push gitee main
```

---

## 场景 D：清理重新开始

### 执行顺序

```
1. git-full-local --delete      # 删除远程仓库
2. 重新执行 A 或 C               # 重新初始化
```

### 详细步骤

```bash
# 删除远程仓库（两个平台都删）
.\git-full-local.ps1 --delete

# 确认删除
# 访问 https://github.com/guanchunguang/repo 和 https://gitee.com/guanchunguang/repo 确认已删除

# 重新开始
.\git-full-local.ps1
```

### 异常情况处理

| 异常 | 表现 | 处理方法 |
|------|------|---------|
| **删除失败** | `404 Not Found` | 说明仓库已不存在，正常 |
| **部分删除成功** | GitHub 删除但 Gitee 失败 | 手动删除 Gitee 仓库 |

---

## ssh-init-config 单独使用场景

### 场景 E：检查 SSH 状态

```bash
.\ssh-init-config.ps1 --verify-ssh
```

**输出示例（正常）：**
```
[OK] github-guanchunguang SSH connection OK
[OK] gitee-guanchunguang SSH connection OK
```

**输出示例（异常）：**
```
[WARN] github-guanchunguang response unexpected: Permission denied
[MISMATCH] Local key NOT registered on GitHub
```

### 场景 F：查看平台已注册密钥

```bash
.\ssh-init-config.ps1 --list-keys
```

**输出示例：**
```
[INFO] GitHub public key list
  ID: 150528298 | Title: ssh-init-config 20260505165155 guanchunguang
[INFO] Gitee public key list
  ID: 5757822 | Title: ssh-init-config 20260505165156 guanchunguang
```

### 场景 G：清理平台密钥（重新配置）

```bash
# 1. 查看当前密钥
.\ssh-init-config.ps1 --list-keys

# 2. 删除指定密钥
.\ssh-init-config.ps1 --delete-key github 150528298
.\ssh-init-config.ps1 --delete-key gitee 5757822

# 3. 重新推送
.\ssh-init-config.ps1 --push-key
```

---

## 脚本功能对照表

| 功能 | ssh-init-config | git-init-local | git-full-local |
|------|----------------|----------------|----------------|
| 生成 SSH 密钥命令 | ✅ | - | - |
| 生成 SSH config | ✅ | - | - |
| 推送公钥到平台 | ✅ | - | - |
| 验证 SSH 连接 | ✅ | - | - |
| 列出平台密钥 | ✅ | - | - |
| 删除平台密钥 | ✅ | - | - |
| git init | - | ✅ | ✅ |
| 配置双 remote | - | ✅ | ✅ |
| 创建远程仓库 | - | - | ✅ |
| 推送代码 | - | 手动 | ✅ |
| 删除远程仓库 | - | - | ✅ |

---

## 快速参照

### 每日使用
```bash
# 推送代码（无论哪个场景）
git add .
git commit -m "message"
git pushall          # git-init-local 配置的别名
```

### 首次设置
```bash
# 1. 配置 SSH 公钥
.\ssh-init-config.ps1 --push-key

# 2. 初始化项目
.\git-full-local.ps1
```

### 检查状态
```bash
# 检查 SSH 是否正常
.\ssh-init-config.ps1 --verify-ssh

# 查看平台密钥
.\ssh-init-config.ps1 --list-keys
```

### 故障恢复
```bash
# SSH 连接失败
.\ssh-init-config.ps1 --verify-ssh

# 推送被拒绝
git pull --rebase origin main && git pushall

# 重新初始化
.\git-full-local.ps1 --delete
.\git-full-local.ps1
```