namespace GUI {
    [Setting hidden]
    bool windowOpen = true;

    // input vars
    [Setting hidden]
    int m_moveOnInSec = 2;
    [Setting hidden]
    int m_defaultTimeLimit = 600;
    [Setting hidden]
    bool m_exclusiveMode = false;
    string m_nextMapId;

    // clean vars updated when changing map
    string nextMapName;
    string nextMapUrl;
    string nextMapUid;

    int64 rules_EndTime;

    Tab@[]@ tabs = CreateAllTabs();

    Tab@[]@ CreateAllTabs() {
        Tab@[]@ r = {};
        // r.InsertLast(MapsTab());
        return r;
    }

    void Render() {
        if (!windowOpen) return;
        if (UI::Begin(PluginName, windowOpen, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize)) {
            // UI::SeparatorText("Simple Room Admin");
            PushInnerWindowStyles();
            RenderTabs();

            if (IsLoading) {
                UI::SeparatorText("Loading");
                for (uint i = opInProgInfo.Length; i > 0; i--) {
                    UI::TextWrapped(tostring(i) + ". \\$i" + opInProgInfo[i - 1]);
                }
            }

            if (_failed) {
                UI::SeparatorText("Failed");
                UI::TextWrapped("\\$i\\$fa6" + _failureMsg);
            }

            PopInnerWindowStyles();
        }
        UI::End();
    }

    void RenderTabs() {
        UI::BeginTabBar("sra-tabs");

        _TabItem("Next Map", RenderNextMap);
        _TabItem("Current Map", RenderCurrRound);
        _TabItem("Maps", RenderAddMap);

        UI::EndTabBar();
    }

    bool _TabItem(const string &in name, CoroutineFunc@ render, int flags = UI::TabItemFlags::NoCloseWithMiddleMouseButton) {
        if (UI::BeginTabItem(name, flags)) {
            UI::BeginDisabled(IsLoading);
            render();
            UI::EndDisabled();
            UI::EndTabItem();
            return true;
        }
        return false;
    }

    void Render_NotInServerRoom() {
        UI::Text("\\$iLoading or not in room");
    }

    void Render_NotClubAdmin() {
        UI::Text("\\$iNot Club Admin");
    }

    BRM::ServerInfo@ brmSI;

    BRM::ServerInfo@ GetBrmSiOrRenderMsg() {
        @brmSI = BRM::GetCurrentServerInfo(GetApp(), false);
        if (brmSI is null) {
            Render_NotInServerRoom();
            return null;
        }
        if (!brmSI.isAdmin) {
            Render_NotClubAdmin();
            return null;
        }
        return brmSI;
    }

    void Render_AddMap() {
        m_nextMapId = UI::InputText("UID or TMX Map ID", m_nextMapId);
        AddSimpleTooltip("Valid formats: Map UID, TMX Map ID, TMX URL, trackmania.io URL.");

        TryValidateNextMapParamSet();
        UI::BeginDisabled(!IsNextMapParamSetValid);
        UI::AlignTextToFramePadding();
        UI::Text("Add Map:");
        UI::SameLine();
        if (UI::Button("as Next")) {
            startnew(AddMapToListNext_Async);
        }
        UI::SameLine();
        if (UI::Button("to End")) {
            startnew(AddMapToListEnd_Async);
        }
        UI::EndDisabled();

        // UI::SameLine();
        UI::AlignTextToFramePadding();
        if (!IsNextMapParamSetValid) {
            UI::TextWrapped("\\$i\\$b83Invalid: " + NextMapParamSetInvalidReason);
        } else {
            DrawMapParamValid();
        }

    }

    void RenderNextMap() {
        if (GetBrmSiOrRenderMsg() is null) return;
        auto rd = MLFeed::GetRaceData_V4();
        UI::SeparatorText("Set Next Map");
        m_nextMapId = UI::InputText("UID or TMX Map ID", m_nextMapId);
        AddSimpleTooltip("Valid formats: Map UID, TMX Map ID, TMX URL, trackmania.io URL.");
        m_moveOnInSec = Math::Max(UI::InputInt("Move on in (sec)", m_moveOnInSec), 1);
        Render_MoveOnInSecParse("New time left", m_moveOnInSec);
        m_defaultTimeLimit = ClampDefaultTimeLimit(UI::InputInt("Default time limit (sec)", m_defaultTimeLimit), m_defaultTimeLimit);
        Render_MoveOnInSecParse("Default time limit", m_defaultTimeLimit);

        m_exclusiveMode = UI::Checkbox("Exclusive Mode", m_exclusiveMode);
        AddSimpleTooltip("If enabled, existing maps will be removed from the map list, so the next map is the only map. This is more reliable since we'll never change to the wrong map. Enable this if maps come out of order.");

        TryValidateNextMapParamSet();
        UI::BeginDisabled(!IsNextMapParamSetValid);
        if (UI::Button("Go!")) {
            startnew(SetNextMap_Async);
        }
        UI::EndDisabled();
        UI::SameLine();
        UI::Text("or");
        UI::SameLine();
        if (UI::Button("Random")) {
            startnew(SetNextMapRandom_Async);
        }

        UI::AlignTextToFramePadding();
        if (!IsNextMapParamSetValid) {
            UI::TextWrapped("\\$i\\$b83Invalid: " + NextMapParamSetInvalidReason);
        } else {
            DrawMapParamValid();
        }
    }

    void RenderAddMap() {
        if (GetBrmSiOrRenderMsg() is null) return;
        UI::SeparatorText("Add Map");
        Render_AddMap();
        UI::SeparatorText("Map List");
        Render_MapList();
    }

    void RenderCurrRound() {
        if (GetBrmSiOrRenderMsg() is null) return;
        UI::SeparatorText("Current Map");
        Render_CurrentMapInfo();
        UI::SeparatorText("Round Time");
        Render_CurrentMapRoundInfo();
    }

    bool _paramsValid;
    string _paramsInvalidReason;
    MapType _paramsValidMapLinkTy;
    int parsedTmxId;
    string parsedMapUid;

    bool TryValidateNextMapParamSet() {
        auto _input = m_nextMapId.Trim();

        if (_input.Length == 0) return _ParamsInvalid("No map ID");
        if (ValidateTmxId(_input)) return _ParamsValid(MapType::TMX_ID);
        if (_input.Length < 8) return _ParamsInvalid("Invalid TMX ID (input length => TMX ID)");
        if (_input.Length <= 27) {
            if (ValidateMapUid(_input)) return _ParamsValid(MapType::Map_UID);
            return _ParamsInvalid("Invalid Map UID (input length => Map UID)");
        }
        if (_input.Contains("trackmania.exchange")) {
            if (ValidateTmxLink(_input)) return _ParamsValid(MapType::TMX_Link);
            return _ParamsInvalid("Invalid TMX Link");
        }
        if (_input.Contains("trackmania.io")) {
            if (ValidateTmioLink(_input)) return _ParamsValid(MapType::TmIo_Link);
            return _ParamsInvalid("Invalid trackmania.io Link");
        }
        if (_input.StartsWith("https:") && ContainsMapUid(_input)) return _ParamsValid(MapType::Other_Link_UID);
        return _ParamsInvalid("Invalid input. (Unknown type)");
    }

    bool _ParamsInvalid(const string &in reason) {
        _paramsValid = false;
        _paramsValidMapLinkTy = MapType::None;
        _paramsInvalidReason = reason;
        return false;
    }

    bool _ParamsValid(MapType type) {
        _paramsValid = true;
        _paramsValidMapLinkTy = type;
        _paramsInvalidReason = "";
        switch (type) {
            case MapType::TMX_Link:
            case MapType::TMX_ID:
                parsedTmxId = CleanAndExtractTmxId(m_nextMapId); break;
            case MapType::TmIo_Link:
            case MapType::Other_Link_UID:
            case MapType::Map_UID:
                parsedMapUid = CleanAndExtractMapUid(m_nextMapId); break;
            case MapType::None: break;
        }
        return true;
    }

    void DrawMapParamValid() {
        switch (_paramsValidMapLinkTy) {
            case MapType::TMX_Link:
            case MapType::TMX_ID:
                UI::Text("TMX ID: " + parsedTmxId); return;
            case MapType::TmIo_Link:
            case MapType::Other_Link_UID:
            case MapType::Map_UID:
                UI::Text("UID: " + parsedMapUid); return;
            case MapType::None: break;
        }
        UI::Text("Unknown");
    }

    bool get_IsNextMapParamSetValid() {
        return _paramsValid;
    }

    string get_NextMapParamSetInvalidReason() {
        return _paramsInvalidReason;
    }

    int ClampDefaultTimeLimit(int tl, int oldTl) {
        if (tl != -1 && tl < 10) {
            if (tl >= 0 && oldTl < 10) return 10;
            return -1;
        }
        return tl;
    }

    void AddMapToListNext_Async() {
        AddMapToList_Async(true);
    }
    void AddMapToListEnd_Async() {
        AddMapToList_Async(false);
    }
    void AddMapToList_Async(bool asNext) {
        AssertNotLoading();
        SetLoading(true, "Adding map to list...");
        try {
            SNM_ConvertMapToUid();
            SNM_GetMapInfoForUid();
            _AddMapToList(brmSI.clubId, brmSI.roomId, nextMapUid, asNext);
            sleep(1000);
            InvalidateAndRefreshMapList();
        } catch {
            ReportFailure("AddMapToList_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void SetNextMap_Async() {
        AssertNotLoading();
        SetLoading(true, "Setting next map...");
        try {
            SNM_ConvertMapToUid();
            SNM_GetMapInfoForUid();
            _SetNextMap(NextMapParams(brmSI.clubId, brmSI.roomId, nextMapUid, m_defaultTimeLimit, m_moveOnInSec, m_exclusiveMode));
            // wait for podium and stuff to happen.
            sleep(5000);
        } catch {
            ReportFailure("SetNextMap_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void SetNextMapRandom_Async() {
        AssertNotLoading();
        SetLoading(true, "Setting next map to random...");
        try {
            SNM_GetRandomMapInfos();
            SNM_GetMapInfoForUid();
            _SetNextMap(NextMapParams(brmSI.clubId, brmSI.roomId, nextMapUid, m_defaultTimeLimit, m_moveOnInSec, m_exclusiveMode));
            // wait for podium and stuff to happen.
            sleep(5000);
        } catch {
            ReportFailure("SetNextMapRandom_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void SNM_GetRandomMapInfos() {
        UpdateFromTmxMapInfo(TMX::FindRandomMap());
        AddLoadingMsg("Loading: " + tostring(int(tmxMapInfo["MapId"])));
    }

    Json::Value@ tmxMapInfo;
    void UpdateFromTmxMapInfo(Json::Value@ j) {
        @tmxMapInfo = j;
        nextMapUid = tmxMapInfo["MapUid"];
        if (!string(tmxMapInfo["MapType"]).Contains("TM_Race")) {
            throw("Map type is not TM_Race. It was: " + string(tmxMapInfo["MapType"]));
        }
    }

    void SNM_ConvertMapToUid() {
        switch (_paramsValidMapLinkTy) {
            case MapType::TMX_Link:
            case MapType::TMX_ID:
                {
                    AddLoadingMsg("Getting map UID for TMX ID: " + parsedTmxId);
                    UpdateFromTmxMapInfo(TMX::GetMap(parsedTmxId));
                    trace("TMX Map Info for "+nextMapUid+": " + Json::Write(tmxMapInfo));
                    break;
                }
            case MapType::TmIo_Link:
            case MapType::Other_Link_UID:
            case MapType::Map_UID:
                nextMapUid = parsedMapUid; break;
            case MapType::None: throw("Unknown input type (tmx id, uid, link, etc)");
        }
    }

    void SNM_GetMapInfoForUid() {
        AddLoadingMsg("Getting map info"); // for UID: " + nextMapUid);
        auto mapInfo = Core::GetMapInfo(nextMapUid);
        if (mapInfo is null) {
            throw("Map not uploaded to Nadeo.");
        }
        if (!mapInfo.Type.Contains("TM_Race")) {
            throw("Map type is not TM_Race. It was: " + mapInfo.Type);
        }
        nextMapName = mapInfo.Name;
        nextMapUrl = mapInfo.FileUrl;
        if (nextMapUrl.Length > 0) {
            BRM::PreCacheMap(nextMapUrl);
        }
    }

    void SetTimeLimit_Async(int64 time) {
        AssertNotLoading();
        SetLoading(true, "Setting time limit: = " + Time::Format(time*1000, false));
        try {
            _SetTimeLimit(time);
        } catch {
            ReportFailure("SetTimeLimit_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void AddTimeLimit_Async(int64 time) {
        AssertNotLoading();
        SetLoading(true, "Adding time: + " + Time::Format(time*1000, false));
        try {
            _AddTimeLimit(time);
        } catch {
            ReportFailure("AddTimeLimit_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void SetTimeRemaining_Async(int64 time) {
        AssertNotLoading();
        SetLoading(true, "Setting time remaining: = " + Time::Format(time*1000, false));
        try {
            _SetTimeRemaining(time);
        } catch {
            ReportFailure("SetTimeRemaining_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void Render_MoveOnInSecParse(const string &in label, int secs) {
        auto mins = secs / 60;
        auto justSecs = secs % 60;
        float _indent = 16;
        UI::Indent(_indent);
            UI::Text(label + ": " + (secs < 0 ? "infinite" : mins + " m " + justSecs + " s"));
        UI::Unindent(_indent);
    }

    float col1Width;

    void Render_CurrentMapInfo() {
        col1Width = Draw::MeasureString("Time Left: ").x * 1.3;

        // map name, uid, elapsed, remaining; GameTime - StartTime
        auto map = GetCurrentMapInfo();
        if (map is null) {
            UI::Text("\\$i\\$f80No map info");
        } else {
            LabelCol2("Map", Text::OpenplanetFormatCodes(map.NameForUi), col1Width, false, true);
            LabelCol2("UID", map.MapUid, col1Width, true);
            if (ButtonSL("TM.IO")) {
                OpenBrowserURL("https://trackmania.io/#/leaderboard/" + map.MapUid + "?utm-source=simple-room-admin");
            }
            UI::Dummy(vec2());
        }
    }

    void Render_CurrentMapRoundInfo() {
        auto rd = MLFeed::GetRaceData_V4();

        LabelCol2("Elapsed", Time::Format(rd.Rules_TimeElapsed, true, true, false, true), col1Width);
        rules_EndTime = rd.Rules_EndTime;
        UI::SameLine();
        UI::Dummy(vec2(8, 0));
        UI::SameLine();
        UI::BeginChild("time-rem", vec2(0, 0), UI::ChildFlags::AlwaysAutoResize | UI::ChildFlags::AutoResizeX | UI::ChildFlags::AutoResizeY);
        LabelCol2("Remaining", (rules_EndTime < 0 ? "No Limit" : Time::Format(rd.Rules_TimeRemaining, true, true, false, true)), col1Width);
        UI::EndChild();

        UI::SeparatorText("Set Time Limit");

        UI::BeginDisabled(rd.Rules_EndTime < 0);
        if (ButtonSL("No Limit##set-lim")) {
            startnew(SetTimeLimit_Async, -1);
        }
        if (ButtonSL("+2 min##set-lim")) {
            startnew(AddTimeLimit_Async, 120);
        }
        if (ButtonSL("+5 m##set-lim")) {
            startnew(AddTimeLimit_Async, 300);
        }
        if (ButtonSL("+10 m##set-lim")) {
            startnew(AddTimeLimit_Async, 600);
        }
        if (UI::Button("+30 m##set-lim")) {
            startnew(AddTimeLimit_Async, 1800);
        }
        UI::EndDisabled();

        UI::SeparatorText("Set round to End In");

        // UI::AlignTextToFramePadding();
        // UI::Text("End in:");
        // UI::SameLine();

        if (ButtonSL("End in 2 min##end-in")) {
            startnew(SetTimeRemaining_Async, 120);
        }
        if (ButtonSL("5 m##end-in")) {
            startnew(SetTimeRemaining_Async, 300);
        }
        if (ButtonSL("10 m##end-in")) {
            startnew(SetTimeRemaining_Async, 600);
        }

        bool altDown = UI::IsKeyDown(UI::Key::LeftAlt);
        UI::BeginDisabled(!altDown);
        if (ButtonSL("10 s##end-in")) {
            startnew(SetTimeRemaining_Async, 10);
        }
        if (ButtonSL("1 s##end-in")) {
            startnew(SetTimeRemaining_Async, 1);
        }
        UI::EndDisabled();
        if (!altDown) {
            UI::SetCursorPos(UI::GetCursorPos() - vec2(4, 0));
            UI::TextDisabled(Icons::QuestionCircle);
            AddSimpleTooltip("Hold Alt to enable.");
        } else {
            UI::Dummy(vec2());
        }

    }


    void Render_MapList() {
        auto listUids = MLFeed::Get_MapListUids_Receiver();
        _CheckMapListStale();
        if (mapList_Uids.Length == 0) {
            UI::Text("\\$i< No maps >");
            return;
        }

        if (mapList_Uids.Length > 0 && mapList_Uids[0] == mapList_CachedFor) {
            UI::TextWrapped("\\$i\\$d95Warning: if the next map is the same as the current map, the server will go to the first map in the list.");
        }

        if (UI::Button("Refresh")) {
            InvalidateAndRefreshMapList();
        }
        if (UI::BeginChild("map-list", vec2(300, 0), UI::ChildFlags::AutoResizeY | UI::ChildFlags::AlwaysAutoResize)) {
            if (UI::BeginTable("##uids", 2, UI::TableFlags::SizingStretchSame)) {
                // UI::TableSetupColumn("UIDs");
                UI::TableSetupColumn("Names");
                UI::TableSetupColumn("Btns", UI::TableColumnFlags::WidthFixed, 110 * UI::GetScale());
                // UI::TableHeadersRow();
                int o = mapList_Slice_StartIx;
                int l = mapList_Uids.Length;

                UI::ListClipper c(mapList_Uids.Length);
                while (c.Step()) {
                    for (int i = c.DisplayStart; i < c.DisplayEnd; i++) {
                        UI::TableNextRow();
                        // UI::TableNextColumn();
                        // UI::Text(mapList_Uids[i]);
                        UI::TableNextColumn();
                        UI::AlignTextToFramePadding();
                        UI::Text(tostring(((i + o) % l) + 1) + ". " + Text::OpenplanetFormatCodes(mapList_Names[i]));
                        UI::TableNextColumn();
                        UI::BeginDisabled(mapList_Uids[i] == mapList_CachedFor);
                        if (UI::Button("Set Next##"+i)) {
                            startnew(SetNextMapUid_Async, mapList_Uids[i]);
                        }
                        UI::EndDisabled();
                        UI::SameLine();
                        if (UI::Button(Icons::Trash + "##"+i)) {
                            startnew(RemoveMapUid_Async, mapList_Uids[i]);
                        }
                    }
                }
                UI::EndTable();
            }
        }
        UI::EndChild();
    }

    void SetNextMapUid_Async(const string &in uid) {
        AssertNotLoading();
        SetLoading(true, "Setting map to be next...");
        try {
            _MoveMapNext(brmSI.clubId, brmSI.roomId, uid);
            sleep(1000);
            InvalidateAndRefreshMapList();
        } catch {
            ReportFailure("SetNextMapUid_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    void RemoveMapUid_Async(const string &in uid) {
        AssertNotLoading();
        SetLoading(true, "Removing map from list...");
        try {
            _RemoveMapFromList(brmSI.clubId, brmSI.roomId, uid);
            sleep(1000);
            InvalidateAndRefreshMapList();
        } catch {
            ReportFailure("RemoveMapUid_Async", getExceptionInfo());
        }
        SetLoading(false, "");
    }

    string mapList_CachedFor;
    string[] mapList_Uids;
    string[] mapList_Names;
    int mapList_Slice_StartIx;


    void _CheckMapListStale() {
        auto listUids = MLFeed::Get_MapListUids_Receiver();
        if (listUids.MapList_IsInProgress) return;
        if (listUids.MapOrigIxInListUid == mapList_CachedFor) return;
        auto rd = MLFeed::GetRaceData_V4();
        if (listUids.MapOrigIxInListUid != rd.Map) return;
        if (rd.Map.Length == 0) return;

        mapList_Names.RemoveRange(0, mapList_Names.Length);
        mapList_Uids.RemoveRange(0, mapList_Uids.Length);

        listUids.MapList_Request();
        startnew(_AwaitForUpdatedMapList).WithRunContext(Meta::RunContext::AfterScripts);
    }

    void InvalidateAndRefreshMapList() {
        mapList_CachedFor = "";
    }

    void _AwaitForUpdatedMapList() {
        auto listUids = MLFeed::Get_MapListUids_Receiver();
        while (listUids.MapList_IsInProgress) yield();
        mapList_CachedFor = listUids.MapOrigIxInListUid;
        for (uint i = 0; i < listUids.MapList_MapUids.Length; i++) {
            mapList_Uids.InsertLast(listUids.MapList_MapUids[i]);
            mapList_Names.InsertLast(listUids.MapList_Names[i]);
        }
        mapList_Slice_StartIx = listUids.Slice_StartIx;
    }


    // applies to inner window
    void PushInnerWindowStyles() {
        UI::PushItemWidth(140);
    }

    void PopInnerWindowStyles() {
        UI::PopItemWidth();
    }




    // void RenderTabs() {
    //     UI::BeginTabBar("sra-tabs");
    //     Tab@ tab;
    //     foreach (Tab@ tab in tabs) {
    //         tab.RenderTab();
    //     }
    //     UI::EndTabBar();
    // }





    bool operationInProgress = false;
    string[] opInProgInfo;
    bool _failed = false;
    string _failureMsg;

    bool get_IsLoading() {
        return operationInProgress;
    }

    string get_LoadingReason() {
        return opInProgInfo.Length == 0 ? "" : opInProgInfo[0];
    }

    void SetLoading(bool loading, const string &in reason) {
        operationInProgress = loading;
        opInProgInfo.RemoveRange(0, opInProgInfo.Length);
        if (loading) {
            opInProgInfo.InsertLast(reason);
            _failed = false;
            _failureMsg = "";
        }
    }

    void AddLoadingMsg(const string &in msg) {
        opInProgInfo.InsertLast(msg);
    }

    void AssertNotLoading() {
        if (IsLoading) throw("Currently loading, cannot start another operation");
    }

    void ReportFailure(const string &in funcName, const string &in msg) {
        NotifyError("Failed in " + funcName + ": " + msg);
        _failureMsg = msg;
        _failed = true;
    }
}



class Tab {
    string name;
    string _id;
    // bool open = true;

    Tab(const string &in name) {
        this.name = name;
        this._id = "##" + name;
    }

    void RenderTab() {
        if (UI::BeginTabItem(name, UI::TabItemFlags::NoCloseWithMiddleMouseButton)) {
            Render();
            UI::EndTabItem();
        }
    }

    void Render() {
        UI::Text("Override me. Hello, " + name);
    }
}
