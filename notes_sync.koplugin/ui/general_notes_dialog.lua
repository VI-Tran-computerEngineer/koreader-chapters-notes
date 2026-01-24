-- General Notes Dialog - Full-screen text editor for general book notes

local Device = require("device")
local Font = require("ui/font")
local InputDialog = require("ui/widget/inputdialog")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local Screen = require("device").screen

local GeneralNotesDialog = InputDialog:extend{
    allow_newline = true,
    title = _("General Notes"),
    fullscreen = true,
}

function GeneralNotesDialog:init()
    -- Get screen dimensions
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    
    -- Set dimensions that fit within screen bounds
    -- Use 85% of screen to leave margins and avoid spillover
    self.width = math.floor(screen_width * 0.85)
    self.height = math.floor(screen_height * 0.80)
    
    -- Set reasonable padding
    self.padding = Size.padding.default
    
    -- Store save callback before init
    local save_callback = self.save_callback
    
    -- Initialize parent InputDialog
    InputDialog.init(self)
    
    -- Get the input widget and make it larger
    self.note_input = self._input_widget
    
    -- Override the input widget's dimensions to be much larger
    if self.note_input then
        -- Calculate input area size accounting for title, padding, and buttons
        local available_height = self.height - 120  -- Leave room for title and buttons
        local available_width = self.width - Size.padding.default * 4
        
        self.note_input.height = math.max(300, available_height)
        self.note_input.width = math.max(400, available_width)
        
        -- Use a readable font size
        self.note_input.face = Font:getFace("cfont", 18)
        
        -- Set initial text if provided
        if self.input then
            self.note_input:setText(self.input)
        end
    end
    
    -- Override OK button to call our save callback
    if self.button_table then
        for _, button_row in ipairs(self.button_table) do
            for _, button in ipairs(button_row) do
                if button.id == "ok" then
                    local old_callback = button.callback
                    button.callback = function()
                        if save_callback then
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

-- Override to handle fullscreen properly
function GeneralNotesDialog:onShow()
    UIManager:setDirty(nil, "ui")
    -- Focus the input
    if self.note_input then
        UIManager:nextTick(function()
            self.note_input:focus()
            if Device:hasKeyboard() or Device:hasScreenKB() then
                if not G_reader_settings:isFalse("virtual_keyboard_enabled") then
                    self.note_input:onShowKeyboard()
                end
            end
        end)
    end
end

return GeneralNotesDialog
