# dotfiles
Personal configuration files to make me feel cool when using Linux

## TMUX
1. TMUX Installation: https://github.com/tmux/tmux/wiki/Installing
2. Move .tmux files to home directory

## Gnome Terminal Instructions
Dump current gnome terminal config
```
dconf dump /org/gnome/terminal/ > gnome_terminal_settings.txt 
```

Load current gnome terminal config
```
dconf load /org/gnome/terminal/ < gnome_terminal_settings.txt 
```


## Credits
OG Tmux config: https://github.com/gpakosz/.tmux