
void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text(msg);
        UI::EndTooltip();
    }
}

void CopyLabel(const string &in label, const string &in value) {
    UI::Text((label.Length > 0 ? label + ": " : "") + value);
    if (UI::IsItemHovered()) UI::SetMouseCursor(UI::MouseCursor::Hand);
    if (UI::IsItemClicked()) CopyToClipboardAndNotify(value);
}

void CopyToClipboardAndNotify(const string &in toCopy) {
    IO::SetClipboard(toCopy);
    Notify("Copied: " + toCopy);
}


void LabelCol2(const string &in label, const string &in text, float col1Width, bool copyable = false, bool wrapped = false) {
    UI::Text(label);
    UI::SameLine();
    auto pos = UI::GetCursorPos();
    pos.x = col1Width;
    UI::SetCursorPos(pos);
    if (copyable) CopyLabel("", text);
    else if (!wrapped) UI::Text(text);
    else UI::TextWrapped(text);
}

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

bool ButtonSL(const string &in label, vec2 size = vec2()) {
    bool clicked = UI::Button(label, size);
    UI::SameLine();
    return clicked;
}
