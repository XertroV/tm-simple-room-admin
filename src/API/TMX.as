namespace TMX {
    const string TMX_MAPS_BASE_URL = "https://trackmania.exchange/api/maps?";
    const string TMX_MAPS_FIELDS = "fields=MapUid,MapId,Name,GbxMapName,Tags,MapType,VehicleName";

    Json::Value@ GetMap(int tmxId) {
        auto url = TMX_MAPS_BASE_URL + string::Join({TMX_MAPS_FIELDS, MapIds({tostring(tmxId)}), Count(1)}, "&");
        trace("Requesting map info from TMX: " + url);
        Net::HttpRequest@ req = Net::HttpGet(url);
        while (!req.Finished()) yield();
        if (req.ResponseCode() != 200) {
            throw("Failed to get map uid from tmx id: " + req.ResponseCode());
        }
        auto json = req.Json();
        if (json is null) throw("Failed to parse TMX Maps response json");
        if (json.GetType() != Json::Type::Object) throw("Expected TMX Maps response json object; got: " + Json::Write(json));
        auto results = json["Results"];
        if (results.GetType() != Json::Type::Array) throw("Expected TMX Map response json .Results to be an array; got: " + Json::Write(results));
        if (results.Length == 0) throw("No results found for tmx id: " + tmxId);
        auto result = results[0];
        if (result.GetType() != Json::Type::Object) throw("Expected tmx map to be a json object; got: " + Json::Write(result));
        return result;
    }


    string Count(int c) {
        return "count=" + c;
    }

    string MapIds(string[]@ ids) {
        return "id=" + string::Join(ids, ",");
    }
}
