# AGENTS Workspace Notes

Read `WORKSPACE_CONTEXT.md` before starting substantial work.

<!-- BEGIN NON_CLAUDE_L2_MIRROR -->
## Workspace L2 Mirror (Non-Claude Agents)

- 此段由 `AI_Workspace/docs/governance/NON_CLAUDE_L2_MIRROR.md` 同步生成；修改 workspace 级规则时先改权威源，再运行 `./ops/sync_non_claude_agent_docs.sh` 与 `./ops/check_non_claude_agent_docs_sync.sh`。
- Claude 的完整 L2 权威仍是 `AI_Workspace/CLAUDE.md`；Codex/Gemini 不会从父目录自动继承 L2，所以这里只保留子项目内必须立即可见的最小规则。

### Work Scope

- 从具体项目目录启动任务；项目实现工作不得直接在 `AI_Workspace/` 根目录展开。
- 实施前先判断目标项目；跨项目改动只在用户明确要求、或任务本身属于 workspace 级治理/文档/共用工具时执行。
- 项目专属任务只写该项目目录；workspace 级治理、文档、共用脚本才写 `AI_Workspace/docs/`、`AI_Workspace/ops/` 等共享目录。
- 优先复用已注册跨项目工具，不重复造轮子。工具索引：`AI_Workspace/docs/references/Cross_Project_Tools_Reference.md`；发现顺序：`which` -> 同级项目 -> `openclaw/skills/` -> `workspace/tools/`。

### Documentation Sources

- 写 task log 前必须读 `AI_Workspace/docs/governance/TASK_LOG_SPEC.md`，不得凭记忆写格式。
- 修改 workspace 级文档约束时，先改权威源或共享 spec，不得只改某项目 `AGENTS.md` / `CLAUDE.md` 局部副本。
- `TASK_LOG_SPEC.md`、`NON_CLAUDE_L2_MIRROR.md`、项目 `NON_CLAUDE_DOC_CONSTRAINTS`、`GEMINI.md` symlink 的同步/检查统一走 `ops/sync_non_claude_agent_docs.sh` 与 `ops/check_non_claude_agent_docs_sync.sh`。
- 日常入口 `./pull_all.sh` 会在 git 拉取后执行上述 sync/check，覆盖 non-git 项目。

### Agent EC / Fabric Minimum Contract

- `Agent Operations Fabric`（简称 `Fabric`）= L2 Sync Plane + L3 Agent EC；`Agent EC` = L3 单 session 工作契约；`Harness` = L3.1 Runtime Harness。
- **FABRIC_TERMINOLOGY_FREEZE（2026-05-12 至 2026-06-12）**：冻结期内不引入 Mesh / Workbench / Agent EC 升伞等新命名。
- Agent EC 组件边界：直接决定 agent 执行、提醒、门禁、同步、审计行为的子 agent、hooks、workspace wrappers、`ops/*.sh` / `ops/*.py` / 指定 runtime 脚本。
- 启动时必须检查 `~/AI_Workspace/.agent_ec/pending_sync`；非空则读全文并决定先补漏还是继续新任务，不能只看 stderr 提示。
- **MAC_MINI_GATEWAY_MODE（MANDATORY，2026-05-12）**：若 `~/AI_Workspace/.machine_hint` 显示 `MACHINE=Mac-mini`，默认只写 `agent-inbox`；canonical 写入必须有用户明确授权并说明 `AIWS_CANONICAL_WRITE_MODE=1` 或手工 commit 边界。

### Closeout Triggers

- **落盘** = L2 publish：repo 源变更必须写入/readback、commit、push 当前 repo durable remote，并回读 ahead/behind；只做 local commit 是部分完成，必须 FAIL_LOUD。
- **收尾 / Fabric 收尾 / agent EC 收尾 / session 收尾** = L3/Fabric 契约执行；若有 repo 源变更，也必须先完成上面的 L2 publish。
- Stop hook / wrapper autosync 只是兜底，不能替代用户明确说“落盘”后的显式 push/readback。

### Closeout Checklist (Read Details On Demand)

- Changelog scope：单项目写项目日志目录；跨项目/workspace 级写 `AI_Workspace/docs/logs/`。
- DOC_SCOPE：评估 Spec / 业务持续追加文档、OBS&iCloud、HANDOFF、memory、Runbook/README/Engineering Contract、治理活文档，并对相关子项逐项说明更新或跳过理由。
- **TASK_OBJECT_SPEC_SYNC（MANDATORY，2026-04-29，全 repo）**：有明确任务对象且存在权威 Spec / Contract / Runbook / README / 持续追加文档时，收尾必须识别完整文档集、打开 grep/read 当前事实与待办，并更新或说明跳过理由。
- **TOPIC_CANONICAL_SINK（MANDATORY，2026-05-04，全 repo）**：同一稳定主题落 Markdown / OBS / iCloud 前，先搜索既有 canonical sink，判断归并或拆分，并在 final / task log 说明关键词、范围和理由。
- **ARTICLE_DISCUSSION_LOG（MANDATORY，2026-05-05，全 repo）**：实质讨论外部文章/帖子/推文/截图/链接且有复盘价值时，收尾落到正确日志或 canonical sink，记录作者、标题/主题、链接、来源类型、日期、摘要、关键数字/机制、agent 判断、用户决定。
- **INFRASTRUCTURE_SCOPE_GREP（MANDATORY，2026-05-03，全 repo）**：修改/退役/切换 VPN、proxy、端口、host、`.env` 代理变量、shell/CLI、macOS 配置、LaunchAgent、浏览器/CDP、MCP 等基础设施时，用 `AI_Workspace/ops/grep_workspace_reference.sh '<pattern>'` 扫旧值/新值/路径并分类命中。
- **PROXY_NETWORK_SPEC_SYNC（MANDATORY，2026-06-02，proxy/VPN 专项）**：改 Shadowrocket / Stash / VPN / proxy / DIRECT / `vahn.cc` / 相关端口和 macOS proxy 工具时，`workspace/ops/check_proxy_network_spec_sync.sh` 必须通过；若不改 canonical spec，task log 必须写 `Proxy Network Spec Sync: skipped - <reason>`。
- 子 agent 经验回写：命中业务范围或 capability-level 能力范围（如前端 UI / 静态页 / 视觉 QA），且产生 5 类可复用经验之一时，写入合适业务 agent 或 capability sink；禁止强塞进无关 agent。
- 子 agent 起手必检（MANDATORY，2026-05-25，与"经验回写"对偶）：复杂多步任务起手前 grep `~/AI_Workspace/agents/*.md` 找候选；命中 + SOP 够用即委派，不够也委派让 agent 报告盲点再二次委派，禁止主线程绕开。完整规则见 `agents/frontend-ui.md § 子 agent 当场用，不是事后补`。
- Runtime 自动分派 hook 边界（2026-05-25）：默认不做“用户一发任务即强制阻断并自动委派子 agent”的重型 hook。优先用收尾/commit freshness gate + 轻量 preflight/router 提醒；只有部署、nginx、Cloudflare DNS/Tunnel、安全 header、计费/账号变更等生产高风险动作，且有反复绕开子 agent 的事故证据时，才考虑硬 gate。
- 完整细则入口：`AI_Workspace/CLAUDE.md § Agent EC`、`AI_Workspace/ops/inject_session_reminders.sh`、`AI_Workspace/docs/governance/Governance_Architecture.md`。

### HANDOFF

- 多步复杂任务未完成时，更新 `workspace/docs/handoff/handoff_items.yaml` 的 `active` / `waiting` item，再运行 `python3 workspace/tools/handoff_manager.py render` 生成 `~/AI_Workspace/HANDOFF.md`。
- 任务完成 / 更正 / 废弃 / 被新方案取代时，把对应 item 改为 `closed` / `abandoned` / `superseded`，补 `close_reason` / `archive_path`，再运行 `python3 workspace/tools/handoff_manager.py check`。
- 禁止手改 generated `HANDOFF.md`。

### Session Output

- 结束时必须明确汇报：改了哪些路径、跑了哪些验证、是否还有需要用户决定的事项。
- 讨论历史 AI 对话话题（创业/投资/育儿/心理/英语等）前，优先 grep 本 repo `docs/references/ai_dialogue/` 或全局 `workspace/tools/ai_dialogue_search.sh`。
<!-- END NON_CLAUDE_L2_MIRROR -->

## Unified Release Governance (All Agents)

The following rules are mandatory and must be identical across agent entry points.

1. 唯一真相源：GitHub `main`（`https://github.com/vahnxu/doubao-asr`）。
2. 唯一发布链路：本地开发 -> push GitHub `main` -> GitHub Actions CI/CD。
3. SSH 角色边界：仅用于诊断/应急；永久修复必须 commit 并 push 回 GitHub `main`。
4. 禁止第二发布通道：
   - 禁止绕过 GitHub（本地直推未受控分支再回灌 `main` 的发布行为均禁止）。
5. 运行态数据与代码发布解耦：
   - `memory/curated/`：人工长期记忆，纳入 GitHub 与发布白名单。
   - `memory/runtime/`：运行态状态，排除出 Git 同步与发布覆盖。
   - `MEMORY.md`：纳入 GitHub 与发布同步。

## New Agent Onboarding

- When introducing a new agent or new machine, use:
  - `docs/workspace/NEW_AGENT_ONBOARDING_PROMPT.md`
- Mandatory baseline command after onboarding:
  - `./ops/check_release_governance_consistency.sh`

### Onboarding Hard Gate (Production)

新 Agent 在执行任何生产相关任务前，必须完成以下 gate：
1. 阅读 `docs/workspace/NEW_AGENT_ONBOARDING_PROMPT.md`。
2. 运行 `./ops/check_release_governance_consistency.sh`。
3. 输出 PASS 证据（`== RESULT: PASS (all checks passed) ==`）。
4. 建议直接执行统一 gate：`./ops/enforce_agent_onboarding_gate.sh`。

未通过不得执行生产变更任务。

## Git Sync Contract (All Agents)

- Single source of truth: `https://github.com/vahnxu/doubao-asr` branch `main`.
- Session start sync (recommended first command): `./ops/git_sync_guard.sh session-start`
- If remote is ahead after sync guard warning, then run: `git pull --rebase origin main`
- On every new machine/new clone, run `./ops/install_git_hooks.sh --apply` once to enable local pre-commit + pre-push gates.
- Pre-push hook: 直推 `main` 时本地强制跑 `check_release_governance_consistency.sh` + behind-remote 检查，不通过则 push 被阻止；推 agent 分支时 behind 检查为警告不阻止。
- After each completed task: run `git add <changed-files> && git commit -m "<agent>: <summary>" && git push origin main` (unless user explicitly asks not to push).
- Do not use `git add -A` or `git add .`; stage files explicitly.
- Do not `git add` temporary or draft files (prompts, scratch notes, verification dumps) that are not part of the deliverable. Leftover staged files cause `working tree dirty` state that blocks other collaborators' sync guard fast-forward. If you must stage exploratory files, commit or unstage (`git reset HEAD <file>`) them before ending your session.
- Definition of done for code/config changes: push succeeds and required CI checks succeed.

### Local Sync Guard (Pull Direction Only)

四层防护：`session-start` → `ttl-check` → `pre-commit-check` → `pre-push behind-check`。
详细说明见 `docs/workspace/README.md` → "Consistency Verification" 节。

### Agent Branch Auto-Merge

AI Agent 推送到 feature branch（`claude/*`、`codex/*`、`antigravity/*`）后：
1. GitHub Actions 自动创建 PR（`agent/xxx → main`）。
2. Governance Consistency Check 自动在 PR 上运行。
3. CI 通过 → 自动 squash merge 到 main。
4. CI 失败 → PR 停住，等待用户排查。
5. Merge 后 feature branch 自动删除。

Agent 无需手动创建 PR 或合并分支。

## Auto Sync (Optional but Recommended)

- 入口：`ops/git_autosync.sh start`（默认 20s 间隔，仅 tracked 文件）
- Runtime override is emergency-only. Keep double-confirmation, leave audit evidence, and backfill permanent fix to GitHub `main`.
- 状态/停止：`ops/git_autosync.sh status` / `ops/git_autosync.sh stop`

## Sync Exceptions (Single Registry)

权威总表：`docs/workspace/governance/SYNC_EXCEPTIONS.md`

## Document Filing Rules

- 日志 → `docs/workspace/logs/`；报告 → `reports/`；prompt → `prompts/`；治理 → `governance/`
- 禁止在 `docs/workspace/` 根目录新建 .md 文件。

## Task Execution Log (Mandatory)

Every non-trivial task must include an execution log in the same commit.

### Log Locations & Naming
- Preferred default (most stable for commits): `docs/workspace/logs/YYYYMMDD_<Summary_PascalCase>.md`
- Skill development alternative: `skills/<skill>/session_logs/YYYYMMDD_<Summary_PascalCase>.md` (some skills may ignore this path via `.gitignore`; use `git add -f` only when intended)
- All AI-created .md files must use `YYYYMMDD` date prefix. Body dates use `YYYY-MM-DD`.
- Model names in body use official product names (e.g. `Claude Opus 4.6`); executor field uses model-id (e.g. `claude-opus-4-6`).
- Full spec and template: `docs/workspace/governance/TASK_LOG_SPEC.md`

### Minimum Required Sections
1. Task
2. Agent & Model (for example: `codex powered by gpt-5.4`)
3. Changed Files
4. Verification (commands + outcomes)
5. Remaining Issues

### Exemptions
- Typo-only markdown edits (< 3 changed lines)
- `.gitignore` or config template updates (`*.example`, `*.example.*`)
- Explicit user waiver (set `TASK_LOG_WAIVER=1` for that commit)

### WAIVER 使用限制（AI 红线）

- AI Agent **严禁**主动注入 `TASK_LOG_WAIVER=1` 来逃避日志追踪。
- 唯一合法使用场景：人类监督者 (User) **显式口头授权**，且 commit message 中必须包含 `[WAIVER: human-authorized]` 标记。
- 系统绝境死锁（如 pre-commit 与 onboarding gate 循环依赖）时可使用，但必须在同一 session 内补建日志并去除 WAIVER。

### Enforcement
- Enforced by pre-commit gate: `ops/pre-commit-log-check.sh`

## 文档治理约束

- 活跃治理文档（不含 archive/ 和 logs/）总行数上限：1,200 行。
- 每条治理规则只允许一个权威落点；其他文件用引用。
- 已完成使命的文档必须移入 archive/。
- 按需定期审查治理文档是否仍与当前工程形态一致。
