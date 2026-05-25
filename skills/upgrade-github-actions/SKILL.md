---
name: upgrade-github-actions
description: 扫描并升级项目中所有 GitHub Actions 到最新主版本，通过 GitHub API 确认版本
version: 1.0.0
tags: [github-actions, ci, upgrade, workflow, dependabot]
---

# Upgrade GitHub Actions

当用户要求升级 GitHub Actions 时，按以下流程操作：

## 流程

1. **扫描工作流文件**：查找 `.github/workflows/` 下所有 `.yml`/`.yaml` 文件
2. **提取当前 action 版本**：识别所有 `uses:` 引用的 action 及其版本标签（包括第三方 action）
3. **查询最新版本**：使用 GitHub API 确认每个 action 的最新版本（见下方"版本查询方法"）
4. **对比差异**：列出需要升级的 action，格式如下表：

| 文件 | Action | 当前版本 | 最新版本 | 备注 |
|------|--------|---------|---------|------|

5. **确认后批量更新**：用户确认后，修改所有 workflow 文件
6. **验证**：检查 workflow 文件语法是否正确（缩进、引号等）
7. **提交并推送**：commit message 格式为 `chore: bump github actions (<action 列表简述>)`

## 版本查询方法（关键）

**必须使用 GitHub API，禁止依赖 web 搜索判断版本。** Web 搜索结果存在严重缓存问题，会返回过时数据导致误判。

### 唯一权威方式：fetch GitHub Releases API

```
https://api.github.com/repos/{owner}/{repo}/releases/latest
```

从返回 JSON 中提取 `tag_name` 字段即为最新版本。

示例：查询 `docker/login-action` 最新版本：
- fetch `https://api.github.com/repos/docker/login-action/releases/latest`
- 读取响应中 `"tag_name": "v4.2.0"` → 主版本为 `@v4`

### 执行时逐个 action fetch API，不可跳过，不可用搜索替代。

## 常见 Docker 相关 Actions 版本参考

> **最后通过 API 验证时间：2026 年 5 月**

- `actions/checkout@v6`
- `docker/setup-qemu-action@v4`
- `docker/setup-buildx-action@v4`
- `docker/login-action@v4`
- `docker/bake-action@v7`
- `docker/build-push-action@v7`
- `peter-evans/dockerhub-description@v5`

> 如版本与上述不一致，说明需要升级。执行升级时必须通过 API 确认是否有更新的主版本，不可仅凭此表。

## 注意事项

- 使用主版本标签（如 `@v4`）而非完整版本号（如 `@v4.1.0`），这样会自动获得 minor/patch 更新
- 升级主版本前，快速确认是否有 breaking changes（查看 release notes 的 body 字段）
- Docker 系列 action（docker/*）通常会同步发布新主版本，如果其中一个升了大版本，其他的大概率也有对应升级
- 如果项目配置了 dependabot / renovate 且已有相关 PR，升级后可以关闭对应 PR
- 同一仓库下所有 workflow 文件应保持一致的 action 版本
- 升级后建议观察一次 CI 运行结果，确认没有 breaking changes 影响

## 安全建议

- 升级时注意检查 action 的权限变更（特别是 `permissions` 相关）
- 关注 GitHub 官方安全公告，及时升级有已知漏洞的 action 版本
