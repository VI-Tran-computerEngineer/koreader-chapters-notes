-- Event Handler - Handle book finished event for auto-sync

local logger = require("logger")
local _ = require("gettext")

local Events = {}
Events.__index = Events

function Events:new(plugin)
    local o = setmetatable({}, self)
    o.plugin = plugin
    return o
end

-- Handle end of book event
function Events:onEndOfBook()
    local Config = require("lib/config")
    Config:load()
    
    -- Check if auto-sync is enabled
    if not Config:get("auto_sync") then
        return
    end
    
    -- Check if we have required settings
    local notion_token = Config:get("notion_token")
    local notion_database_id = Config:get("notion_database_id")
    
    if not notion_token or notion_token == "" then
        logger.info("NotesSync: Auto-sync skipped - Notion token not configured")
        return
    end
    
    if not notion_database_id or notion_database_id == "" then
        logger.info("NotesSync: Auto-sync skipped - Notion database ID not configured")
        return
    end
    
    -- Trigger sync
    logger.info("NotesSync: Auto-syncing notes to Notion on book finish")
    
    -- Use UIManager to schedule sync (non-blocking)
    local UIManager = require("ui/uimanager")
    UIManager:scheduleIn(1, function()
        if self.plugin and self.plugin.syncToNotion then
            self.plugin:syncToNotion(true) -- true = silent mode (no UI feedback)
        end
    end)
end

return Events
