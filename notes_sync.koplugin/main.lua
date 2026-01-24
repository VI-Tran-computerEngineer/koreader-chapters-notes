-- Entry point for notes_sync.koplugin

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Config = require("lib/config")
local NotesManager = require("lib/notes_manager")
local ChapterParser = require("lib/chapter_parser")
local ExportHandler = require("lib/export_handler")
local NotionClient = require("lib/notion_client")
local Events = require("lib/events")
local GeneralNotesDialog = require("ui/general_notes_dialog")
local ChapterNotesDialog = require("ui/chapter_notes_dialog")
local SettingsDialog = require("ui/settings_dialog")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local FileManager = require("apps/filemanager/filemanager")
local _ = require("gettext")
local logger = require("logger")

-------------------------------------------------------
-- Plugin extends WidgetContainer for UI integration
-------------------------------------------------------
local NotesSync = WidgetContainer:extend{
    name = "NotesSync",
    is_doc_only = true, -- allow plugin only working when a document is open
}

-------------------------------------------------------
-- Plugin initialization entry point called by KOReader
-------------------------------------------------------
function NotesSync:init()
    Config:load()
    
    -- Initialize event handler
    self.events = Events:new(self)
    
    -- Register plugin to main menu
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

-------------------------------------------------------
-- Handle end of book event (called by KOReader framework)
-------------------------------------------------------
function NotesSync:onEndOfBook()
    if self.events then
        self.events:onEndOfBook()
    end
end

-------------------------------------------------------
-- Get current document file path
-------------------------------------------------------
function NotesSync:getCurrentDocument()
    if not self.ui or not self.ui.document then
        return nil
    end
    return self.ui.document.file
end

-------------------------------------------------------
-- Initialize managers for current document
-------------------------------------------------------
function NotesSync:getManagers()
    local file_path = self:getCurrentDocument()
    if not file_path then
        return nil, nil, nil, nil
    end
    
    local notes_manager = NotesManager:new(file_path)
    local chapter_parser = ChapterParser:new(self.ui.document)
    local export_handler = ExportHandler:new(notes_manager, chapter_parser, self.ui)
    
    return notes_manager, chapter_parser, export_handler, file_path
end

-------------------------------------------------------
-- Sync notes to Notion
-------------------------------------------------------
function NotesSync:syncToNotion(silent)
    local notes_manager, chapter_parser, _, file_path = self:getManagers()
    if not notes_manager then
        if not silent then
            self:show_message(_("No document open"))
        end
        return
    end
    
    Config:load()
    local notion_token = Config:get("notion_token")
    local notion_database_id = Config:get("notion_database_id")
    
    if not notion_token or notion_token == "" then
        if not silent then
            self:show_message(_("Notion API token not configured. Please set it in Settings."))
        end
        return
    end
    
    if not notion_database_id or notion_database_id == "" then
        if not silent then
            self:show_message(_("Notion database ID not configured. Please set it in Settings."))
        end
        return
    end
    
    -- Get book title
    local book_title = "Unknown Book"
    if self.ui.document then
        local doc_props = self.ui.document:getProps()
        if doc_props and doc_props.title then
            book_title = doc_props.title
        else
            -- Fallback to filename
            local filename = file_path:match("([^/]+)$")
            if filename then
                book_title = filename:gsub("%.[^%.]+$", "") -- Remove extension
            end
        end
    end
    
    -- Get notes data
    local general_notes = notes_manager:getGeneralNotes()
    local chapter_notes = notes_manager:getChapterNotes()
    
    -- Create Notion client and sync
    local notion_client = NotionClient:new(notion_token, notion_database_id)
    
    if not silent then
        self:show_message(_("Syncing to Notion..."))
    end
    
    -- Perform sync (async would be better, but for now we do it synchronously)
    local success, err = notion_client:syncNotes(book_title, general_notes, chapter_notes, chapter_parser)
    
    if not silent then
        if success then
            self:show_message(_("Successfully synced to Notion"))
        else
            self:show_message(_("Failed to sync to Notion: ") .. (err or _("Unknown error")))
        end
    end
end

-------------------------------------------------------
-- Export notes to file
-------------------------------------------------------
function NotesSync:exportNotes()
    local notes_manager, chapter_parser, export_handler, file_path = self:getManagers()
    if not notes_manager then
        self:show_message(_("No document open"))
        return
    end
    
    Config:load()
    local default_path = Config:get("export_path")
    
    -- Get book title for filename
    local book_title = "notes"
    if self.ui.document then
        local doc_props = self.ui.document:getProps()
        if doc_props and doc_props.title then
            book_title = doc_props.title:gsub("[^%w%s]", ""):gsub("%s+", "_")
        end
    end
    
    -- Default export path
    if not default_path or default_path == "" then
        default_path = "/mnt/onboard/.koreader/notes"
    end
    
    local default_file = default_path .. "/" .. book_title .. ".txt"
    
    -- Show file picker dialog
    local file_dialog = InputDialog:new{
        title = _("Export Notes"),
        input = default_file,
        input_hint = _("Enter file path"),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        file_dialog:onClose()
                    end,
                },
                {
                    text = _("Export"),
                    callback = function()
                        local export_path = file_dialog:getInputText()
                        file_dialog:onClose()
                        
                        self:show_message(_("Exporting notes..."))
                        
                        local success, err = export_handler:exportToFile(export_path)
                        
                        if success then
                            self:show_message(_("Notes exported successfully to: ") .. export_path)
                        else
                            self:show_message(_("Failed to export notes: ") .. (err or _("Unknown error")))
                        end
                    end,
                },
            },
        },
    }
    
    UIManager:show(file_dialog)
end

-------------------------------------------------------
-- Open general notes editor
-------------------------------------------------------
function NotesSync:openGeneralNotes()
    local notes_manager = NotesManager:new(self:getCurrentDocument())
    if not notes_manager then
        self:show_message(_("No document open"))
        return
    end
    
    local current_notes = notes_manager:getGeneralNotes()
    
    local dialog = GeneralNotesDialog:new{
        title = _("General Notes"),
        input = current_notes,
        save_callback = function(text)
            notes_manager:saveGeneralNotes(text)
            self:show_message(_("General notes saved"))
        end,
    }
    
    UIManager:show(dialog)
end

-------------------------------------------------------
-- Open chapter notes editor
-------------------------------------------------------
function NotesSync:openChapterNotes(chapter_num)
    local notes_manager, chapter_parser = self:getManagers()
    if not notes_manager then
        self:show_message(_("No document open"))
        return
    end
    
    local chapter = chapter_parser:getChapter(chapter_num)
    if not chapter then
        self:show_message(_("Chapter not found"))
        return
    end
    
    local chapter_data = notes_manager:getChapterNotesForChapter(chapter_num)
    
    -- Get highlights for this chapter
    local page_start, page_end = chapter_parser:getPageRangeForChapter(chapter_num)
    local highlights = {}
    
    if page_start then
        highlights = notes_manager:getHighlightsForPageRange(self.ui, page_start, page_end)
    end
    
    -- Merge stored highlight notes with current highlights
    if chapter_data.highlights then
        for _, stored_highlight in ipairs(chapter_data.highlights) do
            -- Try to match with current highlights by page
            local matched = false
            for _, highlight in ipairs(highlights) do
                if highlight.page_start == stored_highlight.page_start and
                   highlight.text == stored_highlight.text then
                    highlight.note = stored_highlight.note
                    matched = true
                    break
                end
            end
            if not matched then
                table.insert(highlights, stored_highlight)
            end
        end
    end
    
    local dialog = ChapterNotesDialog:new{
        title = _("Chapter Notes"),
        chapter_num = chapter_num,
        chapter_title = chapter.title,
        highlights = highlights,
        chapter_notes = chapter_data.notes or "",
        save_callback = function(notes_text)
            -- Save chapter notes and highlights
            notes_manager:updateChapterNotes(chapter_num, notes_text, highlights)
            self:show_message(_("Chapter notes saved"))
        end,
    }
    
    UIManager:show(dialog)
end

-------------------------------------------------------
-- Open settings dialog
-------------------------------------------------------
function NotesSync:openSettings()
    Config:load()
    
    local dialog = SettingsDialog:new{
        title = _("Notes Sync Settings"),
        notion_token = Config:get("notion_token"),
        notion_database_id = Config:get("notion_database_id"),
        auto_sync = Config:get("auto_sync"),
        export_path = Config:get("export_path"),
        save_callback = function(settings)
            Config:set("notion_token", settings.notion_token)
            Config:set("notion_database_id", settings.notion_database_id)
            Config:set("auto_sync", settings.auto_sync)
            Config:set("export_path", settings.export_path)
            self:show_message(_("Settings saved"))
        end,
    }
    
    UIManager:show(dialog)
end

-------------------------------------------------------
-- Build chapter notes menu items
-------------------------------------------------------
function NotesSync:buildChapterMenuItems()
    local notes_manager, chapter_parser = self:getManagers()
    if not chapter_parser then
        return {}
    end
    
    local chapters = chapter_parser:getChapters()
    local items = {}
    
    if #chapters > 0 then
        for i = 1, #chapters do
            local chapter = chapters[i]
            table.insert(items, {
                text = _("Chapter ") .. i .. ": " .. chapter.title,
                keep_menu_open = true,
                callback = function()
                    self:openChapterNotes(i)
                end,
            })
        end
    else
        -- No chapters found, but still allow creating chapter notes
        table.insert(items, {
            text = _("Chapter 1"),
            keep_menu_open = true,
            callback = function()
                self:openChapterNotes(1)
            end,
        })
    end
    
    return items
end

-------------------------------------------------------
-- Add plugin to KOReader's main menu
-- Called by KOReader during menu construction
-------------------------------------------------------
function NotesSync:addToMainMenu(menu_items)
    -- Capture self for use in callbacks
    local plugin = self
    
    -- Build chapter menu items
    local chapter_items = self:buildChapterMenuItems()
    
    -- Build "Open notes" submenu
    local open_notes_submenu = {
        {
            text = _("General notes"),
            keep_menu_open = true,
            callback = function()
                plugin:openGeneralNotes()
            end,
        },
    }
    
    -- Add chapter items
    for _, item in ipairs(chapter_items) do
        table.insert(open_notes_submenu, item)
    end
    
    menu_items.notes_sync = {
        text = _("Notes Sync"),
        sub_item_table = {
            {
                text = _("Sync"),
                keep_menu_open = true,
                callback = function()
                    plugin:syncToNotion(false)
                end,
            },
            {
                text = _("Export"),
                keep_menu_open = true,
                callback = function()
                    plugin:exportNotes()
                end,
            },
            {
                text = _("Open notes"),
                keep_menu_open = true,
                sub_item_table = open_notes_submenu,
            },
            {
                text = _("Settings"),
                keep_menu_open = true,
                callback = function()
                    plugin:openSettings()
                end,
            },
        }
    }
end

-------------------------------------------------------
-- Helper function to show messages
-------------------------------------------------------
function NotesSync:show_message(text)
    UIManager:show(InfoMessage:new{
        text = text,
        timeout = 2,
    })
end

require("insert_menu")

return NotesSync
