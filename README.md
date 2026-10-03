# herdr-sessionizer

A [tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer) for
[herdr](https://herdr.dev): pick a project directory with fzf and open it in its
own herdr workspace, or jump to that workspace if it is already open.

- Inside herdr it switches your current client to the workspace.
- Outside herdr it starts the herdr server if needed, opens the workspace, and
  attaches.
- Workspaces are labelled with the directory name (`.` and spaces become `_`),
  unless the directories file names them or a [wildcard](#wildcards) found
  them. Your home directory is labelled `~`, matching what herdr shows on its
  own.

## Requirements

herdr (tested with 0.9.3), bash, fzf, jq.

## Install

```sh
git clone git@github.com:devolent/herdr-sessionizer.git
ln -s "$PWD/herdr-sessionizer/herdr-sessionizer" ~/.local/bin/herdr-sessionizer
mkdir -p ~/.config/herdr/sessionizer
cp herdr-sessionizer/directories.example ~/.config/herdr/sessionizer/directories
```

## Directories

`~/.config/herdr/sessionizer/directories` (or `$HERDR_SESSIONIZER_CONFIG`) lists
what the picker offers, one path per line:

```
# a path with wildcards offers every folder it matches (see Wildcards below)
~/projects/*
~/customers/*/*

# any other path is offered as-is
~
~/.dotfiles

# "path = name" names the workspace, e.g. to tell two "api" folders apart
~/work/shop/api = shop-api
~/work/billing/api = billing-api
```

Names only apply to single folders, not wildcard lines. The spaces around `=`
are required, so paths containing `=` still work.

`~` is expanded, `#` starts a comment line, and paths that don't exist are
skipped, so one list can be shared between machines. Without the file, the
picker offers `~` and its subdirectories.

Pass a directory as the only argument to skip the picker:
`herdr-sessionizer ~/projects/foo`.

## Wildcards

A line with a wildcard offers every folder it matches instead of itself. The
wildcards are the shell's:

| Wildcard | Matches                              | Example                |
| -------- | ------------------------------------ | ---------------------- |
| `*`      | any part of a name                   | `~/projects/*`         |
| `?`      | exactly one character                | `~/archive/20??`       |
| `[...]`  | one character from a set or range    | `~/customers/[a-m]*/*` |
| `[!...]` | one character that isn't in the set  | `~/src/[!_]*`          |

A wildcard never crosses a `/`, so use one per level you want to go down:
`~/customers/*/*` reaches `~/customers/acme/api` but not
`~/customers/acme/api/v2`.

Folders found by a wildcard are named from the first wildcard on, so folders
that share a name under different parents get their own workspaces:

| Line                   | Offers                                                   | Named        |
| ---------------------- | -------------------------------------------------------- | ------------ |
| `~/projects/*`         | `~/projects/foo`                                         | `foo`        |
| `~/customers/*/*`      | `~/customers/acme/api`                                   | `acme/api`   |
|                        | `~/customers/globex/api`                                 | `globex/api` |
| `~/customers/*/src`    | `~/customers/acme/src`                                   | `acme/src`   |
| `~/clients/acme-*`     | `~/clients/acme-web`                                     | `acme-web`   |
| `~/archive/20??`       | `~/archive/2024`, but not `~/archive/old`                | `2024`       |
| `~/customers/[a-m]*/*` | `~/customers/acme/api`, but not `~/customers/zenith/api` | `acme/api`   |
| `~/src/[!_]*`          | `~/src/tool`, but not `~/src/_scratch`                   | `tool`       |

- Only folders are offered; files are skipped.
- Hidden folders are skipped unless the pattern starts the name with a dot:
  `~/work/.*` offers `~/work/.cache` as `_cache` (needs bash 5.2 or newer,
  older versions also match `.` and `..`).
- `.` and spaces in names become `_`: `~/customers/my.co/new app` is
  `my_co/new_app`.
- A folder matched by more than one line is offered once, named by the first
  of those lines. A `path = name` line for it always wins, wherever it is.
- Symlinked folders are offered too, and the picker shows the real path.
- `**` is not recursive, it works like `*`. Braces aren't expanded either, so
  `~/customers/{acme,globex}/*` offers nothing; write one line for each.
- To match `*`, `?` or `[` literally, put it in brackets: `~/music/[[]old]`
  offers `~/music/[old]`. A backslash doesn't work.

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

**Neovim** (0.11 or newer) runs the picker in a floating terminal, because fzf
needs a tty, and closes the float when it's done. Add it to your keymaps:

```lua
-- herdr-sessionizer needs a tty for fzf, so run it in a float that closes on exit
vim.keymap.set("n", "<C-f>", function()
	if vim.env.HERDR_ENV ~= "1" then
		vim.notify("herdr-sessionizer: not inside herdr", vim.log.levels.WARN)
		return
	end
	local width = math.floor(vim.o.columns * 0.6)
	local height = math.floor(vim.o.lines * 0.6)
	local win = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
	})
	vim.fn.jobstart({ "herdr-sessionizer" }, {
		term = true,
		on_exit = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end,
	})
	vim.cmd.startinsert()
end, { noremap = true, desc = "Open herdr sessionizer" })
```

Inside herdr, this doesn't run while the herdr binding above is on `ctrl+f`:
herdr takes the key before Neovim sees it and opens its own popup instead. The
mapping only fires if you moved the herdr binding to another key, such as
`prefix+f`. Outside herdr it only shows a "not inside herdr" warning, because
the sessionizer would end by attaching herdr inside Neovim's float.
