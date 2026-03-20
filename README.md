# VibeCoding Bootstrap

一个面向新手的 vibecoding 环境初始化 skill，用来帮助用户在 Windows 或 macOS 上补齐最常用的开发依赖、配置基础 MCP，并检查本地 Codex skill 环境是否可用。

## 适用场景

- 第一次接触 vibecoding，不知道应该先装哪些工具
- 已经装过一部分环境，但本地依赖比较乱，想统一检查
- 想给 Codex 补齐基础 MCP 配置
- 想确认本地 `~/.codex/skills` 和常用 skill 是否正常
- 想把“环境检查、安装、验证”流程标准化

## 支持平台

- Windows
- macOS

## 这个 skill 会做什么

- 检查基础依赖是否存在：`git`、`node`、`npm`、`npx`、`corepack`、`pnpm`、`python/python3`、`uv`、`uvx`
- 检查 `~/.codex/config.toml` 是否存在
- 检查常用 MCP 是否已配置：`context7`、`fetch`、`shadcn`
- 检查常用 skill 是否已存在：`find-skills`、`playwright`、`screenshot`、`netlify-deploy`、`imagegen`、`openai-docs`
- 安装缺失的基础依赖
- 在写入 MCP 配置前自动备份原始 `config.toml`
- 最后做一轮验证，确认当前机器是否达到“可开始 vibecoding”的最低要求

## 不会做什么

- 不会自动写入 API Key 或其他敏感信息
- 不会默认安装一大堆项目无关的 MCP
- 不会强行覆盖你已经存在的 MCP 配置块
- 不会从不可信来源下载随机脚本

## 目录说明

```text
.
├─ README.md
├─ SKILL.md
├─ agents/
│  └─ openai.yaml
├─ references/
│  ├─ packages.md
│  └─ troubleshooting.md
└─ scripts/
   ├─ check-env.ps1
   ├─ install-base.ps1
   ├─ configure-mcp.ps1
   ├─ install-skills.ps1
   ├─ verify-setup.ps1
   ├─ check-env.sh
   ├─ install-base.sh
   ├─ configure-mcp.sh
   ├─ install-skills.sh
   └─ verify-setup.sh
```

## 推荐使用流程

1. 先检查环境，不要一上来就安装。
2. 先安装基础依赖，再配置 MCP。
3. skill 安装和 MCP 配置分开执行，方便排错。
4. 最后跑验证脚本，看机器是否真正可用。

## Windows 使用方法

在 PowerShell 中进入 skill 根目录后，按顺序执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-base.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\scripts\install-base.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\configure-mcp.ps1 -WhatIf
powershell -ExecutionPolicy Bypass -File .\scripts\configure-mcp.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-skills.ps1 -InstallSelf -WhatIf
powershell -ExecutionPolicy Bypass -File .\scripts\install-skills.ps1 -InstallSelf
powershell -ExecutionPolicy Bypass -File .\scripts\verify-setup.ps1 -Deep
```

说明：`install-skills.ps1` 在真正完成安装或更新后，会自动做一次轻量检查；最后这条 `verify-setup.ps1 -Deep` 仍然建议保留，作为完整流程的最终确认。

### Windows 脚本说明

- `check-env.ps1`
  检查当前机器是否已经具备基础依赖、MCP 配置和常用 skill。
- `install-base.ps1`
  使用 `winget` 安装缺失的基础工具，并尝试启用 `corepack` 与 `pnpm`。
- `configure-mcp.ps1`
  为 `~/.codex/config.toml` 补齐常用 MCP 配置，并自动备份原文件。
- `install-skills.ps1`
  检查常用 skill 是否存在，也可以把当前 skill 安装到 `~/.codex/skills`。安装或更新完成后会自动跑一次轻量检查；如果你只想安装不检查，可以加 `-SkipVerify`，想做更深入的检查可以加 `-DeepVerify`。
- `verify-setup.ps1`
  最终验证当前环境是否达到可用状态，`-Deep` 会做更深入的运行时检查。

## macOS 使用方法

在终端中进入 skill 根目录后，按顺序执行：

```bash
bash ./scripts/check-env.sh
bash ./scripts/install-base.sh --dry-run
bash ./scripts/install-base.sh
bash ./scripts/configure-mcp.sh --dry-run
bash ./scripts/configure-mcp.sh
bash ./scripts/install-skills.sh --install-self --dry-run
bash ./scripts/install-skills.sh --install-self
bash ./scripts/verify-setup.sh --deep
```

说明：`install-skills.sh` 在真正完成安装或更新后，会自动做一次轻量检查；最后这条 `verify-setup.sh --deep` 仍然建议保留，作为完整流程的最终确认。

### macOS 脚本说明

- `check-env.sh`
  检查当前机器上的 Homebrew、基础依赖、MCP 配置和常用 skill。
- `install-base.sh`
  使用 `brew` 安装缺失的基础工具，并尝试启用 `corepack` 与 `pnpm`。
- `configure-mcp.sh`
  为 `~/.codex/config.toml` 补齐常用 MCP 配置，并自动备份原文件。
- `install-skills.sh`
  检查常用 skill 是否存在，也可以把当前 skill 安装到 `~/.codex/skills`。安装或更新完成后会自动跑一次轻量检查；如果你只想安装不检查，可以加 `--skip-verify`，想做更深入的检查可以加 `--deep-verify`。
- `verify-setup.sh`
  最终验证当前环境是否达到可用状态，`--deep` 会做更深入的运行时检查。

## 安装到 Codex skill 目录

如果你想把这个 skill 正式放到本机 Codex 的 skill 目录，一般目标路径是：

- Windows: `C:\Users\<你的用户名>\.codex\skills\vibecoding-bootstrap`
- macOS: `~/.codex/skills/vibecoding-bootstrap`

如果已经在 skill 根目录中，可以直接用脚本安装：

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-skills.ps1 -InstallSelf
```

macOS:

```bash
bash ./scripts/install-skills.sh --install-self
```

## 默认检查的基础工具

- Git
- Node.js
- npm
- npx
- corepack
- pnpm
- Python
- uv
- uvx

## 默认配置的 MCP

- `context7`
- `fetch`
- `shadcn`

这三个 MCP 是一个比较保守的入门组合，够新手先把文档查询、基础抓取和部分前端组件工作流跑起来，不会一开始就把配置搞得很重。

## 默认审计的 skill

- `find-skills`
- `playwright`
- `screenshot`
- `netlify-deploy`
- `imagegen`
- `openai-docs`

## 常见问题

### 1. Windows 上没有 `winget`

说明系统缺少或没有启用 App Installer。先从 Microsoft Store 安装或更新 App Installer，再重新打开 PowerShell 运行脚本。

### 2. macOS 上没有 `brew`

先从官方站点安装 Homebrew：[brew.sh](https://brew.sh/)。

### 3. 工具明明装了，但终端里还是找不到

通常是 PATH 没刷新。关闭当前终端，重新打开后再运行验证脚本。

### 4. 不想直接改配置，能不能先看会改什么

可以。Windows 用 `-WhatIf`，macOS 用 `--dry-run`。

### 5. 这个 skill 会不会覆盖我现有的 MCP

不会默认覆盖。它只会补充缺失的配置块；如果目标配置已经存在，会跳过。

## 参考文档

- [SKILL.md](./SKILL.md)
- [packages.md](./references/packages.md)
- [troubleshooting.md](./references/troubleshooting.md)

## 说明

这份 `README.md` 是给人看的中文说明文档。

`SKILL.md` 是给 Codex / agent 使用的技能说明，两者用途不同，不要混用。
