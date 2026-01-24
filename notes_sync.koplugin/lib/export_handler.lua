-- Export Handler - Export notes to file in specified format

local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local _ = require("gettext")

local ExportHandler = {}
ExportHandler.__index = ExportHandler

function ExportHandler:new(notes_manager, chapter_parser, ui)
    local o = setmetatable({}, self)
    o.notes_manager = notes_manager
    o.chapter_parser = chapter_parser
    o.ui = ui
    return o
end

-- Export notes to file in the specified format
function ExportHandler:exportToFile(file_path)
    if not file_path then
        return false, _("No file path specified")
    end
    
    -- Ensure directory exists
    local dir = file_path:match("^(.*)/")
    if dir and not lfs.attributes(dir, "mode") then
        local success, err = lfs.mkdir(dir)
        if not success then
            return false, _("Failed to create directory: ") .. (err or "unknown error")
        end
    end
    
    -- Build export content
    local content = self:buildExportContent()
    
    -- Write to file
    local file = io.open(file_path, "w")
    if not file then
        return false, _("Failed to open file for writing")
    end
    
    file:write(content)
    file:close()
    
    return true, nil
end

-- Build export content in the specified format
function ExportHandler:buildExportContent()
    local lines = {}
    
    -- General Notes section
    local general_notes = self.notes_manager:getGeneralNotes()
    if general_notes and general_notes ~= "" then
        table.insert(lines, "=== General Notes ===")
        table.insert(lines, general_notes)
        table.insert(lines, "")
    end
    
    -- Chapter notes sections
    local chapters = self.chapter_parser:getChapters()
    local chapter_notes_data = self.notes_manager:getChapterNotes()
    
    if #chapters > 0 then
        for i = 1, #chapters do
            local chapter = chapters[i]
            local chapter_data = chapter_notes_data[i]
            
            if chapter_data and (chapter_data.notes or (chapter_data.highlights and #chapter_data.highlights > 0)) then
                -- Chapter header
                table.insert(lines, "=== Chapter " .. i .. " " .. chapter.title .. " ===")
                
                -- Process highlights with notes
                if chapter_data.highlights and #chapter_data.highlights > 0 then
                    for _, highlight in ipairs(chapter_data.highlights) do
                        local page_range = self:formatPageRange(highlight.page_start, highlight.page_end)
                        local highlight_text = highlight.text or ""
                        local note_text = highlight.note or ""
                        
                        if highlight_text ~= "" or note_text ~= "" then
                            local line = "[" .. page_range .. "]"
                            
                            if highlight_text ~= "" then
                                line = line .. "```" .. highlight_text .. "```"
                            end
                            
                            if note_text ~= "" then
                                line = line .. "[" .. note_text .. "]"
                            end
                            
                            table.insert(lines, line)
                        end
                    end
                end
                
                -- General chapter notes (if any, not associated with specific highlights)
                if chapter_data.notes and chapter_data.notes ~= "" then
                    table.insert(lines, chapter_data.notes)
                end
                
                table.insert(lines, "")
            end
        end
    else
        -- No chapters, but might have highlights/notes stored differently
        -- Try to export all highlights from the book
        local all_highlights = self.notes_manager:getBookHighlights(self.ui)
        if #all_highlights > 0 then
            for _, highlight in ipairs(all_highlights) do
                local page_range = self:formatPageRange(highlight.page_start, highlight.page_end)
                local highlight_text = highlight.text or ""
                local note_text = highlight.note or ""
                
                if highlight_text ~= "" or note_text ~= "" then
                    local line = "[" .. page_range .. "]"
                    
                    if highlight_text ~= "" then
                        line = line .. "```" .. highlight_text .. "```"
                    end
                    
                    if note_text ~= "" then
                        line = line .. "[" .. note_text .. "]"
                    end
                    
                    table.insert(lines, line)
                end
            end
        end
    end
    
    return table.concat(lines, "\n")
end

-- Format page range as "page a-b" or "page a" if single page
function ExportHandler:formatPageRange(page_start, page_end)
    if not page_start then
        return "page ?"
    end
    
    if not page_end or page_start == page_end then
        return "page " .. page_start
    end
    
    return "page " .. page_start .. "-" .. page_end
end

return ExportHandler
