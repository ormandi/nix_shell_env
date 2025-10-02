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
 COLOR_NONE="\[\e[0m\]"

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
    BRANCH=""
  fi
}

# Return the prompt symbol to use, colorized based on the return value of the
# previous command.
function set_prompt_symbol () {
  if test $1 -eq 0 ; then
      PROMPT_SYMBOL="\$"
  else
      PROMPT_SYMBOL="${LIGHT_RED}($1)\$${COLOR_NONE}"
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

  # Set the PYTHON_VIRTUALENV variable.
  set_virtualenv

  # Set the BRANCH variable.
  set_git_branch

  # Set the bash prompt variable.
  PS1="${PYTHON_VIRTUALENV}${CYAN}\u@\h${COLOR_NONE}:${YELLOW}\w${COLOR_NONE}${BRANCH}${GREEN}[$(format_time ${BASH_COMMAND_TIMER_SHOW:-0})]${COLOR_NONE} ${PROMPT_SYMBOL} "
}

# Tell bash to execute this function just before displaying its prompt.
PROMPT_COMMAND=set_bash_prompt

# Make `ls` colorful by default.
alias ls='ls --color=auto'
alias ll='ls -lah'

# Add Homebrew to the `PATH`.
export PATH="/opt/homebrew/bin/:${PATH}"

# Add Rust to `PATH`
. "$HOME/.cargo/env"

# Initialize pyenv.
eval $(pyenv init --path)
export temp_file=$(mktemp)
pyenv init - > $temp_file
source $temp_file
pyenv virtualenv-init - > $temp_file
source $temp_file


# Bash completion.
# Use bash-completion, if available
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi
# source ~/bash_completion/out/bazel-complete.bash

# Hide zshell warning.
export BASH_SILENCE_DEPRECATION_WARNING=1

# Add other aliases:
alias ssh_gcuda='gcloud compute ssh "cuda-examples-dev" --zone "us-central1-a" --project "cudaexamples"'
alias stop_gcuda='gcloud compute instances stop "cuda-examples-dev" --zone="us-central1-a"  --project="cudaexamples"'
alias start_gcuda='gcloud compute instances start "cuda-examples-dev" --zone="us-central1-a"  --project="cudaexamples"'

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/ormandi/.cache/lm-studio/bin"
# End of LM Studio CLI section


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/ormandi/.cache/lm-studio/bin"
# End of LM Studio CLI section

# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"

# tmux pane title alias.
alias pane-title='printf "\033]2;%s\033\\" "$1"'
