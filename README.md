# App Focus

Type an app name. If one window is open, it is focused, including a window on another workspace or a hidden scratchpad. If several are open, a second step shows a live screenshot of each one and you pick. Obsidian, VS Code, and Tmux launch when nothing is open.

This is an Omarchy shell overlay. The key that opens it stays in your Hyprland config. Installing the plugin does not change any key.

## What is already in the catalog

A search for "switcher" on the [Omarchy plugin catalog](https://plugins.omarchy.org/index.html?q=switcher#catalog) is mostly two other jobs:

- Alt+Tab switchers cycle the windows you already have open, often with live previews. Better Alt-Tab, WindowPeek, Glass Dock, and the various Alt-Tab galleries are this.
- Workspace switchers preview desktops and move you between them. Super+Tab and the workspace ribbons are this.

[Jump To](https://plugins.omarchy.org/plugin.html?id=dev.cstav.omarchy.plugin.jump-to) is the nearest neighbor. It lists apps that already have a window, then drills into that app's windows by title and workspace. [Quick Apps](https://plugins.omarchy.org/plugin.html?id=andean-bridge.quick-apps) can launch or focus a learned set of favorites, one window per app.

App Focus is the named hotkey on top of that. You type `obsidian`, `vscode`, or `tmux`. A missing Obsidian, VS Code, or Tmux is launched. A window on a hidden scratchpad is revealed before focus. Several windows of one app, including ones you cannot see, get a screenshot each (`grim -T` captures the window's own surface) and you pick on the second step. Tmux is recognized from the terminal's process tree, so those windows are not lumped in with every other terminal.

## Install

Requires Omarchy on the Quickshell shell, Hyprland 0.56 or newer, `grim` 1.5 or newer, and ImageMagick (`magick`) for a placeholder when a capture fails.

```bash
omarchy plugin add https://github.com/lateralcoders/omarchy-app-focus.git --enable
```

Check that the key you want is free:

```bash
omarchy menu keybindings --print
```

Add the bind from `examples/bindings.lua` to `~/.config/hypr/bindings.lua`. Hyprland reloads on save. Confirm it with:

```bash
hyprctl reload
hyprctl configerrors
```

Open it without a key:

```bash
omarchy-shell shell toggle io.github.lateralcoders.app-focus
```

## Use

| Key | Apps | Windows |
| --- | --- | --- |
| Type | Filter the list | |
| Up / Down | Move | |
| Left / Right | | Move between screenshots |
| Enter | Focus one window, launch if none are open, or open screenshots when there are several | Focus the screenshot in front |
| Click a row | Same as Enter | First click selects, second click focuses |
| Click the large screenshot | | Focus it |
| Esc | Clear the filter, then close | Back to the app list |
| Click outside | Close | Close |

Enter on an empty filter repeats the last app. The list puts that app first. Each row shows the app's desktop icon. Tmux uses the terminal icon, because those windows are the terminal. A missing icon falls back to the app's initial.

## Launch commands

Stock launches:

| Name | Command |
| --- | --- |
| Obsidian | `uwsm-app -- obsidian` |
| VS Code | `uwsm-app -- code` |
| Tmux | `omarchy-launch-terminal-tmux` |

Replace any of them in `~/.config/omarchy-switcher/launches.json`. Each value is an argv list. The same file is read by the separate command-line switcher:

```json
{
  "tmux": ["/home/you/.config/tmux/launch-work-view.sh"]
}
```

Other apps are listed only while they have a window. They are not launched from here.

## Remove

```bash
omarchy plugin remove io.github.lateralcoders.app-focus
```

Delete the bind from `~/.config/hypr/bindings.lua` yourself. The plugin never writes that file. `launches.json` is left in place.

## License

MIT. Copyright 2026 Zute Predictive.
