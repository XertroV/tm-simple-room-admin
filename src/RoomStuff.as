void _SetTimeLimit(int64 time) {
    auto room = _GetRoomAndLoad(GUI::brmSI.clubId, GUI::brmSI.roomId);
    GUI::AddLoadingMsg("Saving Room.");
    room.SetTimeLimit(time);
    room.SaveRoom();
    GUI::AddLoadingMsg("Set Time Limit: Done.");
}

void _AddTimeLimit(int64 time) {
    auto room = _GetRoomAndLoad(GUI::brmSI.clubId, GUI::brmSI.roomId);
    GUI::AddLoadingMsg("Saving Room.");
    room.SetTimeLimit(room.GetTimeLimit() + time);
    room.SaveRoom();
    GUI::AddLoadingMsg("Add time to time limit: Done.");
}

void _SetTimeRemaining(int64 time) {
    auto room = _GetRoomAndLoad(GUI::brmSI.clubId, GUI::brmSI.roomId);
    GUI::AddLoadingMsg("Saving Room.");
    auto rd = MLFeed::GetRaceData_V4();
    room.SetTimeLimit(time + 1 + rd.Rules_TimeElapsed / 1000);
    room.SaveRoom();
    GUI::AddLoadingMsg("Set time remaining: Done.");
}

// todo: support royal TA etc
BRM::IRoomSettingsBuilder@ _GetRoomAndLoad(int clubId, int roomId) {
    GUI::AddLoadingMsg("Getting current room settings.");
    auto room = BRM::CreateRoomBuilder(clubId, roomId);
    room.LoadCurrentSettingsAsync();
    if (room.GetMode() != BRM::GameMode::TimeAttack) throw("Room is not in TimeAttack mode.");
    return room;
}

void _SetNextMap(NextMapParams@ params) {
    auto rd = MLFeed::GetRaceData_V4();

    auto room = _GetRoomAndLoad(params.clubId, params.roomId);

    GUI::AddLoadingMsg("Adding map & updating settings.");
    if (params.exclusiveMode) {
        room.SetMaps({params.uid});
    } else {
        InsertMapToRoomNext(room, params.uid);
    }
    auto tmpTimeLimitSecs = rd.Rules_TimeElapsed / 1000 + 1 + params.moveOnInSec;
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
    int uidIx = roomMapIds.Find(uid);

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
        if (uidIx != -1) {
            roomMapIds.RemoveAt(uidIx + 1);
        }
    } else {
        if (andRemoveCurrent) {
            roomMapIds.RemoveAt(foundIx);
            if (foundIx < uidIx) {
                uidIx--;
            }
        }
        if (uidIx != -1) {
            roomMapIds.RemoveAt(uidIx);
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



void _MoveMapNext(int clubId, int roomId, const string &in uid) {
    auto room = _GetRoomAndLoad(clubId, roomId);
    InsertMapToRoomNext(room, uid);
    room.SaveRoom();
    GUI::AddLoadingMsg("Map moved to next: Done.");
}

void _RemoveMapFromList(int clubId, int roomId, const string &in uid) {
    auto room = _GetRoomAndLoad(clubId, roomId);
    auto roomMapIds = room.GetMapUids();
    auto ix = roomMapIds.Find(uid);
    if (ix != -1) {
        roomMapIds.RemoveAt(ix);
        room.SetMaps(roomMapIds);
        room.SaveRoom();
        GUI::AddLoadingMsg("Map removed from list: Done.");
    } else {
        GUI::AddLoadingMsg("Map not found in list.");
    }
}

void _AddMapToList(int clubId, int roomId, const string &in uid, bool asNext) {
    auto room = _GetRoomAndLoad(clubId, roomId);
    auto roomMapIds = room.GetMapUids();
    auto rd = MLFeed::GetRaceData_V4();
        if (roomMapIds.Find(uid) == -1) {
            if (asNext) {
                InsertMapToRoomNext(room, uid, false);
            } else {
                if (roomMapIds[roomMapIds.Length - 1] == rd.Map) {
                    roomMapIds.InsertAt(0, uid);
                } else {
                    roomMapIds.InsertLast(uid);
                }
                room.SetMaps(roomMapIds);
            }
            room.SaveRoom();
            GUI::AddLoadingMsg("Map added to list: Done.");
        } else {
            GUI::AddLoadingMsg("Map already in list.");
        }
}
