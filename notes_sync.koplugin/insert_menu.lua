-- Add Notes Sync to the Tools menu in Reader, after statistics item
local reader_order = require("ui/elements/reader_menu_order")

local pos = 1
for index, value in ipairs(reader_order.tools) do
    if value == "statistics" then
        pos = index + 1
        break
    end
end
table.insert(reader_order.tools, pos, "notes_sync")
