-- Configuration wrapper using KOReader persistent settings

local Config = {
    defaults = {
        notion_token = "",
        notion_database_id = "",
        auto_sync = false,
        export_path = "/mnt/onboard/.koreader/notes",
    }
}

-- Lazy initialization of SETTINGS to avoid G_reader_settings being nil at load time
local SETTINGS = nil
local function get_settings()
    if not SETTINGS then
        SETTINGS = G_reader_settings:open("notes_sync")
    end
    return SETTINGS
end

function Config:load()
    self.values = {}
    for k, def in pairs(self.defaults) do
        local v = get_settings():readSetting(k)
        if v == nil then v = def end
        self.values[k] = v
    end
end

function Config:get(key)
    return self.values[key]
end

function Config:set(key, value)
    self.values[key] = value
    get_settings():saveSetting(key, value)
end

return Config
