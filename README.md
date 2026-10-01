# herdr-sessionizer

A [tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for
[herdr](https://herdr.dev): pick a project directory with fzf and open it in its
own herdr workspace, or jump to that workspace if it is already open.

- Inside herdr it switches your current client to the workspace.
- Outside herdr it starts the herdr server if needed, opens the workspace, and
  attaches.
- Workspaces are labelled with the directory name (`.` and spaces become `_`).
  Your home directory is labelled `~`, matching what herdr shows on its own.

## Requirements

herdr (tested with 0.9.3), bash, fzf, jq.

## Install

```sh
git clone git@github.com:devolent/herdr-sessionizer.git
ln -s "$PWD/herdr-sessionizer/herdr-sessionizer" ~/.local/bin/herdr-sessionizer
mkdir -p ~/.config/herdr-sessionizer
cp herdr-sessionizer/directories.example ~/.config/herdr-sessionizer/directories
```

## Directories

`~/.config/herdr-sessionizer/directories` (or `$HERDR_SESSIONIZER_CONFIG`) lists
what the picker offers, one path per line:

```
# a path ending in /* offers each of its subdirectories (hidden ones skipped)
~/projects/*

# any other path is offered as-is
~
~/.dotfiles
```

`~` is expanded, `#` starts a comment line, and paths that don't exist are
skipped, so one list can be shared between machines. Without the file, the
picker offers `~` and its subdirectories.

Pass a directory as the only argument to skip the picker:
`herdr-sessionizer ~/projects/foo`.

## Keybindings

**herdr** (recommended): a popup binding works no matter what is running in the
pane: a shell, an editor, or an agent. Add to `~/.config/herdr/config.toml`,
then `herdr server reload-config`:

```toml
[[keys.command]]
key = "ctrl+f"
type = "popup"
command = "herdr-sessionizer"
width = "60%"
height = "60%"
```

This takes `ctrl+f` from every program inside herdr. Use something like
`prefix+f` if you'd rather keep it.

**bash**, for terminals outside herdr:

```sh
bind -x '"\C-f": herdr-sessionizer'
```

**zsh**:

```sh
bindkey -s '^f' 'herdr-sessionizer\n'
```
