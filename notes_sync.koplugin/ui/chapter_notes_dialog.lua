-- Chapter Notes Dialog - Editor for chapter-specific notes with highlights (styled like AI Assistant)

local InputDialog = require("ui/widget/inputdialog")
local TextWidget = require("ui/widget/textwidget")
local Font = require("ui/font")
local Size = require("ui/size")
local Screen = require("device").screen
local _ = require("gettext")

local ChapterNotesDialog = InputDialog:extend{
    allow_newline = true,
    input_multiline = true,
    input_height = 10, -- Number of lines for the input area
    text_height = math.floor(10 * Screen:scaleBySize(20)), -- About 10 lines of text
    chapter_num = 1,
    chapter_title = "",
    highlights = {},
    chapter_notes = "",
}

function ChapterNotesDialog:init()
    -- Store save callback before init
    local save_callback = self.save_callback
    
    -- Set title with chapter info
    local title = _("Chapter ") .. self.chapter_num .. ": " .. (self.chapter_title or "")
    self.title = title
    
    -- Build description with highlights info
    local description_parts = {}
    if self.highlights and #self.highlights > 0 then
        table.insert(description_parts, _("Highlights in this chapter:"))
        for i, highlight in ipairs(self.highlights) do
            if highlight.text and highlight.text ~= "" then
                local page_range = ""
                if highlight.page_start then
                    if highlight.page_end and highlight.page_start ~= highlight.page_end then
                        page_range = string.format(" [page %d-%d]", highlight.page_start, highlight.page_end)
                    else
                        page_range = string.format(" [page %d]", highlight.page_start)
                    end
                end
                local highlight_preview = highlight.text
                if #highlight_preview > 50 then
                    highlight_preview = highlight_preview:sub(1, 50) .. "..."
                end
                table.insert(description_parts, string.format("• %s%s", highlight_preview, page_range))
            end
        end
        table.insert(description_parts, "")
        table.insert(description_parts, _("Write your chapter notes below:"))
    else
        table.insert(description_parts, _("Write your notes for this chapter:"))
    end
    
    self.description = table.concat(description_parts, "\n")
    self.input_hint = _("Enter your chapter notes here...")
    
    -- Set dialog size to match assistant.koplugin
    self.width = Screen:getWidth() * 0.8
    self.height = Screen:getHeight() * 0.4
    
    -- Initialize parent InputDialog
    InputDialog.init(self)
    
    -- Get the input widget
    self.note_input = self._input_widget
    
    -- Set initial text for chapter notes
    if self.chapter_notes and self.note_input then
        self.note_input:setText(self.chapter_notes)
    end
    
    -- Override OK button to call our save callback
    if self.button_table then
        for _, button_row in ipairs(self.button_table) do
            for _, button in ipairs(button_row) do
                if button.id == "ok" then
                    local old_callback = button.callback
                    button.callback = function()
                        if save_callback and self.note_input then
                            local text = self.note_input:getText()
                            save_callback(text)
                        end
                        if old_callback then
                            old_callback()
                        end
                    end
                end
            end
        end
    end
end

return ChapterNotesDialog
