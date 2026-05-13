# Git DevOps CLI 参数优化计划

> 创建日期: 2026-05-13
> 状态: 待执行

---

## 一、背景

当前参数设计存在以下问题：
- 命名风格不统一（PowerShell 用 PascalCase，Bash 用 kebab-case）
- 短选项与长选项不一致
- 部分参数过长（如 `-Platform`）
- 冗余参数（如 `-Module` `-Action` 未实际使用）

## 二、目标

统一双平台参数风格，简化命令，提升易用性。

## 三、参数对照表

### 全局控制类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-y` | `--yes` | 开关 | 自动确认 |
| `-h` | `--help` | 开关 | 显示帮助 |
| `-D` | `--debug` | 开关 | 调试模式 |
| `-q` | `--quiet` | 开关 | 安静模式 |
| (无) | `--dry-run` | 开关 | 预览模式 |

### 平台/操作类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-p` | `--platform` | 值 | 平台：github/gitee |
| `-n` | `--name` | 值 | 仓库名称 |
| `-t` | `--title` | 值 | SSH 密钥标题 |
| `-f` | `--force` | 开关 | 强制覆盖 |

### 危险操作类

| 短选项 | 长选项 | 类型 | 说明 |
|--------|--------|------|------|
| `-c` | `--clean` | 开关 | 清理（保留 .git） |
| `-r` | `--reset` | 开关 | 重置（删除 .git） |

### 子命令类

| 短选项 | 长选项 | 用于 | 说明 |
|--------|--------|------|------|
| `-d` | `--delete` | repo | 删除仓库 |

## 四、子命令

| 子命令 | 说明 |
|--------|------|
| `ssh create` | 创建 SSH 密钥 |
| `ssh push` | 推送公钥到平台 |
| `ssh verify` | 验证 SSH 连接 |
| `ssh remove` | 删除平台公钥 |
| `repo create` | 创建远程仓库 |
| `repo delete` | 删除远程仓库 |
| `git init` | 初始化本地仓库 |
| `git remote` | 配置远程仓库 |
| `git push` | 推送到远程 |
| `all init` | 一键初始化 |

## 五、命令示例

### PowerShell (Windows)

```powershell
# SSH 管理
.\git-devops.ps1 ssh create -p github              # 创建密钥
.\git-devops.ps1 ssh push -p github               # 推送公钥
.\git-devops.ps1 ssh verify -p github             # 验证连接
.\git-devops.ps1 ssh remove -p github -y          # 删除公钥

# 仓库管理
.\git-devops.ps1 repo create -p github -n myrepo  # 创建仓库
.\git-devops.ps1 repo delete -p github -n myrepo -y  # 删除仓库
.\git-devops.ps1 repo create -p gitee -n myrepo -f   # 强制创建

# Git 操作
.\git-devops.ps1 git init                          # 初始化
.\git-devops.ps1 git remote -p github             # 配置远程
.\git-devops.ps1 git push -p github               # 推送

# 一键初始化
.\git-devops.ps1 all init -p github                # 单平台
.\git-devops.ps1 all init -p github -p gitee      # 双平台

# 维护操作
.\git-devops.ps1 -c -y                            # 清理
.\git-devops.ps1 -r -y                            # 重置
.\git-devops.ps1 --dry-run -c -y                  # 预览清理
.\git-devops.ps1 --dry-run all init -p github    # 预览初始化

# 辅助选项
.\git-devops.ps1 -h                               # 帮助
.\git-devops.ps1 -D                               # 调试模式
.\git-devops.ps1 -q                               # 安静模式
```

### Bash (Linux/macOS)

```bash
./git-devops.sh ssh create -p github              # 创建密钥
./git-devops.sh ssh push -p github               # 推送公钥
./git-devops.sh ssh verify -p github             # 验证连接
./git-devops.sh ssh remove -p github -y          # 删除公钥

./git-devops.sh repo create -p github -n myrepo # 创建仓库
./git-devops.sh repo delete -p github -n myrepo -y  # 删除仓库
./git-devops.sh repo create -p gitee -n myrepo -f   # 强制创建

./git-devops.sh git init                          # 初始化
./git-devops.sh git remote -p github             # 配置远程
./git-devops.sh git push -p github               # 推送

./git-devops.sh all init -p github                # 单平台
./git-devops.sh all init -p github -p gitee      # 双平台

./git-devops.sh -c -y                            # 清理
./git-devops.sh -r -y                            # 重置
./git-devops.sh --dry-run -c -y                  # 预览清理
./git-devops.sh --dry-run all init -p github    # 预览初始化

./git-devops.sh -h                               # 帮助
./git-devops.sh -D                               # 调试模式
./git-devops.sh -q                               # 安静模式
```

## 六、涉及文件

| 文件 | 修改内容 |
|------|----------|
| `git-devops.ps1` | param 块重写、Show-Help 更新、移除 verbose 参数 |
| `git-devops.sh` | 参数解析重写、show_help 更新、移除 verbose 参数 |
| `README.md` | 命令示例更新 |

## 七、执行步骤

### Step 1: git-devops.ps1 重构
- 重写 param 块
- 更新 Show-Help 函数
- 确保默认输出详细（不需要 verbose 参数）
- 测试验证

### Step 2: git-devops.sh 重构
- 重写参数解析逻辑
- 更新 show_help 函数
- 确保默认输出详细
- 测试验证

### Step 3: README.md 更新
- 更新所有命令示例
- 更新参数说明表格

### Step 4: 完整测试
- Windows PowerShell 测试
- Linux Bash 测试
- 验证向后兼容性

## 八、变更记录

| 日期 | 描述 |
|------|------|
| 2026-05-13 | 创建计划 |
