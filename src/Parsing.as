enum MapType {
    None,
    TMX_ID,
    Map_UID,
    TMX_Link,
    TmIo_Link,
    Other_Link_UID
}

// const string TMX_ID_PATTERN = "[0-9][0-9]?[0-9]?[0-9]?[0-9]?[0-9]?[0-9]?";
const string TMX_ID_PATTERN = "[1-9][0-9]{0,6}";

bool ValidateTmxId(const string &in id) {
    if (id.Length >= 8) return false;
    if (id == "0") return false;
    return Regex::IsMatch(id, "^"+TMX_ID_PATTERN+"$");
}

bool ValidateMapUid(const string &in uid) {
    // between 25 and 27 characters only
    if (Math::Abs(int(uid.Length) - 26) > 1) return false;
    return Regex::IsMatch(uid, "^[a-zA-Z0-9_]+$");
}

bool ContainsMapUid(const string &in input) {
    return Regex::Contains(input, "[a-zA-Z0-9_]{25,27}");
}

bool ContainsTmxID(const string &in input) {
    return Regex::Contains(input, TMX_ID_PATTERN);
}

string ExtractMapUid(const string &in input) {
    auto match = Regex::Search(input, "[a-zA-Z0-9_]{25,27}");
    if (match.Length > 0) return match[0];
    return "";
}

string CleanAndExtractMapUid(const string &in input) {
    string _input = input.Trim();
    if (_input.Contains("trackmania.io/")) {
        auto parts = _input.Split("trackmania.io/", 2);
        if (parts.Length < 2) return "";
        _input = parts[1];
    }
    return ExtractMapUid(_input);
}

int ExtractTmxId(const string &in input) {
    auto match = Regex::Search(input, TMX_ID_PATTERN);
    if (match.Length > 0) {
        int64 val;
        if (Text::TryParseInt64(match[0], val, 10)) {
            return val;
        }
        return -1;
    }
    return -1;
}

int CleanAndExtractTmxId(const string &in input) {
    string _input = input.Trim();
    if (_input.Contains("trackmania.exchange/")) {
        auto parts = _input.Split("trackmania.exchange/", 2);
        if (parts.Length < 2) _input = parts[1];
    }
    return ExtractTmxId(_input);
}

bool ValidateTmxLink(const string &in link) {
    auto parts = link.Split("trackmania.exchange/", 2);
    if (parts.Length < 2) return false;
    return ContainsTmxID(parts[1]);
}

bool ValidateTmioLink(const string &in link) {
    auto parts = link.Split("trackmania.io/", 2);
    if (parts.Length < 2) return false;
    return ContainsMapUid(parts[1]);
}
