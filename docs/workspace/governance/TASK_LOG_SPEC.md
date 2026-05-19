# Task Log Spec (Mandatory)

## Purpose

This spec defines the mandatory execution log format for all non-trivial tasks.

## Scope 互斥声明（2026-04-22 补齐）

本 SPEC **仅适用** task log 类文档（和 `AI_Workspace/docs/governance/session_logs_creation_rules.md` §文件范围 声明的"不适用"列表镜像）：
- `docs/workspace/logs/YYYYMMDD_*.md`
- `AI_Workspace/docs/logs/YYYYMMDD_*.md`
- `skills/<skill>/session_logs/YYYYMMDD_*.md`

**不适用** 以下三类文档（对应 creation rules §文件范围 的适用列表）：
- `workspace/work-journal/YYYYMMDD.md`（业务流水 / session log）
- OBS 业务权威源：`1 工作/1.4.1 AWS 运营手册与分析/*` / `1 工作/1.9 Infwave/*` / Strategy_Decisions / AWS_Business_Decisions
- OBS 客户档案：`1 工作/1.7 客户档案/<客户>/Customer_Timeline.md`、`客户简介.md`、各客户子档案

这三类文档走双文件权威源：
- **写作规则**：`AI_Workspace/docs/governance/session_logs_creation_rules.md`
- **清理规则**：`AI_Workspace/docs/governance/session_logs_cleanup_rules.md`

三套权威源互斥不重叠——修改时各走各的。

## Required Path

Prefer this path for stability with Git commits:
- `docs/workspace/logs/YYYYMMDD_<Summary_PascalCase>.md`

Alternative path for skill development:
- `skills/<skill>/session_logs/YYYYMMDD_<Summary_PascalCase>.md`

**文件名日期格式**：使用 ISO 8601 基本格式 `YYYYMMDD`（无横杠），摘要部分统一 PascalCase。
- 正确：`20260223_User_Capability_Assessment.md`
- 错误：`20260223_User_Capability_Assessment.md`、`20260223_user_capability_assessment.md`

**正文中的日期**：使用 ISO 8601 扩展格式 `YYYY-MM-DD`（有横杠），便于人类阅读。

Note:
- Some `session_logs/` paths are runtime-only by `.gitignore` policy.
- If you intentionally commit under `session_logs/`, you may need `git add -f`.

## Required Sections (must all exist)

1. `## Task`
2. `## Session`
3. `## Changed Files`
4. `## Prior State`
5. `## Verification`
6. `## Remaining Issues`
7. `## Session Insights`

## Session Format (mandatory, session_repo 2026-03-23 新增)

每份 Task Log 必须包含 `## Session` 段落，记录以下五要素：

- **session_id**：当前会话的唯一标识。使用 Agent 平台的真实 session UUID（如 `7b654f2d-bdb8-455b-9b67-e77286dc763b`）。同一 session 内的多份 Task Log 使用同一 session_id。
- **session_repo**：session 执行时所处的项目目录名（如 `misc`、`openclaw`）。当日志存放目录与 session 执行目录不同时（跨项目产出），此字段尤为重要。
- **date**：任务执行日期，ISO 8601 扩展格式 `YYYY-MM-DD`。
- **executor**：执行 Agent 身份，格式为 `<agent> powered by <model-id>`。
- **collaborators**（可选）：多 agent 协作时列出其他参与者。

示例：
```markdown
## Session
- session_id: 7b654f2d-bdb8-455b-9b67-e77286dc763b
- session_repo: misc
- date: 2026-03-14
- executor: claude-code powered by claude-opus-4-6
- collaborators: user (review)
```

**为什么需要 session_id**：同一个任务可能跨多次对话或由多个 Agent 协作完成。session_id 将相关的 Task Log、commit、文档变更关联起来，便于审计追溯。

**为什么需要 session_repo**：session_id 的 jsonl 文件存放在 `~/.claude/projects/<project-path>/` 下，但 UUID 本身不含路径信息。当日志产出在其他项目目录时（如 session 在 `misc` 下运行，日志放在 `health`），不标注 session_repo 就无法还原执行上下文。

**获取 session_id 的方式**：
- Claude Code：`ls -t ~/.claude/projects/<project-path>/*.jsonl | head -1`，取文件名（去掉 `.jsonl` 后缀）
- Codex/其他 Agent：使用各 Agent 平台提供的 session 标识符

## Executor Format (mandatory)

### executor 字段（机器可读 model-id）

**必须格式**：`<agent> powered by <model-id>`

- `- executor: codex powered by gpt-5.4`
- `- executor: claude-code powered by claude-opus-4-6`
- `- executor: openclaw powered by kimi-k2.5`
- Codex 不得凭记忆手写版本号；先运行 `~/AI_Workspace/ops/get_codex_executor.sh`，它会从 `~/.codex/config.toml` 读取当前 `model = "..."` 并输出可直接粘贴的 executor。

**model-id 格式规则**（门禁自动校验，无需维护白名单）：
- 全小写，字母开头，含至少一个版本号数字
- 新模型只要符合格式就自动通过，无需改任何文件

**禁止**以下模糊写法（门禁会拦截 executor 字段）：
- `codex`（无版本号数字）
- `claude`（无版本号数字）
- `powered by gpt`（无版本号数字）
- 非全小写的 model-id（如 `Claude Opus 4.6`、`GPT-5.3-Codex`）

### 正文/标题中（人类可读产品名）

在文档正文、标题、注释中引用模型时，使用各厂商**官方产品名**：
- Anthropic：`Claude Opus 4.6`、`Claude Sonnet 4.6`、`Claude Haiku 4.5`
- OpenAI：`GPT-5.2`、`GPT-5.3-Codex`、`GPT-5.4`
- Google：`Gemini 2.5 Pro`、`Gemini 2.5 Flash`
- Moonshot：`Kimi K2.5`

**禁止**在正文中使用 API model-id 格式（如 `claude-opus-4-6`）。

### 多 agent 协作

如有多 agent 协作，在 `## Session` 的 collaborators 字段列出：
- `- collaborators: user + claude-code (review)`

## Prior State 规范（2026-03-11 新增）

必须说明变更前的状态，至少一句话。新 session 需要此信息判断回滚点。

合法写法：
- `AI 后端为 ChatGPT OAuth (GPT-5.4)，cron 间隔 5 分钟`
- `pre-push hook 中使用 exec 调用 git fetch`

**禁止**省略此 section 或写 `N/A`。如果是全新功能（无 prior state），写 `新增功能，无前置状态`。

## Verification 规范（2026-03-11 修订）

每条验证项只有两种合法状态：

| 状态 | 含义 | 写法 |
|---|---|---|
| **Verified** | 当场执行了命令并贴了输出 | `- Verified: \`systemctl status\` → active (running)` |
| **Unverified: \<原因\>** | 无法当场验证，说明原因 | `- Unverified: cron 下次触发在 20:02 UTC，当前无法验证` |

**禁止**使用 `[ ]` 待办写法——跨 session 无人回填，等于无效信息。
新 session 看到 `Unverified` 应自行判断是否需要补验。

## Remaining Issues 规范（2026-03-11 修订）

只有两种合法写法：

| 状态 | 含义 | 写法 |
|---|---|---|
| **none** | 任务干净收尾 | `- none` |
| **Known risk: \<具体风险\>** | 警告后续 session 此处有坑 | `- Known risk: 双服务同时运行会 409 Conflict` |

**禁止**写 TODO、建议、"应该做 X"——日志是被动参考资料，不是任务清单。
跨 session 的 TODO 无人执行，只会变成噪音。

## Session Insights 规范（2026-04-01 新增，2026-04-17 加强：来源标签硬约束，2026-04-28 v2.6.1 新增第 4 子项 Underlying Patterns）

Agent 在 session 收尾时**必须**从当次对话中提取用户非代码层面的状态，写入此节。目的是防止高价值认知信息随 session 关闭而消散，形成用户心智的纵向数字记录。

### 来源标签（MANDATORY）

**每条 bullet 必须以来源标签开头**。未带标签的条目视为不合法。

| 标签 | 含义 | 适用场景 |
|------|------|---------|
| `[用户亲述]` | 用户对话中直接说过的话或明确表达的观点 | 引用原话或明确陈述 |
| `[用户决定]` | 用户明确做出的决定（含"做""不做""退役""决定""就这样"等信号） | **仅此标签允许出现在 Decisions & Financial 栏** |
| `[Agent 观察]` | Agent 从对话流程中观察到的可验证的客观现象 | 如"追问了三次""要求回退""多次修正同一错误"——无主观推断 |
| `[Agent 推断]` | Agent 基于对话做出的主观推断或猜测 | 必须用此标签明示不确定性，不得伪装成用户观点 |

**禁止**：
- 写无标签的 bullet（一条内容不知道来源等同无效信息）
- 把 `[Agent 推断]` / `[Agent 观察]` / `[Agent 建议]` 塞进 **Decisions & Financial** 栏——此栏只接受 `[用户决定]`
- Agent 自己的建议以任何标签出现在 Session Insights 中（建议属于对话内容，不属于观察记录）

### 四个子项（结构必须保留，无内容写 `none`）

- **Core Insights（核心洞察）**：对话中产生的非代码级思考、架构级顿悟或业务方向认知。
  - 示例：
    - `- [用户亲述] 不需要为了类型思维改 JSON/Schema 基础设施`
    - `- [Agent 观察] 用户对多轮理论框架迭代表现出明显效率焦虑`
    - `- [Agent 推断] 用户倾向"先摸现状再出建议"的对话节奏`

- **Emotional Context（情绪与状态）**：用户在指导任务时表现出的倾向、情绪痛点或关注优先级。
  - 示例：
    - `- [用户亲述] "聊得不是很痛快"`
    - `- [Agent 观察] 用户连续三轮指出建议"太抽象/多此一举/已经有了"`
    - `- [Agent 推断] 对频繁 TCC 弹窗产生抗拒，要求优先处理无感降级`

- **Decisions & Financial（关键决断）**：做出的业务取舍、生活管理或财务相关的不可逆决定。**仅 `[用户决定]` 标签合法**。
  - 示例：
    - `- [用户决定] 退役 finance_master.xlsx，SQLite 作为唯一权威源`
    - `- [用户决定] none`

<!-- TRIGGER_AUTHORITY 2026-04-28 v2.6.5: 此节"触发"行为权威源；AI_Workspace/CLAUDE.md § 子 agent 经验回写 第 (5) 类 + AI_Workspace/ops/inject_session_reminders.sh L2_TRIGGER + DOC_SCOPE_REMIND ⑦ 镜像 from here。修改触发条件关键词集后必须跑 AI_Workspace/ops/check_trigger_sync.sh 验证 3 处一致 -->
- **Underlying Patterns（事件→通用原则反演）**：本 session 处理过退役 / fallback 切换 / 事故 / 反例 / 修复 / 推翻假设类事件时，必须显式反问"事件背后是否有可复用的通用原则"，并指出该原则**应固化到的具体 sink 路径**。**写到 task log 此节 ≠ 已抽象到 sink**——本节只是审计 trace，agent 必须同步在对应文件落盘抽象后才算完成。
  - **触发**：本 session 含**退役 / fallback 切换 / 事故 / 反例 / 修复 / 推翻假设 / 心智模型重构 / 跨 repo 心智迁移 / 默认假设推翻**类事件；纯机械执行无事件可写 `none`（2026-04-28 v2.6.2 扩展：原版仅"退役/fallback/事故/反例"过窄，AImodel-gateway D-VG-004 心智模型重构案例实证扩展必要性）
  - **判定**：下次新 session 看 Account_History/客户档案单条事件，**能否 derive 这条原则**？不能 → 必须抽象到正确 sink
  - **标签限定**：仅 `[Agent 推断]` 或 `[用户亲述]`（这是反演产物，不是观察事实，不进 Decisions）
  - **写法**：`- [<标签>] <一句话原则陈述> → 已固化到 <绝对路径或 wikilink>`（"已固化"指 sink 文件中已落盘，非"待固化"）
  - **Sink 路由**（5 选 1）：
    - 业务方向 / 客户判断 → `OBS Strategy_Decisions § 通用原则` 或客户档案
    - 运维操作纪律 → `Operations_Runbook § SOP / § 红线`
    - agent 默认行为 / 认知边界 → `agents/<n>.md § 红线 / § 经验沉淀`
    - 跨工具 / 跨 repo 治理 → `Governance_Architecture + Q&A`
    - 单点 fix 无可复用原则 → 不抽象，直接 `- none`
  - 示例：
    - `- [Agent 推断] 号源切换 ≠ 无缝 fallback（不同 OAuth = 不同 conversation continuity / prompt cache / model coverage）→ 已固化到 agents/gateway-ops.md § 6 红线 #5`
    - `- [用户亲述] "checklist 命中 ≠ 收尾完成" → 已固化到 ops/inject_session_reminders.sh DOC_SCOPE_REMIND 元规则前置段`
    - `- none`（无事件 / 仅机械执行）

### 失败案例（2026-04-16 实际发生）

- ❌ `- Decisions & Financial: 决定不读《Scala 函数式编程》——用户不写代码，类型思维已通过 Harness 实践获得`
  - 问题：Agent 的建议（不读书）被写成用户的决定。用户并未表态。
- ✅ `- Decisions & Financial: [用户决定] none`
  - Agent 的建议不在此栏出现。若必要记录建议，放对话记录或 Remaining Issues，不进 Session Insights。

### 触发条件

用户收尾（结束/收工/就这样吧/先这样/退出）时，Agent 必须自动填写此节，无需用户提醒。

### 其他写法约束

- 用第三人称描述用户状态（"用户……"），不写 Agent 自身感受。
- 不写未来建议（此节是观察记录，不是 TODO）。
- 若本次 session 完全是机械执行，无任何认知/情绪/决策信息可提取，三项均写 `none` 即可（`none` 不需要标签前缀）。

## Recommended Template

```markdown
# YYYYMMDD_<Summary_PascalCase>

## Task
- One sentence describing the task.

## Session
- session_id: <agent-platform-session-uuid>
- session_repo: <project-directory-name>
- date: YYYY-MM-DD
- executor: codex powered by gpt-5.4
- collaborators: user (optional)

## Changed Files
- `path/to/file1`
- `path/to/file2`

## Prior State
- 变更前的关键状态描述（至少一句话）

## Verification
- Verified: `command 1` → actual output
- Unverified: <原因>

## Remaining Issues
- none

## Session Insights
- Core Insights:
  - [用户亲述] ...
  - [Agent 观察] ...
  - [Agent 推断] ...
- Emotional Context:
  - [用户亲述] ...
  - [Agent 观察] ...
- Decisions & Financial:
  - [用户决定] ...   # 仅此标签合法
- Underlying Patterns:
  - [Agent 推断] <原则一句话> → 已固化到 <sink 路径>
  - none   # 若无事件 / 仅机械执行
```

> 若某栏无内容，直接写 `- <栏名>: none`，不需要标签前缀。

## Exemptions

Only these are exempt from mandatory task logs:
- Typo-only markdown edits (`< 3` changed lines)
- `.gitignore` or config template updates (`*.example`, `*.example.*`)
- Explicit user waiver (`TASK_LOG_WAIVER=1` for that commit)
  - Commit-message marker for human-approved waivers: `[WAIVER: human-authorized]`

## Enforcement

- Pre-commit gate: `ops/pre-commit-log-check.sh`
- Hook bootstrap: `ops/install_git_hooks.sh --apply`
- Strict mode (default ON): `TASK_LOG_STRICT=1` (model whitelist + content quality check block commit on violation)
- Waiver audit: `TASK_LOG_WAIVER=1` writes audit lines to `$(git rev-parse --git-path waiver-audit.log)`
