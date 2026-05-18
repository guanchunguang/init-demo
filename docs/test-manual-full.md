# Git-DevOps 双平台完整功能测试手册

**项目：** init-demo  
**脚本：** git-devops.ps1 (PowerShell)  
**平台：** GitHub + Gitee 双平台  
**测试日期：** 2026-05-17  
**测试方式：** 静态代码分析 + 功能场景设计

---

## 一、ssh-pass.py 与 upload.py 工具说明

### 1.1 ssh-pass.py（SSH 密码代理）

**用途：** 通过 SSH 密码认证方式执行远程 Linux 命令

**工作原理：**
1. 创建临时 `askpass` 脚本写入密码
2. 设置 `SSH_ASKPASS` 环境变量指向该脚本
3. 调用 `ssh` 命令执行远程命令
4. 自动清理临时脚本

**核心函数：**
```python
run(host, user, password, command, stdin_data=None) -> (exit_code, stdout, stderr)
```

**使用场景：**
- 远程执行 git 操作
- 远程机器无 SSH 密钥配置时的替代方案
- 通过密码认证而非密钥认证

---

### 1.2 upload.py（文件上传工具）

**用途：** 通过 SSH 密码认证将本地文件上传到远程 Linux

**工作原理：**
1. 读取本地文件并 Base64 编码
2. 通过 SSH 管道传输编码后的数据
3. 远程使用 Python 解码并写入文件

**核心函数：**
```python
upload_file(host, user, password, local, remote) -> None
```

**使用场景：**
- 上传 git-devops.sh 到远程 Linux
- 上传 .env 配置文件到远程
- 批量部署项目文件到多台服务器

---

## 二、git-devops.ps1 功能模块总览

```
git-devops.ps1 <module> <action> [options]

模块：
├── ssh      SSH 密钥管理
├── repo     远程仓库管理
├── git      本地 Git 配置
├── all      一键初始化
└── clean    清理操作

全局选项：
-p, --platform    目标平台 (github/gitee)
-n, --name       仓库名称
-t, --title      SSH 密钥标题
-f, --force      覆盖已有资源
-y, --yes        自动确认危险操作
-D, --debug      显示 DEBUG 日志
-q, --quiet      仅显示 WARN/ERROR
-h, --help       显示帮助
-c, --clean      清理本地配置（保留 .git）
-r, --reset      删除 .git 目录
--dry-run        预览模式
```

---

## 三、功能测试场景设计

### 场景 1：SSH 模块测试

#### 1.1 SSH 创建密钥

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 1.1.1 | `.\git-devops.ps1 ssh create -p github` | 创建 GitHub SSH 密钥成功，生成 `~/.ssh/id_ed25519_github_guanchunguang` |
| 1.1.2 | `.\git-devops.ps1 ssh create -p gitee` | 创建 Gitee SSH 密钥成功，生成 `~/.ssh/id_ed25519_gitee_guanchunguang` |
| 1.1.3 | `.\git-devops.ps1 ssh create -p github` (已存在) | 输出 WARN "SSH key already exists"，不覆盖 |
| 1.1.4 | `.\git-devops.ps1 ssh create -p github -f` (强制覆盖) | 覆盖已有密钥，生成 backup |
| 1.1.5 | `.\git-devops.ps1 ssh create` (无平台参数) | 输出 ERROR，要求指定 -p 参数 |

#### 1.2 SSH 上传公钥

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 1.2.1 | `.\git-devops.ps1 ssh push -p github` | 上传 GitHub 公钥成功，返回 SSH key ID |
| 1.2.2 | `.\git-devops.ps1 ssh push -p gitee` | 上传 Gitee 公钥成功，处理重复密钥 (400/422) |
| 1.2.3 | `.\git-devops.ps1 ssh push -p github` (重复) | 输出 WARN "GitHub SSH key already exists"，跳过 |
| 1.2.4 | `.\git-devops.ps1 ssh push -p gitee` (重复) | 输出 WARN "Gitee SSH key already exists"，跳过 |
| 1.2.5 | `.\git-devops.ps1 ssh push` (无平台参数) | 输出 ERROR，要求指定 -p 参数 |

#### 1.3 SSH 验证连接

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 1.3.1 | `.\git-devops.ps1 ssh verify -p github` | 输出 "Hi username! You've successfully authenticated..." → SSH connection OK |
| 1.3.2 | `.\git-devops.ps1 ssh verify -p gitee` | 输出 "Hi username! You've successfully connected..." → SSH connection OK |
| 1.3.3 | `.\git-devops.ps1 ssh verify` (无平台参数) | 输出 ERROR |

#### 1.4 SSH 删除密钥

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 1.4.1 | `.\git-devops.ps1 ssh remove -p github -y` | 从 GitHub 删除 SSH 公钥成功 |
| 1.4.2 | `.\git-devops.ps1 ssh remove -p gitee -y` | 从 Gitee 删除 SSH 公钥成功 |
| 1.4.3 | `.\git-devops.ps1 ssh remove -p github` (无 -y) | 提示确认删除 |
| 1.4.4 | `.\git-devops.ps1 ssh remove` (无平台参数) | 输出 ERROR |

#### 1.5 SSH Agent 管理

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 1.5.1 | `.\git-devops.ps1 ssh agent-start` | 启动 ssh-agent，设置 SSH_AUTH_SOCK 和 SSH_AGENT_PID 环境变量 |
| 1.5.2 | `.\git-devops.ps1 ssh agent-status` | 显示 ssh-agent 状态和已加载的密钥列表 |

---

### 场景 2：Repo 模块测试

#### 2.1 创建远程仓库

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 2.1.1 | `.\git-devops.ps1 repo create -p github -n test-repo` | 在 GitHub 创建公开仓库成功 |
| 2.1.2 | `.\git-devops.ps1 repo create -p gitee -n test-repo` | 在 Gitee 创建公开仓库成功 |
| 2.1.3 | `.\git-devops.ps1 repo create -p github -n test-repo` (重复) | 输出 WARN "GitHub repo already exists: test-repo" (HTTP 422) |
| 2.1.4 | `.\git-devops.ps1 repo create -p gitee -n test-repo` (重复) | 输出 WARN "Gitee repo already exists: test-repo" (HTTP 400/422) |
| 2.1.5 | `.\git-devops.ps1 repo create -p github` (无仓库名) | 使用当前目录名作为仓库名 |
| 2.1.6 | `.\git-devops.ps1 repo create` (无平台参数) | 输出 ERROR |

#### 2.2 删除远程仓库

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 2.2.1 | `.\git-devops.ps1 repo delete -p github -n test-repo -y` | 删除 GitHub 仓库成功 |
| 2.2.2 | `.\git-devops.ps1 repo delete -p gitee -n test-repo -y` | 删除 Gitee 仓库成功 |
| 2.2.3 | `.\git-devops.ps1 repo delete -p github -n test-repo` (无 -y) | 提示确认删除 |
| 2.2.4 | `.\git-devops.ps1 repo delete` (无平台参数) | 输出 ERROR |

---

### 场景 3：Git 模块测试

#### 3.1 Git 初始化

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 3.1.1 | `.\git-devops.ps1 git init` (全新项目) | 执行 `git init -b main`，创建 .git 目录，设置 user.name 和 user.email |
| 3.1.2 | `.\git-devops.ps1 git init` (已有 .git) | 输出 INFO "Git repo already exists, skipping"，检查并重命名 master → main |

#### 3.2 Git Remote 配置

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 3.2.1 | `.\git-devops.ps1 git remote` (无 .git) | 输出 ERROR "Git repo not initialized" |
| 3.2.2 | `.\git-devops.ps1 git remote` (正常) | 清除现有 remotes，添加 github 和 gitee remote，配置 pushall 别名 |
| 3.2.3 | `.\git-devops.ps1 git remote` (幂等) | remote 不重复添加 |

#### 3.3 Git Push

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 3.3.1 | `.\git-devops.ps1 git push` (无平台参数) | 执行 `git pushall`（推送到所有远程） |
| 3.3.2 | `.\git-devops.ps1 git push -p github` | 执行 `git push github main` |
| 3.3.3 | `.\git-devops.ps1 git push -p gitee` | 执行 `git push gitee main` |

---

### 场景 4：All 模块测试（一键初始化）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 4.1 | `.\git-devops.ps1 all init -y` | 完整流程：SSH 创建 → SSH 上传 → Repo 创建 → Git init → Git remote |
| 4.2 | `.\git-devops.ps1 all init` (无 -y) | 逐步执行，需要手动确认 |
| 4.3 | `.\git-devops.ps1 all init --dry-run` | 仅预览，不执行实际操作 |

---

### 场景 5：Clean 模块测试

#### 5.1 Clean Local（清理配置，保留 .git）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 5.1.1 | `.\git-devops.ps1 -c -y` | 删除所有 git remote，取消 pushall 别名，保留 .git 目录 |
| 5.1.2 | `.\git-devops.ps1 clean local -y` | 同上 |

#### 5.2 Clean Reset（删除 .git）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 5.2.1 | `.\git-devops.ps1 -r -y` | 删除 .git 目录（不可恢复） |
| 5.2.2 | `.\git-devops.ps1 clean reset -y` | 同上 |

#### 5.3 Clean Keys（清理 SSH 密钥）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 5.3.1 | `.\git-devops.ps1 clean keys -p github -y` | 从 GitHub 删除 SSH 密钥，删除本地密钥文件 |
| 5.3.2 | `.\git-devops.ps1 clean keys -p gitee -y` | 从 Gitee 删除 SSH 密钥，删除本地密钥文件 |
| 5.3.3 | `.\git-devops.ps1 clean keys -y` | 清理所有平台的 SSH 密钥 |

#### 5.4 Clean Repos（清理远程仓库）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 5.4.1 | `.\git-devops.ps1 clean repos -p github -y` | 删除 GitHub 远程仓库 |
| 5.4.2 | `.\git-devops.ps1 clean repos -p gitee -y` | 删除 Gitee 远程仓库 |

#### 5.5 Clean Full（完整清理）

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 5.5.1 | `.\git-devops.ps1 clean full -y` | 执行：清理远程仓库 → 清理 SSH 密钥 → 清理本地配置 → 删除 .git |
| 5.5.2 | `.\git-devops.ps1 clean all -y` | 同 clean full |

---

### 场景 6：Dry-Run 与错误处理

| 步骤 | 命令 | 预期结果 |
|------|------|----------|
| 6.1 | `.\git-devops.ps1 --dry-run ssh create -p github` | 输出 [DRY-RUN] 预览信息，不实际创建密钥 |
| 6.2 | `.\git-devops.ps1 --dry-run all init` | 预览一键初始化的所有操作 |
| 6.3 | `.\git-devops.ps1 -D ssh create -p github` | 显示 DEBUG 日志，输出详细调试信息 |
| 6.4 | `.\git-devops.ps1 -q ssh create -p github` | 仅显示 WARN 和 ERROR，隐藏 INFO 和 DEBUG |
| 6.5 | `.\git-devops.ps1 ssh unknown-op` | 输出 ERROR "Unknown SSH operation: unknown-op" |
| 6.6 | `.\git-devops.ps1 unknownmodule action` | 输出 ERROR "Unknown module: unknownmodule" |
| 6.7 | `.\git-devops.ps1` (无参数) | 显示帮助信息 |
| 6.8 | `.\git-devops.ps1 -h` | 显示帮助信息 |

---

## 四、测试执行指南

### 4.1 测试前准备

1. **检查 .env 配置**
   ```powershell
   # 验证 GitHub 账户配置
   Get-Content .env | Select-String "GITHUB_ACCOUNTS"

   # 验证 Gitee 账户配置
   Get-Content .env | Select-String "GITEE_ACCOUNTS"

   # 验证 Git 用户配置
   Get-Content .env | Select-String "GIT_USER"
   ```

2. **检查 SSH 目录**
   ```powershell
   Test-Path ~/.ssh
   Get-ChildItem ~/.ssh -Filter "id_ed25519_*"
   ```

3. **清理旧测试环境**
   ```powershell
   # 创建专用测试目录
   mkdir test-20260517
   cd test-20260517

   # 清理可能存在的旧资源
   .\git-devops.ps1 clean full -y 2>$null
   ```

### 4.2 测试执行顺序

建议按以下顺序执行测试：

1. **场景 6：错误处理和 Dry-Run**（破坏性最小）
2. **场景 1：SSH 模块**（基础设施测试）
3. **场景 2：Repo 模块**（远程仓库测试）
4. **场景 3：Git 模块**（本地配置测试）
5. **场景 4：All 模块**（集成测试）
6. **场景 5：Clean 模块**（清理操作测试）

### 4.3 测试记录模板

```
| 步骤 | 命令 | 预期结果 | 实际结果 | 通过 |
|------|------|----------|----------|------|
```

### 4.4 测试结果汇总

| 场景 | 名称 | 测试项数 | 预期通过 |
|------|------|----------|----------|
| 1 | SSH 模块 | 16 | 16 |
| 2 | Repo 模块 | 8 | 8 |
| 3 | Git 模块 | 6 | 6 |
| 4 | All 模块 | 3 | 3 |
| 5 | Clean 模块 | 9 | 9 |
| 6 | Dry-Run + 错误处理 | 8 | 8 |
| **合计** | | **50** | **50** |

---

## 五、日志级别说明

| 级别 | 颜色 | 显示条件 | 用途 |
|------|------|----------|------|
| DEBUG | Gray | `-D` 参数 | 显示详细调试信息，Token 会被脱敏 |
| INFO | Cyan | 默认 | 显示一般操作信息 |
| WARN | Yellow | 始终 | 显示警告（可忽略的问题） |
| ERROR | Red | 始终 | 显示错误（需处理的问题） |
| SUCCESS | Green | 始终 | 显示成功信息 |

---

## 六、配置文件格式

### .env 文件结构

```env
# ============================================================
# Git DevOps 配置文件
# ============================================================

# ---- GitHub 多账户配置 ----
# 格式: [{"user":"用户名","host":"SSH别名","token":"token"}]
GITHUB_ACCOUNTS=[{"user":"guanchunguang","host":"github-guanchunguang","token":"ghp_xxxx"}]

# ---- Gitee 多账户配置 ----
GITEE_ACCOUNTS=[{"user":"guanchunguang","host":"gitee-guanchunguang","token":"xxxx"}]

# ---- Git 用户配置（全局默认值）----
GIT_USER_NAME=guanchunguang
GIT_USER_EMAIL=guanchunguang@163.com
```

### SSH 密钥文件命名

- GitHub: `~/.ssh/id_ed25519_github_guanchunguang`
- Gitee: `~/.ssh/id_ed25519_gitee_guanchunguang`

---

## 七、远程仓库 URL 格式

| 平台 | Remote URL 格式 |
|------|-----------------|
| GitHub | `git@github-guanchunguang:guanchunguang/<repo>.git` |
| Gitee | `git@gitee-guanchunguang:guanchunguang/<repo>.git` |

**注意：** 使用 SSH 别名（如 `github-guanchunguang`）而非直接使用 `github.com`，这样可以在 `~/.ssh/config` 中配置不同的密钥。

---

## 八、已知问题与限制

### 8.1 已修复问题（PowerShell 版本）

- SSH push 重复密钥处理（HTTP 422/400）
- Repo create 重复处理
- Gitee SSH verify ANSI 转义码处理
- All init --dry-run 检查

### 8.2 待观察项

- Token 权限：需确认 token 有创建/删除 SSH 密钥和仓库的权限
- 网络连接：确保能访问 GitHub API 和 Gitee API
- 磁盘空间：确保有足够空间存储 SSH 密钥

### 8.3 安全注意事项

- Token 存储在 .env 文件中，不要提交到版本控制
- SSH 私钥文件权限应设置为 600（Windows 上由系统管理）
- 使用完毕后及时清理测试资源

---

## 九、测试完成标准

### 9.1 成功标准

- [ ] 所有 50 个测试步骤通过
- [ ] SSH 连接 GitHub 和 Gitee 成功
- [ ] 远程仓库创建和删除正常
- [ ] 本地 Git 配置正确
- [ ] pushall 别名工作正常
- [ ] Clean/Reset 功能正常
- [ ] 无残留测试资源

### 9.2 清理验证

```powershell
# 验证测试资源已清理
Test-Path .git  # 应为 False
git remote -v  # 应为空
Get-ChildItem ~/.ssh -Filter "id_ed25519_*" | Measure-Object  # 检查是否有多余密钥
```

---

## 十、辅助工具使用

### 10.1 ssh-pass.py 使用

```python
# 执行远程命令
python ssh-pass.py 192.168.80.132 guanchunguang 123456 "ls -la"

# 参数说明
# argv[1]: host - 远程主机地址
# argv[2]: user - 用户名
# argv[3]: password - 密码
# argv[4]: command - 要执行的命令（可选，默认 "echo OK"）
```

### 10.2 upload.py 使用

```python
# 上传文件到远程
python upload.py 192.168.80.132 guanchunguang 123456 local.txt /remote/path.txt

# 参数说明
# argv[1]: host - 远程主机地址
# argv[2]: user - 用户名
# argv[3]: password - 密码
# argv[4]: local_file - 本地文件路径
# argv[5]: remote_path - 远程目标路径
```