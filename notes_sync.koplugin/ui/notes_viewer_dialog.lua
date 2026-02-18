-- Notes Viewer Dialog - Similar to VocabBuilder structure

local Device = require("device")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local FocusManager = require("ui/widget/focusmanager")
local TitleBar = require("ui/widget/titlebar")
local Button = require("ui/widget/button")
local TextBoxWidget = require("ui/widget/textboxwidget")
local FrameContainer = require("ui/widget/container/framecontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local LineWidget = require("ui/widget/linewidget")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local Menu = require("ui/widget/menu")
local GestureRange = require("ui/gesturerange")
local BD = require("ui/bidi")
local GeneralNotesDialog = require("ui/general_notes_dialog")
local ChapterNotesDialog = require("ui/chapter_notes_dialog")
local _ = require("gettext")
local logger = require("logger")

local NotesViewerDialog = FocusManager:extend{
    title = _("Notes"),
    width = nil,
    height = nil,
    notes_sync = nil,
    notes_manager = nil,
    chapter_parser = nil,
    ui = nil,
    current_index = 0,
    notes_list = {},
}

function NotesViewerDialog:init()
    -- Build notes list: general notes first, then chapters
    self.notes_list = {}
    
    -- Add general notes
    table.insert(self.notes_list, {
        type = "general",
        title = _("General Notes"),
    })
    
    -- Add chapter notes
    if self.chapter_parser then
        local chapters = self.chapter_parser:getChapters()
        for i = 1, #chapters do
            local chapter = chapters[i]
            table.insert(self.notes_list, {
                type = "chapter",
                num = i,
                title = string.format(_("Chapter %d: %s"), i, chapter.title),
            })
        end
    end
    
    -- Set initial index to 0 (general notes)
    if self.current_index < 0 or self.current_index >= #self.notes_list then
        self.current_index = 0
    end
    
    self.dimen = Geom:new{
        w = self.width or Screen:getWidth(),
        h = self.height or Screen:getHeight(),
    }
    
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
        self.key_events.ShowMenu = { { "Menu" } }
    end
    
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = self.dimen,
            }
        }
    end
    
    -- Setup footer first (like VocabBuilder)
    local padding = Size.padding.large
    self.width_widget = self.dimen.w - 2 * padding
    self.item_width = self.dimen.w - 2 * padding
    
    self.page_info = HorizontalGroup:new{}
    self.footer_buttons = HorizontalGroup:new{}
    self:refreshFooter()
    
    local bottom_line = LineWidget:new{
        dimen = Geom:new{ w = self.item_width, h = Size.line.thick },
        background = Blitbuffer.COLOR_LIGHT_GRAY,
    }
    local vertical_footer = VerticalGroup:new{
        bottom_line,
        self.page_info,
        self.footer_buttons,
    }
    self.footer_height = vertical_footer:getSize().h
    local footer = BottomContainer:new{
        dimen = self.dimen:copy(),
        vertical_footer,
    }
    
    -- Setup title bar (like VocabBuilder)
    self.title_bar = TitleBar:new{
        width = self.dimen.w,
        align = "center",
        title_face = Font:getFace("smallinfofontbold"),
        bottom_line_color = Blitbuffer.COLOR_LIGHT_GRAY,
        with_bottom_line = true,
        bottom_line_h_padding = Size.padding.large,
        left_icon = "appbar.menu",
        left_icon_tap_callback = function() self:onShowMenu() end,
        title = self.title,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }
    
    -- Setup main content
    self.main_content = VerticalGroup:new{}
    self:updateContent()
    
    -- Assemble like VocabBuilder
    local frame_content = FrameContainer:new{
        height = self.dimen.h,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            self.title_bar,
            self.main_content,
        },
    }
    local content = OverlapGroup:new{
        dimen = self.dimen:copy(),
        frame_content,
        footer,
    }
    -- assemble page
    self[1] = FrameContainer:new{
        height = self.dimen.h,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        content
    }
end

function NotesViewerDialog:refreshFooter()
    -- Update page info text
    self.page_info:clear()
    
    if #self.notes_list > 0 then
        local current_note = self.notes_list[self.current_index + 1]
        local page_text = string.format("%d / %d", self.current_index + 1, #self.notes_list)
        if current_note then
            page_text = current_note.title .. " (" .. page_text .. ")"
        end
        
        local page_widget = TextBoxWidget:new{
            text = page_text,
            face = Font:getFace("smallinfofont"),
            width = self.dimen.w - 2 * Size.padding.large,
        }
        table.insert(self.page_info, page_widget)
    end
    
    -- Setup footer buttons (left arrow - Edit - right arrow) if not already created
    if self.footer_left == nil then
        local footer_button_width = math.floor(self.width_widget * (12/100))
        local footer_edit_width = math.floor(self.width_widget * (30/100))
        local footer_center_width = math.floor(self.width_widget * (32/100))
        
        local chevron_left = "chevron.left"
        local chevron_right = "chevron.right"
        if BD.mirroredUILayout() then
            chevron_left, chevron_right = chevron_right, chevron_left
        end
        
        self.footer_left = Button:new{
            icon = chevron_left,
            width = footer_button_width,
            callback = function() self:prevNote() end,
            bordersize = 0,
            radius = 0,
            show_parent = self,
        }
        
        self.footer_edit = Button:new{
            text = _("Edit"),
            width = footer_edit_width,
            callback = function() self:editCurrentNote() end,
            bordersize = 0,
            radius = 0,
            show_parent = self,
        }
        
        self.footer_right = Button:new{
            icon = chevron_right,
            width = footer_button_width,
            callback = function() self:nextNote() end,
            bordersize = 0,
            radius = 0,
            show_parent = self,
        }
    end
    
    -- Update footer buttons row
    self.footer_buttons:clear()
    local footer_center_width = math.floor(self.width_widget * (32/100))
    table.insert(self.footer_buttons, HorizontalSpan:new{width = footer_center_width})
    table.insert(self.footer_buttons, self.footer_left)
    table.insert(self.footer_buttons, self.footer_edit)
    table.insert(self.footer_buttons, self.footer_right)
    table.insert(self.footer_buttons, HorizontalSpan:new{width = footer_center_width})
end

function NotesViewerDialog:updateContent()
    self.main_content:clear()
    
    local notes_text = ""
    local title_text = ""
    
    if #self.notes_list > 0 then
        local current_note = self.notes_list[self.current_index + 1]
        if current_note then
            title_text = current_note.title
            
            if current_note.type == "general" then
                notes_text = self.notes_manager:getGeneralNotes() or ""
            elseif current_note.type == "chapter" then
                local chapter_data = self.notes_manager:getChapterNotesForChapter(current_note.num)
                notes_text = chapter_data.notes or ""
                
                -- Add highlights info if available
                if chapter_data.highlights and #chapter_data.highlights > 0 then
                    local highlights_text = "\n\n" .. _("Highlights:") .. "\n"
                    for i, highlight in ipairs(chapter_data.highlights) do
                        if highlight.text and highlight.text ~= "" then
                            local preview = highlight.text
                            if #preview > 100 then
                                preview = preview:sub(1, 100) .. "..."
                            end
                            highlights_text = highlights_text .. "• " .. preview .. "\n"
                        end
                    end
                    notes_text = notes_text .. highlights_text
                end
            end
        end
    end
    
    -- Update title
    local title_text_display = title_text
    if #self.notes_list > 0 then
        title_text_display = title_text_display .. string.format(" (%d / %d)", self.current_index + 1, #self.notes_list)
    end
    if self.title_bar then
        self.title_bar:setTitle(title_text_display)
    end
    
    -- Always show the content area, even if empty (like VocabBuilder)
    local content_width = self.item_width
    local content_height = self.dimen.h - self.title_bar:getHeight() - self.footer_height - Size.padding.large
    
    local display_text = title_text
    if notes_text and notes_text ~= "" then
        display_text = display_text .. "\n\n" .. notes_text
    end
    
    local text_widget = TextBoxWidget:new{
        text = display_text,
        face = Font:getFace("smallinfofont"),
        width = content_width,
        editable = false,
    }
    
    local content_frame = FrameContainer:new{
        height = content_height,
        padding = Size.padding.large,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        text_widget,
    }
    
    -- Use table.insert like VocabBuilder
    table.insert(self.main_content, content_frame)
    
    -- If empty, add a spacer like VocabBuilder
    if #self.main_content == 0 then
        table.insert(self.main_content, HorizontalGroup:new{width = self.item_width})
    end
    
    self:refreshFooter()
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function NotesViewerDialog:prevNote()
    if #self.notes_list == 0 then
        return
    end
    
    self.current_index = self.current_index - 1
    if self.current_index < 0 then
        self.current_index = #self.notes_list - 1
    end
    
    self:updateContent()
end

function NotesViewerDialog:nextNote()
    if #self.notes_list == 0 then
        return
    end
    
    self.current_index = self.current_index + 1
    if self.current_index >= #self.notes_list then
        self.current_index = 0
    end
    
    self:updateContent()
end

function NotesViewerDialog:goToNote(index)
    if index >= 0 and index < #self.notes_list then
        self.current_index = index
        self:updateContent()
    end
end

function NotesViewerDialog:onShowMenu()
    local menu_items = {}
    
    -- Add general notes item
    table.insert(menu_items, {
        text = _("General Notes"),
        checked_func = function()
            return self.current_index == 0
        end,
        callback = function()
            self:goToNote(0)
            UIManager:close(self.menu_dialog)
        end,
    })
    
    -- Add chapter notes items
    for i = 1, #self.notes_list - 1 do
        local note = self.notes_list[i + 1]
        if note.type == "chapter" then
            table.insert(menu_items, {
                text = note.title,
                checked_func = function()
                    return self.current_index == i
                end,
                callback = function()
                    self:goToNote(i)
                    UIManager:close(self.menu_dialog)
                end,
            })
        end
    end
    
    self.menu_dialog = Menu:new{
        title = _("Select Note"),
        item_table = menu_items,
        width = math.min(Screen:getWidth() * 0.4, 400), -- Small menu like dictionary
        show_parent = self,
    }
    
    UIManager:show(self.menu_dialog)
end

function NotesViewerDialog:editCurrentNote()
    if #self.notes_list == 0 then
        return
    end
    
    local current_note = self.notes_list[self.current_index + 1]
    if not current_note then
        return
    end
    
    -- Store reference to self for callback
    local viewer = self
    
    if current_note.type == "general" then
        -- Edit general notes - open popout window
        local notes_manager = self.notes_manager
        local current_notes = notes_manager:getGeneralNotes()
        
        local dialog = GeneralNotesDialog:new{
            title = _("General Notes"),
            description = _("Write your general notes for this book"),
            input_hint = _("Enter your notes here..."),
            input = current_notes,
            save_callback = function(text)
                notes_manager:saveGeneralNotes(text)
                -- Refresh viewer after saving
                viewer:updateContent()
            end,
        }
        
        UIManager:show(dialog)
    elseif current_note.type == "chapter" then
        -- Edit chapter notes - open popout window
        if self.chapter_parser then
            local notes_manager = self.notes_manager
            local chapter_parser = self.chapter_parser
            local chapter_num = current_note.num
            
            local chapter = chapter_parser:getChapter(chapter_num)
            if not chapter then
                return
            end
            
            local chapter_data = notes_manager:getChapterNotesForChapter(chapter_num)
            
            -- Get highlights for this chapter
            local page_start, page_end = chapter_parser:getPageRangeForChapter(chapter_num)
            local highlights = {}
            
            if page_start and viewer.ui then
                highlights = notes_manager:getHighlightsForPageRange(viewer.ui, page_start, page_end)
            end
            
            -- Merge stored highlight notes with current highlights
            if chapter_data.highlights then
                for _, stored_highlight in ipairs(chapter_data.highlights) do
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
                    -- Refresh viewer after saving
                    viewer:updateContent()
                end,
            }
            
            UIManager:show(dialog)
        end
    end
end

function NotesViewerDialog:onPrevPage()
    self:prevNote()
end

function NotesViewerDialog:onNextPage()
    self:nextNote()
end

function NotesViewerDialog:onSwipe(arg, ges_ev)
    if ges_ev.direction == "west" then
        self:nextNote()
    elseif ges_ev.direction == "east" then
        self:prevNote()
    end
    return true
end

function NotesViewerDialog:onClose()
    UIManager:close(self)
end

return NotesViewerDialog
