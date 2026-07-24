# PrettyUI

PrettyUI is a reusable component library for RuneScape Client API Lua plugins. It provides native-looking windows, panels, controls, layouts, tooltips, notifications, and a shared edge-mounted plugin ribbon built with RuneScape's own sprites and fonts.

Plugins can register a ribbon action with `prettyui.RibbonBar.Register`. Users can place the shared bar on the left, right, or top edge and optionally auto-hide it from its built-in settings button. Registration handles should be destroyed from the consuming plugin's `PluginShutdown` function.

## Useful resourced
- [Documentation](https://prettyui.j3.gg/)
- [Demo Plugin](https://github.com/J3sven/prettyui-demo)
