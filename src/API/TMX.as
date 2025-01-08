namespace TMX {
    const string TMX_MAPS_BASE_URL = "https://trackmania.exchange/api/maps?";
    const string TMX_MAPS_FIELDS = "fields=MapUid,MapId,OnlineMapId,Name,GbxMapName,Tags,MapType,VehicleName,ServerSizeExceeded";

    Json::Value@ GetMap(int tmxId) {
        // auto url = TMX_MAPS_BASE_URL + string::Join({TMX_MAPS_FIELDS, MapIds({tostring(tmxId)}), Count(1)}, "&");
        // trace("Requesting map info from TMX: " + url);
        // Net::HttpRequest@ req = Net::HttpGet(url);
        // while (!req.Finished()) yield();
        // if (req.ResponseCode() != 200) {
        //     throw("Failed to get map uid from tmx id: " + req.ResponseCode());
        // }
        // auto json = req.Json();
        // if (json is null) throw("Failed to parse TMX Maps response json");
        // if (json.GetType() != Json::Type::Object) throw("Expected TMX Maps response json object; got: " + Json::Write(json));
        // auto results = json["Results"];
        // if (results.GetType() != Json::Type::Array) throw("Expected TMX Map response json .Results to be an array; got: " + Json::Write(results));
        auto results = GetMapsById({tmxId});
        if (results.Length == 0) throw("No results found for tmx id: " + tmxId);
        auto result = results[0];
        if (result.GetType() != Json::Type::Object) throw("Expected tmx map to be a json object; got: " + Json::Write(result));
        return result;
    }

    Json::Value@ GetMapsById(int[]@ mapIds) {
        string[] _mapIds = {};
        for (uint i = 0; i < mapIds.Length; i++) {
            _mapIds.InsertLast(tostring(mapIds[i]));
        }
        auto url = TMX_MAPS_BASE_URL + string::Join({TMX_MAPS_FIELDS, MapIds(_mapIds), Count(mapIds.Length)}, "&");
        trace("Requesting maps info from TMX: " + url);
        Net::HttpRequest@ req = Net::HttpGet(url);
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            throw("Failed to get maps info from tmx ids: " + req.ResponseCode());
        }
        auto json = req.Json();
        if (json is null) throw("Failed to parse TMX Maps response json");
        if (json.GetType() != Json::Type::Object) throw("Expected TMX Maps response json object; got: " + Json::Write(json));
        auto results = json["Results"];
        if (results.GetType() != Json::Type::Array) throw("Expected TMX Maps response json .Results to be an array; got: " + Json::Write(results));
        return results;
    }

    Json::Value@ GetLatestMaps(uint count) {
        auto url = TMX_MAPS_BASE_URL + string::Join({TMX_MAPS_FIELDS, Count(count), OrderByNewestUpload}, "&");
        trace("Requesting latest maps info from TMX: " + url);
        Net::HttpRequest@ req = Net::HttpGet(url);
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            throw("Failed to get latest maps info: " + req.ResponseCode());
        }
        auto json = req.Json();
        if (json is null) throw("Failed to parse TMX Maps response json");
        if (json.GetType() != Json::Type::Object) throw("Expected TMX Maps response json object; got: " + Json::Write(json));
        auto results = json["Results"];
        if (results.GetType() != Json::Type::Array) throw("Expected TMX Maps response json .Results to be an array; got: " + Json::Write(results));
        return results;
    }

    // https://trackmania.exchange/api/meta/maporders
    string OrderByNewestUpload = "order1=6";

    string Count(int c) {
        return "count=" + c;
    }

    string MapIds(string[]@ ids) {
        return "id=" + string::Join(ids, ",");
    }

    int TmxMapIdMax = 250000;

    int[]@ GenRandomIds(uint count) {
        int[]@ ids = {};
        for (uint i = 0; i < count; i++) {
            ids.InsertLast(Math::Rand(1, TmxMapIdMax));
        }
        return ids;
    }

    Json::Value@ FindRandomMap() {
        int retriesLeft = 5;
        while (retriesLeft > 0) {
            retriesLeft--;
            auto randomIds = GenRandomIds(100);
            auto maps = TMX::GetMapsById(randomIds);
            for (uint i = 0; i < randomIds.Length; i++) {
                auto mapId = randomIds[i];
                auto map = GetMapWithId(maps, mapId);
                if (map is null) continue;
                if (!string(map["MapType"]).Contains("TM_Race")) continue;
                if (!string(map["VehicleName"]).Contains("Character")) continue;
                if (map["OnlineMapId"].GetType() == Json::Type::Null) continue;
                if (bool(map["ServerSizeExceeded"])) continue;
                // todo: add other filters, possibly to request depending on them
                trace("Found random map @ " + i + ": " + int(map["MapId"]));
                return map;
            }
        }
        throw("Failed to find a random map");
        return null;
    }

    Json::Value@ GetMapWithId(Json::Value@ maps, int mapId) {
        for (uint i = 0; i < maps.Length; i++) {
            auto map = maps[i];
            if (int(map["MapId"]) == mapId) return map;
        }
        return null;
    }


    void OnPluginLaunch() {
        auto maps = TMX::GetLatestMaps(10);
        TmxMapIdMax = 218000;
        for (uint i = 0; i < maps.Length; i++) {
            int mapId = maps[i]["MapId"];
            TmxMapIdMax = Math::Max(TmxMapIdMax, mapId);
        }
    }
}
