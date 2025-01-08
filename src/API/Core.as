namespace Core {
    CNadeoServicesMap@ GetMapInfo(const string &in uid) {
        trace("Core::GetMapInfo: Requesting map info from NadeoServices: " + uid);
        auto menuApp = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp;
        auto req = menuApp.DataFileMgr.Map_NadeoServices_GetFromUid(menuApp.UserMgr.Users[0].Id, uid);
        while (req.IsProcessing) yield();
        if (req.HasSucceeded) {
            startnew(MenuDFM_ClearTaskSoon, uint64(req.Id.Value));
            return req.Map;
        }
        if (req.IsCanceled) {
            warn("Core::GetMapInfo: Request canceled");
            return null;
        }
        if (!req.HasFailed) throw("Request did not fail, but did not succeed either");
        warn("Core::GetMapInfo: Request failed: Ty = " + req.ErrorType + "; Code = " + req.ErrorCode + "; Desc = " + req.ErrorDescription);
        menuApp.DataFileMgr.TaskResult_Release(req.Id);
        return null;
    }
}


void MenuDFM_ClearTaskSoon(uint64 id) {
    yield(120);
    cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.DataFileMgr.TaskResult_Release(MwId(uint(id)));
}
