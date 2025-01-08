void _SetTimeLimit(int64 time) {
    // auto brm = BRM::Get(GetApp());
    // if (brm is null) return;
    // brm.SetTimeLimit(time);
}

void _AddTimeLimit(int64 time) {
    // auto brm = BRM::Get(GetApp());
    // if (brm is null) return;
    // brm.AddTimeLimit(time);
}

void _SetTimeRemaining(int64 time) {
    // auto brm = BRM::Get(GetApp());
    // if (brm is null) return;
    // brm.SetTimeRemaining(time);
}

void _SetNextMap(NextMapParams@ params) {
    auto rd = MLFeed::GetRaceData_V4();
    GUI::AddLoadingMsg("Getting current room settings.");
    auto room = BRM::CreateRoomBuilder(params.clubId, params.roomId);
    room.LoadCurrentSettingsAsync();
    if (room.GetMode() != BRM::GameMode::TimeAttack) throw("Room is not in TimeAttack mode.");
    GUI::AddLoadingMsg("Adding map & updating settings.");
    if (params.exclusiveMode) {
        room.SetMaps({params.uid});
    } else {
        InsertMapToRoomNext(room, params.uid);
    }
    auto tmpTimeLimitSecs = rd.Rules_MillisSinceStart / 1000 + 1 + params.moveOnInSec;
    room.SetTimeLimit(tmpTimeLimitSecs);
    dev_trace('tmpTimeLimitSecs: ' + tmpTimeLimitSecs);
    GUI::AddLoadingMsg("Saving room settings.");
    room.SaveRoom();
    GUI::AddLoadingMsg("Waiting for round to end.");
    AwaitEndOfRound(params.moveOnInSec * 1000 + 5000);
    GUI::AddLoadingMsg("Setting Time Limit: " + params.timeLimit);
    room.SetTimeLimit(params.timeLimit);
    room.SaveRoom();
    GUI::AddLoadingMsg("Set Next Map: Done.");
}

void InsertMapToRoomNext(BRM::IRoomSettingsBuilder@ room, const string &in uid, bool andRemoveCurrent = false) {
    auto roomMapIds = room.GetMapUids();
    if (roomMapIds.Length == 0) {
        room.SetMaps({uid});
        return;
    }

    auto rd = MLFeed::GetRaceData_V4();
    auto listUids = MLFeed::Get_MapListUids_Receiver();
    auto expectedIx = listUids.MapOrigIxInList;
    int foundIx = -1;
    int mapRealIx = -1;

    if (int(roomMapIds.Length) >= expectedIx && roomMapIds[expectedIx] == rd.Map) {
        mapRealIx = foundIx = expectedIx;

    } else {
        mapRealIx = roomMapIds.Find(rd.Map);
        foundIx = expectedIx < int(roomMapIds.Length) ? expectedIx : mapRealIx;
        if (foundIx == -1) { foundIx = expectedIx; }
    }

    if (foundIx == int(roomMapIds.Length) - 1 && andRemoveCurrent) {
        roomMapIds.RemoveLast();
        roomMapIds.InsertAt(0, uid);
    } else {
        if (andRemoveCurrent) {
            roomMapIds.RemoveAt(foundIx);
        }
        roomMapIds.InsertAt(foundIx + 1, uid);
    }
    room.SetMaps(roomMapIds);
}


class NextMapParams {
    int clubId, roomId, timeLimit, moveOnInSec;
    string uid;
    bool exclusiveMode;
    NextMapParams(int clubId, int roomId, const string &in uid, int timeLimit, int moveOnInSec, bool exclusiveMode) {
        this.clubId = clubId;
        this.roomId = roomId;
        this.uid = uid;
        this.timeLimit = timeLimit;
        this.moveOnInSec = moveOnInSec;
        this.exclusiveMode = exclusiveMode;
    }
}
