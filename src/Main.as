const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cog + Icons::Building;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void Render() {
    GUI::Render();
}
