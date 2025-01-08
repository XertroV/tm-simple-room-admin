CGameCtnChallengeInfo@ GetCurrentMapInfo() {
    auto map = GetApp().RootMap;
    if (map is null) return null;
    return map.MapInfo;
}

void AwaitEndOfRound(uint64 timeout = 15000) {
    auto start = Time::Now;
    auto app = GetApp();
    if (app.RootMap is null) return;
    auto mapIdV = app.RootMap.Id.Value;

    while (Time::Now < start + timeout) {
        if (app.RootMap is null) return;
        if (app.RootMap.Id.Value != mapIdV) return;
        auto pg = cast<CSmArenaClient>(app.CurrentPlayground);
        if (pg is null) return;
        if (pg.GameTerminals.Length == 0) return;
        auto gt = pg.GameTerminals[0];
        if (gt is null) return;
        auto seq = gt.UISequence_Current;
        if (seq == SGamePlaygroundUIConfig::EUISequence::Podium
            || seq == SGamePlaygroundUIConfig::EUISequence::UIInteraction
            || seq == SGamePlaygroundUIConfig::EUISequence::EndRound
            || seq == SGamePlaygroundUIConfig::EUISequence::None
            ) {
            return;
        }
        yield();
    }
    warn("Timeout waiting for podium");

}
