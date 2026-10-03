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

Two more options are mostly there for the [Neovim](#keybindings) mapping:

- `--print` shows the picker and prints the chosen directory instead of opening
  it.
- `--edit FILE [LINE [COLUMN]]` opens a file in Neovim in its project's
  workspace, in the background: the nearest folder above the file that is in
  your directories list, else its git root, else the folder it's in. An open
  workspace gets a new tab for it, so nothing already running there is typed
  into.

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
needs a tty. Add it to your keymaps:

```lua
-- herdr-sessionizer needs a tty for fzf, so run it in a float that closes on exit
local function sessionizer_float(cmd, on_exit)
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
	vim.fn.jobstart(cmd, {
		term = true,
		on_exit = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
			if on_exit then
				on_exit()
			end
		end,
	})
	vim.cmd.startinsert()
end

-- Open herdr on dir in a new terminal window, and quit if no files are left open.
local function sessionizer_window(dir)
	local cmd = { "xdg-terminal-exec", vim.fn.exepath("herdr-sessionizer"), dir }
	if vim.fn.executable("uwsm-app") == 1 then
		cmd = { "uwsm-app", "--", unpack(cmd) }
	end
	vim.fn.jobstart(cmd, { detach = true })
	for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if info.name ~= "" then
			return
		end
	end
	vim.cmd("confirm qall")
end

vim.keymap.set("n", "<C-f>", function()
	if vim.env.HERDR_ENV == "1" then
		sessionizer_float({ "herdr-sessionizer" })
		return
	end

	-- Outside herdr: move the current file into its project's workspace, then
	-- open herdr on the picked directory in a new window.
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local picked = vim.fn.tempname()
	sessionizer_float({ "sh", "-c", 'herdr-sessionizer --print > "$1"', "sh", picked }, function()
		local dir = vim.fn.filereadable(picked) == 1 and vim.fn.readfile(picked)[1] or ""
		vim.fn.delete(picked)
		if dir == "" then
			return
		end
		if vim.bo[buf].buftype ~= "" or vim.fn.filereadable(file) == 0 then
			sessionizer_window(dir)
			return
		end
		if vim.bo[buf].modified then
			local name = vim.fn.fnamemodify(file, ":~:.")
			local answer = vim.fn.confirm(("Save changes to %s?"):format(name), "&Yes\n&No\n&Cancel")
			if answer == 1 then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd.write()
				end)
			elseif answer ~= 2 then
				return
			end
		end
		-- close it here so the Neovim in herdr can open it without a swap file warning
		vim.api.nvim_buf_delete(buf, { force = true })
		local edit = { "herdr-sessionizer", "--edit", file, tostring(row), tostring(col + 1) }
		vim.system(edit, {}, vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				vim.notify("herdr-sessionizer: couldn't open " .. file .. " in herdr", vim.log.levels.ERROR)
				vim.cmd.edit(vim.fn.fnameescape(file))
				vim.api.nvim_win_set_cursor(0, { row, col })
				return
			end
			sessionizer_window(dir)
		end))
	end)
end, { noremap = true, desc = "Open herdr sessionizer" })
```

Outside herdr, picking a directory also moves the file you're editing into
herdr:

1. If the file has unsaved changes, it asks whether to save them. Cancel stops
   here, and so does closing the picker without choosing.
2. The file closes, and `herdr-sessionizer --edit` opens it in Neovim at the
   same cursor position, in its project's workspace: the nearest folder above
   the file that is in your directories list, else its git root, else the
   folder it's in. If that workspace is already open, the file gets a new tab
   there.
3. A new terminal window opens with herdr on the directory you picked, through
   `xdg-terminal-exec`, or `uwsm-app -- xdg-terminal-exec` where `uwsm-app` is
   installed, as on Omarchy.
4. If no other files are open, Neovim quits. The old window stays either way.

If the current buffer isn't a file, it goes straight to the new window.

Inside herdr, the mapping doesn't run while the herdr binding above is on
`ctrl+f`: herdr takes the key before Neovim sees it and opens its own popup
instead. It only fires there if you moved the herdr binding to another key,
such as `prefix+f`.

## Tests

```sh
test/run
```

The tests need herdr, jq and git, and Neovim for the mapping tests. They run in
a throwaway herdr session and a temporary home directory, so they don't touch
your workspaces, and stand-ins replace fzf, `nvim` in herdr panes and the
terminal launcher, so no window opens. The Neovim tests load the mapping from
this README, so the snippet above is the one being tested.
