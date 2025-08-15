#!/bin/bash

cp ./tmux_rocm_smi.sh ~/
cp .tmux.conf ~/
tmux source-file ~/.tmux.conf

cp .vimrc ~/

## Copy docker run script
cp drun.sh ~/.local/bin/drun
chmod +x ~/.local/bin/drun

#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#cd  ~/.oh-my-zsh/custom/plugins
#git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
#source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh

cat << 'EOF' >> ~/.bashrc
alias dps='docker ps --format="table {{.ID}}\t{{printf \"%.50s\" .Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Names}}"'

dstoprm() { for container in "$@"; do docker stop "$container" && docker rm "$container"; done; }

EOF
source ~/.bashrc
