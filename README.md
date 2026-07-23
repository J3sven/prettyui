# PrettyUI

PrettyUI is a reusable component library for RuneScape Client API Lua plugins. It provides native-looking windows, panels, controls, layouts, tooltips, notifications, and a shared edge-mounted plugin ribbon built with RuneScape's own sprites and fonts.

Plugins can register a ribbon action with `prettyui.RibbonBar.Register`. Users can place the shared bar on the left, right, or top edge and optionally auto-hide it from its built-in settings button. Registration handles should be destroyed from the consuming plugin's `PluginShutdown` function.

The library is currently private and under active development. See `pretty-docs` for the full documentation and `prettyui-demo` for examples.

## Project structure

- `main.lua` assembles the public `PrettyUI` API and manages plugin lifecycle.
- `src/` contains UI components and public features.
- `src/core/` contains internal layout, input, palette, cursor, and sprite helpers.
- `resources/` contains plugin-owned assets.
