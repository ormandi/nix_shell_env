# Prompt:
#
#   Set the bash prompt according to:
#    * the active virtualenv
#    * the branch of the current git repository
#    * the return value of the previous command
#
# LINEAGE:
#
#   Based on work by woods
#
#   https://gist.github.com/31967

# Use the bash from Nix if available.
if [ -n "$NIX_BASH" ]; then
  export SHELL="${HOME}/.nix_shell_wrapper.sh"
  cat << EOF > $SHELL
#!/usr/bin/env bash
$NIX_BASH --rcfile $NIX_BASHRC "\$@"
EOF
  chmod 755 ${SHELL}
  alias bash="exec $SHELL"
  alias bazel="bazelisk"
  if [ -f "$NIX_BAZEL_COMPLETION" ] && [ -s "$NIX_BAZEL_COMPLETION" ]; then
    source "$NIX_BAZEL_COMPLETION"
    complete -F _bazel__complete -o nospace bazelisk
  fi
  alias tmux="$NIX_TMUX -f $NIX_TMUX_CONF"
  export EDITOR="$NIX_VIM -u $NIX_VIMRC"
  alias vim="$EDITOR"
  alias vimdiff="$NIX_VIM_DIFF -u $NIX_VIMRC"
  alias whoami="echo $USER"
fi

# The various escape codes that we can use to color our prompt.
         RED="\[\033[38;5;160m\]"   # Bright red
      YELLOW="\[\033[38;5;220m\]"   # Bright yellow
       GREEN="\[\033[38;5;114m\]"   # Vim-like green
        BLUE="\[\033[38;5;75m\]"    # Sky blue
      PURPLE="\[\033[38;5;141m\]"   # Vim purple
   LIGHT_RED="\[\033[38;5;203m\]"   # Light red
 LIGHT_GREEN="\[\033[38;5;120m\]"   # Light green
       WHITE="\[\033[38;5;231m\]"   # Pure white
  LIGHT_GRAY="\[\033[38;5;250m\]"   # Light gray
        CYAN="\[\033[38;5;87m\]"    # Bright cyan
LIGHT_ORANGE="\[\033[38;5;215m\]"   # Light orange (peach)
      ORANGE="\[\033[38;5;208m\]"   # Vibrant orange
        PINK="\[\033[38;5;211m\]"   # Soft pink
  LIGHT_BLUE="\[\033[38;5;117m\]"   # Pale blue
        TEAL="\[\033[38;5;80m\]"    # Teal/turquoise
       PEACH="\[\033[38;5;223m\]"   # Peachy yellow
    LAVENDER="\[\033[38;5;183m\]"   # Light lavender
 LIGHT_CORAL="\[\033[38;5;217m\]"   # Light coral
  COLOR_NONE="\[\e[0m\]"

# Determine the name of the nix shell environment.
function set_nix_env_name() {
    if [ -n "$IN_NIX_SHELL" ]; then
        if [ -n "$name" ]; then
            NIX_ENV_NAME_FOR_PROMPT="${LIGHT_CORAL}[${name}]${COLOR_NONE} "
        else
            NIX_ENV_NAME_FOR_PROMPT="${LIGHT_CORAL}[nix-shell]${COLOR_NONE} "
        fi
    else
        NIX_ENV_NAME_FOR_PROMPT=""
    fi
}

# Determine git branch name.
function parse_git_branch(){
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

# Determine the branch/state information for this git repository.
function set_git_branch() {
  # Get the name of the branch.
  branch=$(parse_git_branch)
  
  if [ -n "$branch" ]; then
    local status_symbol=""
    
    # Check if working directory is dirty
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      status_symbol="*"
    fi
    
    # Check if branch is ahead of remote
    local upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
    if [ -n "$upstream" ]; then
      local commits_ahead=$(git rev-list --count @{upstream}..HEAD)
      if [ "$commits_ahead" -gt 0 ]; then
        status_symbol="${status_symbol}↑"
      fi
    fi
    
    if [ -n "$status_symbol" ]; then
      BRANCH="${PURPLE} (${status_symbol}${branch})${COLOR_NONE} "
    else
      BRANCH="${PURPLE} (${branch})${COLOR_NONE} "
    fi
  else
    BRANCH=" "
  fi
}

# Return the prompt symbol to use, colorized based on the return value of the
# previous command.
function set_prompt_symbol () {
  if test $1 -eq 0 ; then
      PROMPT_SYMBOL="\n"
  else
      PROMPT_SYMBOL="${LIGHT_RED}($1) ${COLOR_NONE}\n"
  fi
}

# Determine active Python virtualenv details.
function set_virtualenv () {
  if test -z "$VIRTUAL_ENV" ; then
      PYTHON_VIRTUALENV=""
  else
      PYTHON_VIRTUALENV="${BLUE}[`basename \"$VIRTUAL_ENV\"`]${COLOR_NONE} "
  fi
}

# Capture start time before each command
function timer_start {
    BASH_COMMAND_TIMER=${BASH_COMMAND_TIMER:-$SECONDS}
}

function timer_stop {
    if [ -n "$BASH_COMMAND_TIMER" ]; then
        BASH_COMMAND_TIMER_SHOW=$(($SECONDS - $BASH_COMMAND_TIMER))
        unset BASH_COMMAND_TIMER
    else
        BASH_COMMAND_TIMER_SHOW="0"
    fi
}

trap 'timer_start' DEBUG

# Format elapsed time in human readable form
function format_time {
    local total_seconds=$1
    if (( total_seconds < 1 )); then
        printf "0 s"
    elif (( total_seconds < 60 )); then
        printf "%d s" "$total_seconds"
    elif (( total_seconds < 3600 )); then
        printf "%d m %d s" $((total_seconds / 60)) $((total_seconds % 60))
    else
        printf "%d h %d m %d s" $((total_seconds / 3600)) $(((total_seconds % 3600) / 60)) $((total_seconds % 60))
    fi
}

# Set the full bash prompt.
function set_bash_prompt () {
  # Set the PROMPT_SYMBOL variable. We do this first so we don't lose the
  # return value of the last command.
  set_prompt_symbol $?
  
  # Stop timer.
  timer_stop

  # Set the NIX_ENV_NAME_FOR_PROMPT variable.
  set_nix_env_name

  # Set the PYTHON_VIRTUALENV variable.
  set_virtualenv

  # Set the BRANCH variable.
  set_git_branch

  # Set the bash prompt variable.
  PS1="╭─ ${NIX_ENV_NAME_FOR_PROMPT}${PYTHON_VIRTUALENV}${CYAN}${USER}@\h${COLOR_NONE}:${YELLOW}\w${COLOR_NONE}${BRANCH}${GREEN}[$(format_time ${BASH_COMMAND_TIMER_SHOW:-0})]${COLOR_NONE} ${PROMPT_SYMBOL}╰○ "
}

# Tell bash to execute this function just before displaying its prompt.
PROMPT_COMMAND=set_bash_prompt

# Bash completion.
if [ -f "$NIX_BASH_COMPLETION" ]; then
    source "$NIX_BASH_COMPLETION"
fi

# Hide zshell warning.
export BASH_SILENCE_DEPRECATION_WARNING=1

# Make `ls` colorful by default.
alias ls='eza'
alias ll='eza -lah --git'
alias llt='eza -lah --git --tree'
alias llt2='eza -lah --git --tree --level 2'
alias llt3='eza -lah --git --tree --level 3'
alias llt4='eza -lah --git --tree --level 4'
alias llt5='eza -lah --git --tree --level 5'

if [ -z "$PYENV_LOADING" ]; then
    export PYENV_LOADING="true"

    export PYENV_ROOT="${HOME}/.pyenv/"
    export PYENV_INIT_TEMP_FILE=$(mktemp)
    pyenv init - --no-push-path --no-rehash $SHELL > $PYENV_INIT_TEMP_FILE
    source $PYENV_INIT_TEMP_FILE

    export PYENV_VIRTUAL_ENV_DIR="${PYENV_ROOT}/plugins/pyenv-virtualenv"
    if [ ! -d "${PYENV_VIRTUAL_ENV_DIR}" ]; then
        git clone https://github.com/pyenv/pyenv-virtualenv.git ${PYENV_VIRTUAL_ENV_DIR}
    fi

    pyenv virtualenv-init - > ${PYENV_INIT_TEMP_FILE}
    source ${PYENV_INIT_TEMP_FILE}

    unset PYENV_LOADING
fi

# Add Claude code to the $PATH
export PATH="$PATH:~/.local/bin/claude"

# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"

# tmux pane title alias.
alias pane-title='printf "\033]2;%s\033\\" "$1"'

# Make sure ghostty works as a normal terminal.
export TERM=xterm-256color
