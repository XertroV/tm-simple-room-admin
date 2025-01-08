const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$ac4";
const string PluginIcon = Icons::Cog + Icons::BuildingO;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

void RenderInterface() {
    if (!Permissions::CreateClub()) return;
    GUI::Render();
}

/** Render function called every frame intended only for menu items in `UI`.
*/
void RenderMenu() {
    if (!Permissions::CreateClub()) return;
    if (UI::MenuItem(MenuTitle, "", GUI::windowOpen)) {
        GUI::windowOpen = !GUI::windowOpen;
    }
}
