#!/usr/bin/env bash
# 扫描 .github/workflows/ 中的 GitHub Actions 引用,经 GitHub API 查询各 action
# 最新版本并输出对比结果。只读:不修改任何 workflow 文件。
#
# 用法: check-actions.sh [--dir <repo-root>] [--json] [-v|--verbose] [-h|--help]
# 退出码: 0 完成 / 1 用法或运行错误 / 2 前置条件不满足(无 workflows 目录或无可用查询工具)
set -euo pipefail

DIR="."
JSON=0
VERBOSE=0

usage() {
  cat >&2 <<'EOF'
用法: check-actions.sh [--dir <repo-root>] [--json] [-v|--verbose]
扫描 .github/workflows/ 下所有 GitHub Actions 引用,查询最新版本并输出对比。
  --dir <path>   项目根目录(默认当前目录)
  --json         以 JSON 输出结果(stdout 仅 JSON)
  -v, --verbose  输出诊断信息(stderr)
  -h, --help     显示本帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) [[ $# -ge 2 ]] || { echo "错误: --dir 缺少参数" >&2; exit 1; }; DIR="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "错误: 未知参数 $1" >&2; usage; exit 1 ;;
  esac
done

log() { [[ "$VERBOSE" == 1 ]] && echo "$*" >&2 || true; }

WF_DIR="$DIR/.github/workflows"
if [[ ! -d "$WF_DIR" ]]; then
  echo "错误: 未找到 $WF_DIR" >&2
  exit 2
fi

# 查询工具: 优先 gh(自带鉴权,免限流),回退 curl(+可选 GITHUB_TOKEN)
USE_GH=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH=1
  log "使用 gh api 查询(已登录)"
elif command -v curl >/dev/null 2>&1; then
  log "使用 curl 查询(未登录 gh;匿名限流 60 次/时,可设 GITHUB_TOKEN 提额)"
else
  echo "错误: 需要 gh 或 curl 之一用于查询 GitHub API" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 第一步: 扫描所有 workflow 文件,提取 uses: 引用
# 每行格式: action<TAB>ref<TAB>file(排除本地 ./ 引用与 docker:// 镜像)
: > "$TMP/refs"
found_files=0
for f in "$WF_DIR"/*.yml "$WF_DIR"/*.yaml; do
  [[ -f "$f" ]] || continue
  found_files=1
  base="$(basename "$f")"
  grep -E '^[[:space:]]*-?[[:space:]]*uses:' "$f" 2>/dev/null | while IFS= read -r line; do
    # 取 uses: 后的值,去引号与行尾注释
    ref="$(echo "$line" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//; s/[[:space:]]*$//')"
    case "$ref" in
      ./*|docker://*|"") continue ;;
    esac
    [[ "$ref" == *@* ]] || continue
    action="${ref%@*}"
    version="${ref##*@}"
    # owner/repo/path@ref(可复用 workflow)的仓库是前两段
    repo="$(echo "$action" | cut -d/ -f1-2)"
    printf '%s\t%s\t%s\t%s\n' "$action" "$version" "$base" "$repo" >> "$TMP/refs"
  done
done

if [[ "$found_files" == 0 ]]; then
  echo "错误: $WF_DIR 下没有 .yml/.yaml 文件" >&2
  exit 2
fi

if [[ ! -s "$TMP/refs" ]]; then
  echo "警告: 未发现任何远程 action 引用" >&2
  [[ "$JSON" == 1 ]] && echo "[]"
  exit 0
fi

# 第二步: 对每个唯一仓库查询最新版本
# 优先 releases/latest;404(仅打 tag 不发 release 的仓库)回退 tags 列表首项
query_latest() {
  local repo="$1" tag=""
  if [[ "$USE_GH" == 1 ]]; then
    if tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null)" && [[ -n "$tag" ]]; then
      printf '%s\t%s\n' "$tag" "release"; return 0
    fi
    if tag="$(gh api "repos/$repo/tags?per_page=1" --jq '.[0].name' 2>/dev/null)" && [[ -n "$tag" ]]; then
      printf '%s\t%s\n' "$tag" "tag"; return 0
    fi
  else
    local auth=() body
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    body="$(curl -fsS ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)" || body=""
    if [[ -z "$body" ]]; then
      body="$(curl -sS ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null)" || body=""
      if echo "$body" | grep -qi 'rate limit'; then
        echo "错误: GitHub API 匿名限流已用尽,请设置 GITHUB_TOKEN 或 gh auth login 后重试" >&2
        exit 1
      fi
      # 无 release,回退 tags
      body="$(curl -fsS ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/$repo/tags?per_page=1" 2>/dev/null)" || body=""
      tag="$(echo "$body" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
      [[ -n "$tag" ]] && { printf '%s\t%s\n' "$tag" "tag"; return 0; }
    else
      tag="$(echo "$body" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
      [[ -n "$tag" ]] && { printf '%s\t%s\n' "$tag" "release"; return 0; }
    fi
  fi
  printf '\tnone\n'
}

: > "$TMP/latest"
cut -f4 "$TMP/refs" | sort -u | while IFS= read -r repo; do
  log "查询 $repo ..."
  result="$(query_latest "$repo")"
  printf '%s\t%s\n' "$repo" "$result" >> "$TMP/latest"
done

# 主版本号提取: v4 / v4.1.0 / 4.1 -> 4;SHA 或分支名 -> 空
major_of() {
  local ref="$1"
  if [[ "$ref" =~ ^v?([0-9]+)(\..*)?$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# 第三步: 汇总每个唯一 (action, 当前版本) 组合,标注状态
# 状态: outdated(主版本落后) / up-to-date / sha-pinned / unknown(查询失败或无法比较)
: > "$TMP/rows"
sort -u -t"$(printf '\t')" -k1,2 "$TMP/refs" | cut -f1,2 | sort -u | while IFS="$(printf '\t')" read -r action version; do
  repo="$(echo "$action" | cut -d/ -f1-2)"
  latest="$(awk -F'\t' -v r="$repo" '$1==r {print $2}' "$TMP/latest" | head -1)"
  source="$(awk -F'\t' -v r="$repo" '$1==r {print $3}' "$TMP/latest" | head -1)"
  files="$(awk -F'\t' -v a="$action" -v v="$version" '$1==a && $2==v {print $3}' "$TMP/refs" | sort -u | paste -sd, -)"
  cur_major="$(major_of "$version")"
  latest_major="$(major_of "$latest")"
  if [[ "$version" =~ ^[0-9a-f]{40}$ ]]; then
    status="sha-pinned"
  elif [[ -z "$latest" ]]; then
    status="unknown"
  elif [[ -z "$cur_major" || -z "$latest_major" ]]; then
    status="unknown"
  elif [[ "$cur_major" -lt "$latest_major" ]]; then
    status="outdated"
  else
    status="up-to-date"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$action" "$version" "${latest:--}" "${source:-none}" "$status" "$files" >> "$TMP/rows"
done

# 第四步: 输出(stdout = 数据)
if [[ "$JSON" == 1 ]]; then
  # 手工构造 JSON;字段值来自 action 名/版本号/文件名,不含需转义字符
  {
    echo "["
    first=1
    while IFS="$(printf '\t')" read -r action version latest source status files; do
      [[ "$first" == 1 ]] && first=0 || echo ","
      files_json="$(echo "$files" | tr ',' '\n' | sed 's/^/"/; s/$/"/' | paste -sd, -)"
      printf '  {"action":"%s","current":"%s","latest":"%s","latest_source":"%s","status":"%s","files":[%s]}' \
        "$action" "$version" "$latest" "$source" "$status" "$files_json"
    done < "$TMP/rows"
    echo ""
    echo "]"
  }
else
  {
    printf 'ACTION\tCURRENT\tLATEST\tSTATUS\tFILES\n'
    cut -f1,2,3,5,6 "$TMP/rows"
  } | column -t -s "$(printf '\t')"
fi

outdated_count="$(awk -F'\t' '$5=="outdated"' "$TMP/rows" | wc -l | tr -d ' ')"
log "共 $(wc -l < "$TMP/rows" | tr -d ' ') 个引用,$outdated_count 个主版本落后"
exit 0
