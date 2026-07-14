# Coding Skill Hub

编码实践类技能集合。每个技能是一份结构化的 Markdown 文档，供 AI Agent（Claude Code / Kiro 等）在执行任务时加载，获得特定领域的专业知识和操作流程。

## 理念

- **技能即文档**：每个技能是独立的、自包含的操作指南
- **Agent 友好**：结构化格式让 AI 能精准理解并执行
- **人类可读**：同时也是团队共享的操作手册

## 目录结构

```
skills/
├── upgrade-github-actions/   # 升级项目中的 GitHub Actions 版本
│   └── SKILL.md
└── gen-ssh-key/              # 按团队规范生成 SSH 密钥
    ├── SKILL.md
    ├── scripts/
    │   └── gen-ssh-key.sh    # 核心脚本
    ├── evals/
    │   └── evals.json        # Agent 行为级回归测试用例
    ├── test.sh               # 自测
    └── .env.example          # 配置样例
```

每个技能以独立目录存在，目录名即技能名，内部至少包含 `SKILL.md` 文件；带脚本的技能同目录附带可执行脚本（位于 `scripts/`）、自测脚本、配置样例，部分技能另附 `evals/evals.json` 回归测试用例。

## 技能列表

| 技能 | 说明 |
|------|------|
| `upgrade-github-actions` | 扫描并升级 GitHub Actions 到最新主版本，通过 API 确认版本 |
| `gen-ssh-key` | 按团队规范生成 SSH 密钥（Ed25519 默认 / RSA 4096 兜底，puttygen 优先降级 ssh-keygen） |

## 使用

详见 [USAGE.md](./USAGE.md)。

快速开始：

```bash
# 安装所有技能
npx skills add chinayin/coding-skillhub -g

# 或安装指定技能
npx skills add chinayin/coding-skillhub -g -s upgrade-github-actions
```

## 贡献

1. 在 `skills/` 下新建以技能名命名的目录
2. 目录内创建 `SKILL.md`，包含 frontmatter 元数据和完整操作内容
3. 提交 PR
