#!/bin/bash

alias ls='ls -G'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias dmesg='dmesg --human'
alias :q='exit'
alias grep='grep --color=always'
alias grop='grep --color=never'
alias sudo='sudo -E'
alias csvawk='awk -v FPAT="([^,]*)|(\"([^\"]|\"\")+\")"'
alias plainvim='vim -u NONE'

alias weather='curl wttr.in'

alias k=kubectl

_claude_find_parent_claude_md() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -f "$dir/.claude/CLAUDE.md" ]; then
      echo "$dir"
      return
    fi
  done
}

_claude_find_parent_settings() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -f "$dir/.claude/settings.json" ]; then
      echo "$dir/.claude/settings.json"
      return
    fi
  done
}

_claude_discover_plugins() {
  local dir="$PWD"
  local -A seen
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -d "$dir/.claude/plugins" ]; then
      for p in "$dir"/.claude/plugins/*/; do
        local name="$(basename "$p")"
        if [ -d "${p}.claude-plugin" ] && [ -z "${seen[$name]}" ]; then
          seen[$name]=1
          echo "$p"
        fi
      done
    fi
  done
}

_claude_find_parent_mcp_config() {
  local parent="$(dirname "$PWD")"
  if [ "$parent" != "$HOME" ] && [ "$parent" != "/" ] && [ -f "$parent/.mcp.json" ]; then
    echo "$parent/.mcp.json"
  fi
}

_claude_account_config_dir() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/.claude-account" ]; then
      cat "$dir/.claude-account"
      return
    fi
    dir="$(dirname "$dir")"
  done
}

_claude_ensure_otel() {
  local name="claude-otel-collector"
  local image="otel/opentelemetry-collector-contrib:0.156.0"
  local config="$HOME/dev/private/dotfiles/.claude/otel/collector-config.yaml"

  if [ -z "$CLAUDE_OTEL_DATA_DIR" ]; then
    echo "c: CLAUDE_OTEL_DATA_DIR is not set — telemetry has nowhere to go." >&2
    return 1
  fi
  mkdir -p "$CLAUDE_OTEL_DATA_DIR" || return 1

  if docker ps --format '{{.Names}}' | grep -qx "$name"; then
    return 0
  elif docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    docker start "$name" >/dev/null
  else
    docker run -d --name "$name" --restart unless-stopped \
      -p 4317:4317 -p 4318:4318 \
      -v "$config":/etc/otelcol-contrib/config.yaml:ro \
      -v "$CLAUDE_OTEL_DATA_DIR":/data \
      "$image" >/dev/null
  fi
}

c() {
  if [ "$1" != "agents" ] && [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    set -- -- "$*"
  fi
  # Scoped to the child rather than exported: a leaked CLAUDE_CONFIG_DIR would
  # silently point a later bare `claude` at the wrong account.
  local account_config_dir="$(_claude_account_config_dir)"
  local config_env=(env -u CLAUDE_CONFIG_DIR)
  [ -n "$account_config_dir" ] && config_env=(env "CLAUDE_CONFIG_DIR=$account_config_dir")
  _claude_ensure_otel || return 1
  export CLAUDE_CODE_ENABLE_TELEMETRY=1
  export OTEL_METRICS_EXPORTER=otlp
  export OTEL_LOGS_EXPORTER=otlp
  export OTEL_TRACES_EXPORTER=otlp
  export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
  export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
  export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
  export OTEL_LOG_USER_PROMPTS=1
  export OTEL_LOG_ASSISTANT_RESPONSES=1
  export OTEL_LOG_TOOL_DETAILS=1
  export OTEL_LOG_TOOL_CONTENT=1
  export OTEL_LOG_RAW_API_BODIES=1
  export OTEL_METRICS_INCLUDE_VERSION=true
  export OTEL_METRICS_INCLUDE_ENTRYPOINT=true
  export OTEL_METRICS_INCLUDE_SESSION_ID=true
  export OTEL_METRICS_INCLUDE_ACCOUNT_UUID=true
  local add_dir="$(_claude_find_parent_claude_md)"
  local settings_file="$(_claude_find_parent_settings)"
  local mcp_config="$(_claude_find_parent_mcp_config)"
  local plugin_args=()
  while IFS= read -r p; do
    [ -n "$p" ] && plugin_args+=(--plugin-dir "$p")
  done < <(_claude_discover_plugins)
  local settings_args=()
  [ -n "$settings_file" ] && settings_args=(--settings "$settings_file")
  local mcp_args=()
  [ -n "$mcp_config" ] && mcp_args=(--mcp-config "$mcp_config")
  local model_args=()
  local has_model=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --model|--model=*) has_model=1; break ;;
    esac
  done
  [ "$has_model" -eq 0 ] && model_args=(--model default)
  export CLAUDE_CODE_NO_FLICKER=1
  export ENABLE_PROMPT_CACHING_1H=1
  if [ -n "$add_dir" ]; then
    "${config_env[@]}" CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir "$add_dir" "${plugin_args[@]}" "${settings_args[@]}" "${mcp_args[@]}" "${model_args[@]}" "$@"
  else
    "${config_env[@]}" claude "${plugin_args[@]}" "${settings_args[@]}" "${mcp_args[@]}" "${model_args[@]}" "$@"
  fi
}

# `claude --resume` only offers sessions started in the current directory; this
# lists the latest ones of the whole account, so you know where to cd to resume.
cl() {
  local config_dir="$(_claude_account_config_dir)"
  config_dir="${config_dir:-$HOME/.claude}"
  if [ ! -d "$config_dir/projects" ]; then
    echo "cl: no sessions in $config_dir" >&2
    return 1
  fi
  local limit=20 shown=0 mtime f cwd shown_cwd title
  # maxdepth 2 skips subagent transcripts, which live under <session>/subagents/
  while read -r mtime f; do
    cwd="$(command grep -m1 '"cwd":"' "$f" | jq -r '.cwd // empty')"
    # Sessions that never got a prompt have no cwd and can't be resumed anyway
    [ -z "$cwd" ] && continue
    case "$cwd" in
      "$HOME") shown_cwd="~" ;;
      "$HOME"/*) shown_cwd="~${cwd#"$HOME"}" ;;
      *) shown_cwd="$cwd" ;;
    esac
    # Keep the tail: the repo name says more than the common prefix
    [ "${#shown_cwd}" -gt 40 ] && shown_cwd="...${shown_cwd: -37}"
    title="$(command grep -E '"type":"(custom-title|ai-title|last-prompt)"' "$f" | jq -rs '
      (map(select(.type == "custom-title")) | last | .customTitle)
      // (map(select(.type == "ai-title")) | last | .aiTitle)
      // (map(select(.type == "last-prompt")) | last | .lastPrompt)
      // ""' | tr '\n' ' ' | cut -c1-60)"
    printf '%s  %-40s  %-60s  %s\n' "$(date -r "$mtime" '+%Y-%m-%d %H:%M')" "$shown_cwd" "$title" "$(basename "$f" .jsonl)"
    shown=$((shown + 1))
    [ "$shown" -ge "$limit" ] && break
  done < <(find "$config_dir/projects" -maxdepth 2 -name '*.jsonl' -exec stat -f '%m %N' {} + | sort -rn)
}

alias gw='./gradlew'

mw() {
  if [ ! -f "pom.xml" ]; then
    echo "Error: No pom.xml found in current directory" >&2
    return 1
  fi
  if [ -f "./mvnw" ]; then
    ./mvnw "$@"
  else
    mvn "$@"
  fi
}

alias g='git grep'
alias gp='git push'
alias gl='git status'
alias goto='git checkout'

gob() {
  git checkout -b "$1"
}

gsu() {
  remote=$(git remote)
  branch=$(git branch --show-current)
  git branch --set-upstream-to="$remote/$branch" "$branch"
}

~/dev/private/dotfiles/sysdeps.sh check 2>/dev/null || true
alias syslist='~/dev/private/dotfiles/sysdeps.sh list'
alias sysupgrade='~/dev/private/dotfiles/sysdeps.sh upgrade'

alias gu='goto main && git pull'
alias gub='gu && goto -'
gdpr() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "gdpr: not on a branch" >&2
    return 1
  }
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    echo "gdpr: refusing to run on '$branch' — create a feature branch first" >&2
    return 1
  fi
  git push --no-verify && gh pr create --fill "$@"
}
alias ghw='gh pr view --web'

gc() {
  git add . || return 1
  git commit -m "$*" || return 1
}

traceparent() {
  printf '00-%s-%s-01\n' "$(openssl rand -hex 16)" "$(openssl rand -hex 8)"
}

curlt() {
  local tp
  tp="$(traceparent)"
  printf 'traceid: %s\n' "$(printf '%s' "$tp" | cut -d- -f2)" >&2
  curl -H "traceparent: $tp" "$@"
}
