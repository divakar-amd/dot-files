#!/bin/bash

cp ./tmux_rocm_smi.sh ~/
cp .tmux.conf ~/
tmux source-file ~/.tmux.conf

cp .vimrc ~/

## Copy docker run script
mkdir -p ~/.local/bin
cp drun.sh ~/.local/bin/drun
cp drunl.sh ~/.local/bin/drunl
chmod +x ~/.local/bin/drun
chmod +x ~/.local/bin/drunl

#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#cd  ~/.oh-my-zsh/custom/plugins
#git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
#source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

cat << 'EOF' >> ~/.bashrc
alias dps='docker ps --format="table {{.ID}}\t{{printf \"%.50s\" .Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Names}}"'

EOF

cat custom_bash_cmds.sh >> ~/.bashrc

source ~/.bashrc

## Claude Code status bar
curl -fsSL https://raw.githubusercontent.com/briansmith80/claude-code-status-bar/main/install.sh | bash

## The installer hardcodes statusLine/subagentStatusLine commands to this
## machine's absolute $HOME path. That breaks once ~/.claude is docker cp'd
## into a container running as a different user (e.g. root), so rewrite
## those commands to use $HOME instead -- works on host and in any container.
python3 <<'PYEOF'
import json, os

path = os.path.expanduser('~/.claude/settings.json')
home = os.environ['HOME']
settings = json.load(open(path))
for key in ('statusLine', 'subagentStatusLine'):
    if key in settings and 'command' in settings[key]:
        settings[key]['command'] = settings[key]['command'].replace(home, '$HOME')
json.dump(settings, open(path, 'w'), indent=2)
PYEOF
