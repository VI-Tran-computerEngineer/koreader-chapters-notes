-- Chapter Notes Dialog - Editor for chapter-specific notes with highlights

local Button = require("ui/widget/button")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputDialog = require("ui/widget/inputdialog")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local Font = require("ui/font")
local Size = require("ui/size")
local _ = require("gettext")
local logger = require("logger")

local ChapterNotesDialog = InputDialog:extend{
    allow_newline = true,
    title = _("Chapter Notes"),
    padding = 10,
    chapter_num = 1,
    chapter_title = "",
    highlights = {},
    chapter_notes = "",
}

function ChapterNotesDialog:init()
    InputDialog.init(self)
    
    -- Set title with chapter info
    self.title = _("Chapter ") .. self.chapter_num .. ": " .. (self.chapter_title or "")
    
    -- Create widgets for highlights display
    local highlight_widgets = {}
    
    if self.highlights and #self.highlights > 0 then
        -- Add heading for highlights
        table.insert(highlight_widgets, TextWidget:new{
            text = _("Highlights:"),
            face = Font:getFace("cfont", 18),
            padding = Size.padding.default,
        })
        
        -- Add each highlight
        for i, highlight in ipairs(self.highlights) do
            local page_range = ""
            if highlight.page_start then
                if highlight.page_end and highlight.page_start ~= highlight.page_end then
                    page_range = _(" [page ") .. highlight.page_start .. "-" .. highlight.page_end .. "]"
                else
                    page_range = _(" [page ") .. highlight.page_start .. "]"
                end
            end
            
            -- Highlight text
            if highlight.text and highlight.text ~= "" then
                local highlight_text = TextWidget:new{
                    text = "```" .. highlight.text .. "```" .. page_range,
                    face = Font:getFace("smallinfofont"),
                    padding = Size.padding.small,
                }
                table.insert(highlight_widgets, highlight_text)
            end
            
            -- Note for this highlight (if any)
            if highlight.note and highlight.note ~= "" then
                local note_text = TextWidget:new{
                    text = _("Note: ") .. highlight.note,
                    face = Font:getFace("smallinfofont"),
                    padding = Size.padding.small,
                }
                table.insert(highlight_widgets, note_text)
            end
        end
        
        -- Add separator
        table.insert(highlight_widgets, TextWidget:new{
            text = _("Chapter Notes:"),
            face = Font:getFace("cfont", 18),
            padding = Size.padding.default,
        })
    end
    
    -- Add highlight widgets before the input
    for _, widget in ipairs(highlight_widgets) do
        self:addWidget(widget)
    end
    
    -- Set initial text for chapter notes
    if self.chapter_notes then
        self._input_widget:setText(self.chapter_notes)
    end
end

function ChapterNotesDialog:onSave()
    if self.save_callback then
        self.save_callback(self._input_widget:getText())
    end
    self:onClose()
end

return ChapterNotesDialog
