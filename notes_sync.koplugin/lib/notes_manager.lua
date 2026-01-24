-- Notes Manager - Core notes management using DocSettings API

local DocSettings = require("docsettings")
local logger = require("logger")

local NotesManager = {}
NotesManager.__index = NotesManager

function NotesManager:new(file_path)
    local o = setmetatable({}, self)
    o.file_path = file_path
    o.doc_settings = DocSettings:open(file_path)
    return o
end

-- Get general notes for the book
function NotesManager:getGeneralNotes()
    return self.doc_settings:readSetting("general_notes") or ""
end

-- Save general notes for the book
function NotesManager:saveGeneralNotes(text)
    self.doc_settings:saveSetting("general_notes", text)
    self.doc_settings:flush()
end

-- Get chapter notes (returns table indexed by chapter number)
function NotesManager:getChapterNotes()
    return self.doc_settings:readSetting("chapter_notes") or {}
end

-- Get notes for a specific chapter
function NotesManager:getChapterNotesForChapter(chapter_num)
    local chapter_notes = self:getChapterNotes()
    return chapter_notes[chapter_num] or { notes = "", highlights = {} }
end

-- Save notes for a specific chapter
function NotesManager:saveChapterNotes(chapter_num, chapter_data)
    local chapter_notes = self:getChapterNotes()
    chapter_notes[chapter_num] = chapter_data
    self.doc_settings:saveSetting("chapter_notes", chapter_notes)
    self.doc_settings:flush()
end

-- Update notes for a specific chapter (merges with existing)
function NotesManager:updateChapterNotes(chapter_num, notes_text, highlights)
    local existing = self:getChapterNotesForChapter(chapter_num)
    local updated = {
        notes = notes_text or existing.notes or "",
        highlights = highlights or existing.highlights or {}
    }
    self:saveChapterNotes(chapter_num, updated)
end

-- Get all highlights for the book
function NotesManager:getBookHighlights(ui)
    if not ui or not ui.highlight then
        return {}
    end
    
    local highlights = ui.highlight:getBookHighlights(self.file_path)
    if not highlights then
        return {}
    end
    
    -- Convert highlights to a more usable format
    local result = {}
    for _, highlight in ipairs(highlights) do
        table.insert(result, {
            text = highlight.text or "",
            page_start = highlight.pos0 and highlight.pos0.page or nil,
            page_end = highlight.pos1 and highlight.pos1.page or nil,
            note = highlight.note or "",
            datetime = highlight.datetime or nil
        })
    end
    
    return result
end

-- Get highlights for a specific page range (for chapter mapping)
function NotesManager:getHighlightsForPageRange(ui, page_start, page_end)
    local all_highlights = self:getBookHighlights(ui)
    local filtered = {}
    
    for _, highlight in ipairs(all_highlights) do
        if highlight.page_start and highlight.page_start >= page_start then
            if not page_end or (highlight.page_start <= page_end) then
                table.insert(filtered, highlight)
            end
        end
    end
    
    return filtered
end

return NotesManager
