# Coding Skill Hub

编码实践类技能集合。每个技能是一份结构化的 Markdown 文档，供 AI Agent（Claude Code / Kiro 等）在执行任务时加载，获得特定领域的专业知识和操作流程。

## 理念

- **技能即文档**：每个技能是独立的、自包含的操作指南
- **Agent 友好**：结构化格式让 AI 能精准理解并执行
- **人类可读**：同时也是团队共享的操作手册

## 目录结构

```
skills/
└── upgrade-github-actions/   # 升级项目中的 GitHub Actions 版本
    └── SKILL.md
```

每个技能以独立目录存在，目录名即技能名，内部包含 `SKILL.md` 文件。

## 技能列表

| 技能 | 说明 |
|------|------|
| `upgrade-github-actions` | 扫描并升级 GitHub Actions 到最新主版本，通过 API 确认版本 |

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
