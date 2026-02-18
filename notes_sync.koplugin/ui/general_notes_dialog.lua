-- General Notes Dialog - Editor for general book notes (styled like AI Assistant)

local Device = require("device")
local InputDialog = require("ui/widget/inputdialog")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local GeneralNotesDialog = InputDialog:extend{
    allow_newline = true,
    input_multiline = true,
    input_height = 10, -- Number of lines for the input area
    text_height = math.floor(10 * Screen:scaleBySize(20)), -- About 10 lines of text
}

function GeneralNotesDialog:init()
    -- Store save callback before init
    local save_callback = self.save_callback
    
    -- Set up the dialog similar to AI Assistant
    self.title = self.title or _("General Notes")
    self.description = self.description or _("Write your general notes for this book")
    self.input_hint = self.input_hint or _("Enter your notes here...")
    
    -- Set dialog size to match assistant.koplugin
    self.width = Screen:getWidth() * 0.8
    self.height = Screen:getHeight() * 0.4
    
    -- Initialize parent InputDialog
    InputDialog.init(self)
    
    -- Get the input widget
    self.note_input = self._input_widget
    
    -- Set initial text if provided
    if self.input and self.note_input then
        self.note_input:setText(self.input)
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

return GeneralNotesDialog
