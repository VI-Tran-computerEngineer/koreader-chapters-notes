-- Settings Dialog - Configure Notion API and export settings

local Button = require("ui/widget/button")
local FrameContainer = require("ui/widget/container/framecontainer")
local InputDialog = require("ui/widget/inputdialog")
local InputText = require("ui/widget/inputtext")
local ToggleSwitch = require("ui/widget/toggleswitch")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local Font = require("ui/font")
local Size = require("ui/size")
local _ = require("gettext")

local SettingsDialog = InputDialog:extend{
    title = _("Notes Sync Settings"),
    padding = 10,
}

function SettingsDialog:init()
    InputDialog.init(self)
    
    -- Notion API Token
    local token_label = TextWidget:new{
        text = _("Notion API Token:"),
        face = Font:getFace("cfont", 16),
    }
    
    self.token_field = InputText:new{
        width = self.width - Size.padding.default * 2 - Size.border.inputtext * 2 - 30,
        input = self.notion_token or "",
        focused = false,
        show_parent = self,
        parent = self,
        hint = _("Enter your Notion API token"),
        face = Font:getFace("cfont", 16),
    }
    
    -- Notion Database ID
    local db_label = TextWidget:new{
        text = _("Notion Database ID:"),
        face = Font:getFace("cfont", 16),
    }
    
    self.database_field = InputText:new{
        width = self.width - Size.padding.default * 2 - Size.border.inputtext * 2 - 30,
        input = self.notion_database_id or "",
        focused = false,
        show_parent = self,
        parent = self,
        hint = _("Enter your Notion database ID"),
        face = Font:getFace("cfont", 16),
    }
    
    -- Auto-sync toggle
    local auto_sync_label = TextWidget:new{
        text = _("Auto-sync on book finish:"),
        face = Font:getFace("cfont", 16),
    }
    
    self.auto_sync_switch = ToggleSwitch:new{
        width = self.width - 30,
        margin = 10,
        alternate = false,
        toggle = { _("Off"), _("On") },
        values = { false, true },
        config = self,
    }
    self.auto_sync_switch:setPosition(self.auto_sync and 2 or 1)
    
    -- Export path
    local export_label = TextWidget:new{
        text = _("Export Path:"),
        face = Font:getFace("cfont", 16),
    }
    
    self.export_field = InputText:new{
        width = self.width - Size.padding.default * 2 - Size.border.inputtext * 2 - 30,
        input = self.export_path or "",
        focused = false,
        show_parent = self,
        parent = self,
        hint = _("Default path for exported notes"),
        face = Font:getFace("cfont", 16),
    }
    
    -- Add widgets
    self:addWidget(token_label)
    self:addWidget(self.token_field)
    self:addWidget(db_label)
    self:addWidget(self.database_field)
    self:addWidget(auto_sync_label)
    self:addWidget(self.auto_sync_switch)
    self:addWidget(export_label)
    self:addWidget(self.export_field)
end

function SettingsDialog:onSwitchFocus(inputbox)
    -- Unfocus current inputbox
    if self._input_widget then
        self._input_widget:unfocus()
    end
    self:onCloseKeyboard()
    
    UIManager:setDirty(nil, function()
        return "ui", self.dialog_frame.dimen
    end)
    
    -- Focus new inputbox
    self._input_widget = inputbox
    self._input_widget:focus()
    
    self:onShowKeyboard()
end

function SettingsDialog:onSave()
    if self.save_callback then
        self.save_callback({
            notion_token = self.token_field:getText(),
            notion_database_id = self.database_field:getText(),
            auto_sync = self.auto_sync_switch:getPosition() == 2,
            export_path = self.export_field:getText(),
        })
    end
    self:onClose()
end

return SettingsDialog
