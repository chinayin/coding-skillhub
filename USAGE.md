# 使用指南

## 什么是技能

技能是一份 Markdown 文件（`SKILL.md`），包含：

- YAML frontmatter（name、description、version、tags）
- 操作流程和步骤
- 完整可用的示例
- 注意事项和常见问题

AI Agent 加载后即可按照文档中的流程执行任务。

## 安装技能

使用 `npx skills` 安装到系统级目录，安装后所有项目中均可使用：

```bash
# 安装仓库下所有技能
npx skills add chinayin/coding-skillhub -g

# 安装指定技能
npx skills add chinayin/coding-skillhub -g -s upgrade-github-actions
```

安装后技能会放入用户级目录（Kiro: `~/.kiro/skills/`，Claude Code: `~/.claude/skills/`），所有子项目自动生效。

## 在 Kiro 中使用

安装后技能会出现在 `.kiro/skills/` 中，Kiro 自动发现并在相关场景中加载。

也可以在对话中通过 `#` 引用已安装的技能，让 Kiro 按文档操作。

## 在 Claude Code 中使用

安装后技能会出现在 `~/.claude/skills/` 中，Claude Code 自动发现并在相关场景中加载。

也可以在对话中用 `@` 引用技能文件，让 Claude Code 按流程执行。


