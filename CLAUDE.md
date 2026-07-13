# coding-skillhub 仓库规范

面向 AI Agent(Claude Code / Kiro 等)分发的**编码实践技能集合**。每个技能是一份自包含的操作指南,供 Agent 在执行任务时加载。本文件同时是**技能编写**与**shell 脚本编写**的规范性指导,约束在本仓内新增或修改内容时必须遵守的规则。

## 全项目硬规范

- **禁止任何 emoji / 装饰性符号**:代码、脚本运行时输出、SKILL.md、README、注释、提交信息、文档全程不得出现 emoji 或对勾/叉/警告标志等装饰性 Unicode 符号。状态一律用纯文本表达:错误用 `错误:`、警告用 `警告:`、测试结果用 `[PASS]`/`[FAIL]`。

## 一、技能编写规范

### 目录结构

- 每个技能位于 `skills/<name>/`,目录名即技能名(kebab-case)。
- 至少包含 `SKILL.md`。带脚本的技能同目录附带:可执行脚本、`test.sh` 自测、`.env.example`(如需配置)。
- 本地文件不入库:`.env`(实际配置)、`docs/`(设计/计划/交接文档)已在 `.gitignore` 中忽略,不要提交。

### SKILL.md

- **frontmatter 必备字段**:`name`、`description`、`version`(语义化版本)、`tags`(数组)。
  - 说明:`version` / `tags` 是本仓分发工具 **`npx skills`(社区)** 使用的字段,**不是 Claude Code 官方 SKILL frontmatter**(官方只认 `name`/`description`/`paths`/`allowed-tools` 等)。本仓走 `npx skills` 分发,故保留这两个字段——**不要按官方规范当作多余字段删掉**。(对比:团队 `gox-code-rules` 插件走 Claude Code 插件体系,其 skill 就不带 `version`/`tags`,版本在 `plugin.json`。)
- `name` 必须与目录名一致。
- `description` 决定 Agent 何时触发本技能,要写清**做什么** + **典型触发语句**(用引号列举用户可能的说法)。
- **语言:SKILL.md 正文与 frontmatter 一律用英文**(面向公开分发,统一风格、最大化受众与触发稳定性)。这是唯一例外于个人「中文优先」偏好的地方,仅限 `SKILL.md`。
- `version` 必须与技能脚本内部版本号(脚本的 `VERSION=` 与 `--version` 输出)保持一致。

## 二、shell / CLI 脚本编写规范

> 本节与团队 `gox-code-rules:shell` 技能**同源**;若启用了该插件,以插件为准。此处内联是为了让本仓对未启用插件的协作者也**开箱即用**(自包含)。

### 脚本基础

- 每个脚本以 `#!/usr/bin/env bash` + `set -euo pipefail` 开头。
- 变量展开一律加引号(`"$var"`、`"${arr[@]}"`);`[ ]` / `[[ ]]` 用法保持一致。
- 涉及密钥/凭据的产物按最小权限处理(如私钥 `chmod 600`)。
- 破坏性操作(覆盖、删除)默认拒绝,提供显式 `--force` 等开关。
- 脚本注释用中文(团队/个人偏好),但**用户可见的帮助文本以 SKILL.md 为准**。
- 每个带脚本的技能必须有 `test.sh`:写入临时目录、跑完清理、以 `PASS/FAIL` 汇总并用退出码反映结果。**改脚本必须同步改测试并跑绿**。

### CLI 约定(参照 cargo / git / gh / docker / kubectl 与 clig.dev)

- **stdout = 数据,stderr = 消息**:可被程序消费的产物(公钥、JSON 等)走 stdout;错误、警告、进度、诊断走 stderr。这样 `... --json | jq`、`... | pbcopy` 才干净。
- **状态用最小文字前缀**:`错误:` / `警告:`(对齐 cargo 的 `error:`/`warning:`、git 的前缀);测试器用 `[PASS]` / `[FAIL]`(对齐 Go test / TAP `ok`/`not ok`)。
- **默认不打日志级别标签**:非 verbose 模式不要输出 `ERR/WARN/INFO/DEBUG` 之类标签或多余上下文(clig.dev)。啰嗦诊断放到 `-v/--verbose`,且只打 stderr。
- **不使用颜色**:技能由 Agent 调用,颜色无意义,一律纯文本(也就无需处理 `NO_COLOR`/TTY 检测)。
- **禁 emoji / 装饰符号**(见「全项目硬规范」)。
- **标准开关**:机器可读输出用 `--json`;可预览用 `--dry-run`;`-v/--verbose` 开诊断;`--` 结束选项解析;`--version`、`-h/--help`。Flag 用 kebab-case,bool flag 不带值,高频项才配短选项。
- **退出码**:有明确语义并在 SKILL.md 记录(如 `0` 成功 / `1` 用法或运行错误 / `2` 前置条件不满足)。

## 三、提交前检查

1. `bash skills/<name>/test.sh` 全绿。
2. frontmatter `version` 与脚本版本号一致。
3. 新增/改名技能后同步更新 `README.md` 的技能列表与目录结构、`USAGE.md`(如涉及)。
4. git 提交信息用中文(约定式前缀 `feat:`/`fix:`/`docs:`/`chore:` 保留英文)。
