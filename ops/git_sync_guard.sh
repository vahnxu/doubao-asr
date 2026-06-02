#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-status}"
shift || true

REMOTE="${REMOTE:-origin}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
SYNC_TTL_SECONDS="${SYNC_TTL_SECONDS:-900}"
PRECOMMIT_TTL_SECONDS="${PRECOMMIT_TTL_SECONDS:-300}"
FETCH_TIMEOUT_SECONDS="${FETCH_TIMEOUT_SECONDS:-20}"
BEHIND_BLOCK_THRESHOLD="${BEHIND_BLOCK_THRESHOLD:-1}"
REPORT_REMOTE_STALE_LIMIT="${REPORT_REMOTE_STALE_LIMIT:-30}"
AUTO_STASH="${AUTO_STASH:-1}"

AGENT_PREFIXES=(
  "claude/"
  "codex/"
  "antigravity/"
  "openclaw/"
)

usage() {
  cat <<'EOF'
Usage:
  ops/git_sync_guard.sh session-start
  ops/git_sync_guard.sh ttl-check [--ttl-seconds N] [--reason STR]
  ops/git_sync_guard.sh pre-commit-check [--ttl-seconds N] [--behind-threshold N]
  ops/git_sync_guard.sh status

Environment variables:
  AUTO_STASH=1  (default) auto-stash dirty working tree before fast-forward
  AUTO_STASH=0  disable auto-stash (legacy behavior: skip ff when dirty)

Design boundary:
  - Pull/fetch direction only (no auto push, no remote branch deletion).
  - Auto-stash is local-only (git stash push/pop), never touches remote.
  - Uses git-dir scoped state file:
      $(git rev-parse --git-dir)/last-fetch-ts
  - Handles network failure with warn-and-degrade behavior.
  - FETCH_TIMEOUT_SECONDS bounds git fetch so pre-commit cannot hang forever.
EOF
}

if [[ "$COMMAND" == "-h" || "$COMMAND" == "--help" ]]; then
  usage
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "[FAIL] not inside a git repository" >&2
  echo "FIX: cd 到项目根目录（含 .git/）后重新执行此脚本" >&2
  exit 1
fi
GIT_DIR="$(git -C "$REPO_ROOT" rev-parse --git-dir)"
LAST_FETCH_TS_FILE="$GIT_DIR/last-fetch-ts"
SYNC_GUARD_LOG_FILE="$GIT_DIR/sync-guard.log"
SYNC_GUARD_LOCK_DIR="$GIT_DIR/sync-guard.lock"
ONBOARDING_LOCK_FILE="$GIT_DIR/AGENT_ONBOARDING_PASSED"
LOCK_ACTIVE=0

now_epoch() {
  date +%s
}

ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_line() {
  local level="$1"
  local message="$2"
  local line
  line="$(ts) [sync-guard][$level] $message"
  echo "$line"
  if { : >>"$SYNC_GUARD_LOG_FILE"; } 2>/dev/null; then
    echo "$line" >>"$SYNC_GUARD_LOG_FILE" 2>/dev/null || true
  fi
}

onboarding_lock_exists() {
  [[ -f "$ONBOARDING_LOCK_FILE" ]]
}

require_onboarding_lock() {
  local caller="$1"
  if ! onboarding_lock_exists; then
    cat <<EOF >&2
[FAIL] onboarding gate 未通过。请先执行: ./ops/enforce_agent_onboarding_gate.sh
  ($caller 被阻断，直到 onboarding gate PASS 并创建状态锁)
EOF
    exit 1
  fi
}

acquire_lock() {
  local waited=0
  while ! mkdir "$SYNC_GUARD_LOCK_DIR" 2>/dev/null; do
    if [[ ! -e "$SYNC_GUARD_LOCK_DIR" ]]; then
      log_line "WARN" "lock unavailable (permission), continue without lock"
      LOCK_ACTIVE=0
      trap - EXIT
      return 0
    fi
    waited=$((waited + 1))
    if (( waited >= 20 )); then
      log_line "WARN" "lock busy, skip current run"
      return 1
    fi
    sleep 0.1
  done
  LOCK_ACTIVE=1
  trap 'if [[ "$LOCK_ACTIVE" -eq 1 ]]; then rmdir "$SYNC_GUARD_LOCK_DIR" >/dev/null 2>&1 || true; fi' EXIT
  return 0
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

get_last_fetch_age() {
  if [[ ! -f "$LAST_FETCH_TS_FILE" ]]; then
    echo "-1"
    return 0
  fi
  local last
  last="$(cat "$LAST_FETCH_TS_FILE" 2>/dev/null || true)"
  if ! is_integer "${last:-}"; then
    echo "-1"
    return 0
  fi
  local now
  now="$(now_epoch)"
  if (( now < last )); then
    echo "-1"
    return 0
  fi
  echo "$((now - last))"
}

touch_last_fetch_ts() {
  if ! echo "$(now_epoch)" >"$LAST_FETCH_TS_FILE" 2>/dev/null; then
    log_line "WARN" "failed to update last-fetch timestamp (permission issue): $LAST_FETCH_TS_FILE"
  fi
}

remote_main_ref() {
  echo "$REMOTE/$MAIN_BRANCH"
}

remote_main_exists() {
  git -C "$REPO_ROOT" rev-parse --verify "$(remote_main_ref)" >/dev/null 2>&1
}

run_with_timeout() {
  local timeout="$1"
  shift
  local pid=""
  local elapsed=0
  local rc=0

  if ! is_integer "$timeout" || (( timeout <= 0 )); then
    timeout=20
  fi

  "$@" &
  pid="$!"
  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= timeout )); then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  set +e
  wait "$pid"
  rc="$?"
  set -e
  return "$rc"
}

fetch_main() {
  local reason="$1"
  local before=""
  local after=""
  local new_commits=0
  local fetch_rc=0
  before="$(git -C "$REPO_ROOT" rev-parse --verify "$(remote_main_ref)" 2>/dev/null || true)"

  fetch_rc=0
  run_with_timeout "$FETCH_TIMEOUT_SECONDS" git -C "$REPO_ROOT" fetch --prune "$REMOTE" "$MAIN_BRANCH" --quiet >/dev/null 2>&1 || fetch_rc=$?
  if [[ "$fetch_rc" -eq 0 ]]; then
    after="$(git -C "$REPO_ROOT" rev-parse --verify "$(remote_main_ref)" 2>/dev/null || true)"
    touch_last_fetch_ts
    if [[ -n "$before" && -n "$after" && "$before" != "$after" ]]; then
      new_commits="$(git -C "$REPO_ROOT" rev-list --count "${before}..${after}" 2>/dev/null || echo 0)"
    fi
    log_line "INFO" "fetch ok reason=$reason new_commits=$new_commits remote=$(remote_main_ref)"
    return 0
  fi

  if [[ "$fetch_rc" -eq 124 ]]; then
    log_line "WARN" "fetch timed out after ${FETCH_TIMEOUT_SECONDS}s reason=$reason remote=$(remote_main_ref); using cached refs"
    return 1
  fi

  log_line "WARN" "fetch failed reason=$reason remote=$(remote_main_ref); using cached refs"
  return 1
}

maybe_fetch_with_ttl() {
  local ttl="$1"
  local reason="$2"
  local age
  age="$(get_last_fetch_age)"

  if ! is_integer "$ttl"; then
    ttl=900
  fi

  if [[ "$age" == "-1" ]]; then
    fetch_main "$reason:first-fetch"
    return $?
  fi

  if (( age >= ttl )); then
    fetch_main "$reason:ttl-expired(age=${age}s)"
    return $?
  fi

  log_line "INFO" "fetch skipped reason=$reason age=${age}s ttl=${ttl}s"
  return 0
}

current_branch() {
  git -C "$REPO_ROOT" symbolic-ref --short -q HEAD || echo "DETACHED"
}

working_tree_dirty() {
  if ! git -C "$REPO_ROOT" diff --quiet; then
    return 0
  fi
  if ! git -C "$REPO_ROOT" diff --cached --quiet; then
    return 0
  fi
  return 1
}

count_behind_remote_main() {
  if ! remote_main_exists; then
    echo "0"
    return 0
  fi
  git -C "$REPO_ROOT" rev-list --count "HEAD..$(remote_main_ref)" 2>/dev/null || echo "0"
}

count_ahead_remote_main() {
  if ! remote_main_exists; then
    echo "0"
    return 0
  fi
  git -C "$REPO_ROOT" rev-list --count "$(remote_main_ref)..HEAD" 2>/dev/null || echo "0"
}

warn_if_remote_ahead() {
  if ! remote_main_exists; then
    log_line "WARN" "remote ref missing: $(remote_main_ref); skip ahead/behind warning"
    return 0
  fi
  local behind ahead branch
  behind="$(count_behind_remote_main)"
  ahead="$(count_ahead_remote_main)"
  branch="$(current_branch)"
  if (( behind > 0 )); then
    log_line "WARN" "remote main ahead branch=$branch behind=$behind ahead=$ahead; suggest: git pull --rebase $REMOTE $MAIN_BRANCH"
  else
    log_line "INFO" "branch synced-with-remote branch=$branch behind=$behind ahead=$ahead"
  fi
}

_STASH_MSG=""
auto_stash_push() {
  # Sets _STASH_MSG on success. Call directly (not in subshell) to preserve log_line stdout.
  _STASH_MSG=""
  local stash_msg="sync-guard-auto-stash-$(date +%s)"
  if git -C "$REPO_ROOT" stash push -m "$stash_msg" --quiet 2>/dev/null; then
    # Verify stash actually created (git stash push exits 0 even when nothing to stash in some versions)
    local top_msg
    top_msg="$(git -C "$REPO_ROOT" stash list -1 --format='%s' 2>/dev/null || true)"
    if [[ "$top_msg" == *"$stash_msg"* ]]; then
      log_line "INFO" "auto-stash push ok msg=$stash_msg"
      _STASH_MSG="$stash_msg"
      return 0
    fi
  fi
  log_line "WARN" "auto-stash push failed"
  return 1
}

auto_stash_pop() {
  local stash_msg="$1"
  # Verify top of stash is ours before popping
  local top_msg
  top_msg="$(git -C "$REPO_ROOT" stash list -1 --format='%s' 2>/dev/null || true)"
  if [[ "$top_msg" != *"$stash_msg"* ]]; then
    log_line "WARN" "auto-stash pop skipped: stash top mismatch (expected=$stash_msg got=$top_msg)"
    return 1
  fi

  if git -C "$REPO_ROOT" stash pop --quiet 2>/dev/null; then
    log_line "INFO" "auto-stash pop ok msg=$stash_msg"
    return 0
  fi

  # Pop failed — likely merge conflict. Stash entry is already removed by git on conflict pop.
  # Check if there are conflict markers
  if git -C "$REPO_ROOT" diff --name-only --diff-filter=U 2>/dev/null | head -1 | grep -q .; then
    log_line "WARN" "auto-stash pop conflict: your stashed changes conflict with new commits"
    log_line "WARN" "resolve conflicts manually, then: git add <files> && git stash drop (if needed)"
    log_line "WARN" "or discard stashed changes: git checkout -- . && git stash drop (if stash remains)"
    return 1
  fi

  # Pop failed for other reason — stash should still be in list
  log_line "WARN" "auto-stash pop failed msg=$stash_msg; stash preserved, recover with: git stash pop"
  return 1
}

fast_forward_local_branch_to_remote_main() {
  local local_branch="$1"
  local branch_ref="refs/heads/$local_branch"
  local current
  current="$(current_branch)"

  if ! git -C "$REPO_ROOT" show-ref --verify --quiet "$branch_ref"; then
    return 0
  fi
  if ! remote_main_exists; then
    log_line "WARN" "skip fast-forward $local_branch: missing $(remote_main_ref)"
    return 0
  fi

  if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$local_branch" "$(remote_main_ref)"; then
    log_line "INFO" "skip fast-forward $local_branch: has local-only commits"
    return 0
  fi

  if [[ "$current" == "$local_branch" ]]; then
    if working_tree_dirty; then
      if [[ "$AUTO_STASH" != "1" ]]; then
        log_line "WARN" "skip fast-forward $local_branch: working tree dirty (auto-stash disabled)"
        return 0
      fi

      # Auto-stash path: stash → ff → pop
      if ! auto_stash_push; then
        log_line "WARN" "skip fast-forward $local_branch: auto-stash failed, working tree preserved"
        return 0
      fi
      local stash_msg="$_STASH_MSG"

      if [[ -z "$stash_msg" ]]; then
        log_line "WARN" "skip fast-forward $local_branch: auto-stash produced no stash entry"
        return 0
      fi

      # Now working tree is clean — attempt fast-forward
      local ff_ok=0
      if git -C "$REPO_ROOT" merge --ff-only "$(remote_main_ref)" >/dev/null 2>&1; then
        log_line "INFO" "fast-forwarded checked-out branch=$local_branch to $(remote_main_ref) (via auto-stash)"
        ff_ok=1
      else
        log_line "WARN" "ff-only merge failed for checked-out branch=$local_branch (via auto-stash)"
      fi

      # Always restore stashed changes
      if ! auto_stash_pop "$stash_msg"; then
        if (( ff_ok )); then
          log_line "WARN" "fast-forward succeeded but stash pop had issues; your changes are in git stash list"
        fi
      fi
      return 0
    fi

    # Clean working tree — straightforward fast-forward
    if git -C "$REPO_ROOT" merge --ff-only "$(remote_main_ref)" >/dev/null 2>&1; then
      log_line "INFO" "fast-forwarded checked-out branch=$local_branch to $(remote_main_ref)"
    else
      log_line "WARN" "ff-only merge failed for checked-out branch=$local_branch"
    fi
    return 0
  fi

  # Not checked out — update ref directly (no working tree concern)
  if git -C "$REPO_ROOT" update-ref "$branch_ref" "$(git -C "$REPO_ROOT" rev-parse "$(remote_main_ref)")"; then
    log_line "INFO" "fast-forwarded local branch=$local_branch to $(remote_main_ref)"
  else
    log_line "WARN" "failed to fast-forward local branch=$local_branch"
  fi
}

is_agent_branch() {
  local branch="$1"
  local prefix
  for prefix in "${AGENT_PREFIXES[@]}"; do
    if [[ "$branch" == "$prefix"* ]]; then
      return 0
    fi
  done
  return 1
}

branch_has_unique_paths_vs_main() {
  local branch_ref="$1"
  if ! remote_main_exists; then
    echo "1"
    return 0
  fi
  git -C "$REPO_ROOT" diff --diff-filter=ACMR --name-only "$(remote_main_ref)" "$branch_ref" | wc -l | tr -d ' '
}

branch_merged_fastforward() {
  local branch_ref="$1"
  if ! remote_main_exists; then
    return 1
  fi
  git -C "$REPO_ROOT" merge-base --is-ancestor "$branch_ref" "$(remote_main_ref)"
}

cleanup_local_agent_branches() {
  local current
  current="$(current_branch)"
  local deleted=()
  local kept=()
  local merged_reason=""

  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    is_agent_branch "$branch" || continue
    if [[ "$branch" == "$current" ]]; then
      kept+=("$branch(current)")
      continue
    fi

    merged_reason=""
    if branch_merged_fastforward "$branch"; then
      merged_reason="ancestor"
    else
      unique_paths="$(branch_has_unique_paths_vs_main "$branch")"
      if [[ "$unique_paths" == "0" ]]; then
        merged_reason="squash-no-diff"
      fi
    fi

    if [[ -n "$merged_reason" ]]; then
      if git -C "$REPO_ROOT" branch -D "$branch" >/dev/null 2>&1; then
        deleted+=("$branch($merged_reason)")
      else
        kept+=("$branch(delete-failed)")
      fi
    else
      kept+=("$branch(active)")
    fi
  done < <(git -C "$REPO_ROOT" for-each-ref refs/heads --format='%(refname:short)')

  if (( ${#deleted[@]} > 0 )); then
    log_line "INFO" "local agent branches deleted count=${#deleted[@]} list=${deleted[*]}"
  else
    log_line "INFO" "local agent branches deleted count=0"
  fi
  if (( ${#kept[@]} > 0 )); then
    log_line "INFO" "local agent branches kept count=${#kept[@]} list=${kept[*]}"
  fi
}

report_remote_stale_agent_branches() {
  if ! remote_main_exists; then
    log_line "WARN" "skip remote stale scan: missing $(remote_main_ref)"
    return 0
  fi

  local stale=()
  local short=""
  local ref=""
  local unique_paths=""

  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    short="${ref#${REMOTE}/}"
    [[ "$short" == "HEAD" ]] && continue
    is_agent_branch "$short" || continue

    if branch_merged_fastforward "$ref"; then
      stale+=("$short(ancestor)")
      continue
    fi

    unique_paths="$(branch_has_unique_paths_vs_main "$ref")"
    if [[ "$unique_paths" == "0" ]]; then
      stale+=("$short(squash-no-diff)")
    fi
  done < <(git -C "$REPO_ROOT" for-each-ref "refs/remotes/$REMOTE" --format='%(refname:short)')

  if (( ${#stale[@]} == 0 )); then
    log_line "INFO" "remote stale agent branch candidates count=0"
    return 0
  fi

  local display=("${stale[@]}")
  if (( ${#display[@]} > REPORT_REMOTE_STALE_LIMIT )); then
    display=("${display[@]:0:$REPORT_REMOTE_STALE_LIMIT}")
  fi
  log_line "WARN" "remote stale agent branch candidates count=${#stale[@]} list=${display[*]}"
  log_line "WARN" "remote branch cleanup is report-only (no auto delete)."
}

session_start_sync() {
  acquire_lock || return 0

  fetch_main "session-start" || true
  fast_forward_local_branch_to_remote_main "main"
  fast_forward_local_branch_to_remote_main "master"
  cleanup_local_agent_branches
  report_remote_stale_agent_branches
  warn_if_remote_ahead

  if onboarding_lock_exists; then
    log_line "INFO" "onboarding lock ok"
  else
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════════╗
║  ⚠️  ONBOARDING GATE 未完成                                     ║
║                                                                  ║
║  首次使用的 Agent 必须先执行:                                     ║
║    ./ops/enforce_agent_onboarding_gate.sh                        ║
║                                                                  ║
║  在此之前，pre-commit 和 ttl-check 将被阻断。                    ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    log_line "WARN" "onboarding lock missing: first-time agents run ./ops/enforce_agent_onboarding_gate.sh before production tasks"
  fi
}

ttl_check() {
  require_onboarding_lock "ttl-check"
  acquire_lock || return 0
  local ttl="$SYNC_TTL_SECONDS"
  local reason="ttl-check"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl-seconds)
        ttl="${2:-$ttl}"
        shift 2
        ;;
      --reason)
        reason="${2:-$reason}"
        shift 2
        ;;
      *)
        echo "[FAIL] unknown argument for ttl-check: $1" >&2
        exit 2
        ;;
    esac
  done

  maybe_fetch_with_ttl "$ttl" "$reason" || true
  warn_if_remote_ahead
}

precommit_check() {
  require_onboarding_lock "pre-commit-check"
  acquire_lock || return 0
  local ttl="$PRECOMMIT_TTL_SECONDS"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl-seconds)
        ttl="${2:-$ttl}"
        shift 2
        ;;
      --behind-threshold)
        # kept for backward compatibility, ignored (auto-catchup replaces threshold)
        shift 2
        ;;
      *)
        echo "[FAIL] unknown argument for pre-commit-check: $1" >&2
        exit 2
        ;;
    esac
  done

  if [[ "$(current_branch)" == "DETACHED" ]]; then
    log_line "WARN" "pre-commit check skip: detached HEAD"
    exit 0
  fi

  maybe_fetch_with_ttl "$ttl" "pre-commit-check" || true
  if ! remote_main_exists; then
    log_line "WARN" "pre-commit check degrade: missing $(remote_main_ref), allow commit"
    exit 0
  fi

  local behind ahead
  behind="$(count_behind_remote_main)"
  ahead="$(count_ahead_remote_main)"

  if (( behind > 0 )); then
    log_line "INFO" "pre-commit auto-catchup: behind=$behind ahead=$ahead, attempting fast-forward"
    fast_forward_local_branch_to_remote_main "$(current_branch)"

    # Re-check after FF attempt
    behind="$(count_behind_remote_main)"
    if (( behind > 0 )); then
      cat <<EOF >&2
[FAIL] auto-catchup failed: still behind=$behind after fast-forward attempt
[FAIL] likely cause: local commits diverged from $(remote_main_ref)
[FAIL] manual resolution needed:
  git pull --rebase $REMOTE $MAIN_BRANCH
EOF
      exit 1
    fi
    log_line "INFO" "pre-commit auto-catchup success: now in sync with $(remote_main_ref)"
  else
    log_line "INFO" "pre-commit check pass: behind=$behind ahead=$ahead"
  fi
}

status_report() {
  local age branch behind ahead
  age="$(get_last_fetch_age)"
  branch="$(current_branch)"
  behind="$(count_behind_remote_main)"
  ahead="$(count_ahead_remote_main)"
  echo "repo_root=$REPO_ROOT"
  echo "git_dir=$GIT_DIR"
  echo "last_fetch_ts_file=$LAST_FETCH_TS_FILE"
  echo "last_fetch_age_seconds=$age"
  echo "current_branch=$branch"
  echo "remote_main_ref=$(remote_main_ref)"
  echo "behind_remote_main=$behind"
  echo "ahead_remote_main=$ahead"
  echo "log_file=$SYNC_GUARD_LOG_FILE"
}

cd "$REPO_ROOT"
case "$COMMAND" in
  session-start)
    session_start_sync "$@"
    ;;
  ttl-check)
    ttl_check "$@"
    ;;
  pre-commit-check)
    precommit_check "$@"
    ;;
  status)
    status_report
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
