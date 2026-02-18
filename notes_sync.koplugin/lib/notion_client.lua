-- Notion Client - Notion API integration

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local _ = require("gettext")

local NotionClient = {}
NotionClient.__index = NotionClient

function NotionClient:new(api_token, database_id)
    local o = setmetatable({}, self)
    o.api_token = api_token
    o.database_id = database_id
    o.api_base = "https://api.notion.com/v1"
    return o
end

-- Sync notes to Notion
function NotionClient:syncNotes(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    if not self.api_token or self.api_token == "" then
        return false, _("Notion API token not configured")
    end
    
    if not self.database_id or self.database_id == "" then
        return false, _("Notion database ID not configured")
    end
    
    -- Create or update page in Notion database
    local success, err = self:createOrUpdatePage(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    
    if not success then
        return false, err or _("Failed to sync to Notion")
    end
    
    return true, nil
end

-- Create or update a page in Notion
function NotionClient:createOrUpdatePage(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    -- First, try to find existing page
    local page_id = self:findPageByTitle(book_title)
    
    if page_id then
        -- Update existing page
        return self:updatePage(page_id, book_title, book_author, general_notes, chapter_notes, chapter_parser)
    else
        -- Create new page
        return self:createPage(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    end
end

-- Find page by title in database
-- Note: This assumes your Notion database has a "Title" property of type "title"
-- Adjust the property name to match your database schema
function NotionClient:findPageByTitle(title)
    local url = self.api_base .. "/databases/" .. self.database_id .. "/query"
    
    -- Note: Adjust property name to match your Notion database schema
    -- Common names: "Title", "Name", "Book Title", etc.
    local request_body = json.encode({
        filter = {
            property = "Title",  -- Change this to match your database property name
            title = {
                equals = title
            }
        }
    })
    
    local response_body = {}
    local res, code, headers = http.request({
        url = url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. self.api_token,
            ["Notion-Version"] = "2022-06-28",
            ["Content-Type"] = "application/json"
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    })
    
    if code ~= 200 then
        logger.warn("NotionClient: Failed to query database: " .. (code or "unknown"))
        return nil
    end
    
    local response_text = table.concat(response_body)
    local response_data = json.decode(response_text)
    
    if response_data and response_data.results and #response_data.results > 0 then
        return response_data.results[1].id
    end
    
    return nil
end

-- Create a new page in Notion
function NotionClient:createPage(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    local url = self.api_base .. "/pages"
    
    -- Build page content blocks
    local blocks = self:buildPageBlocks(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    
    local request_body = json.encode({
        parent = {
            database_id = self.database_id
        },
        properties = {
            Title = {  -- Change this to match your database property name
                title = {
                    {
                        text = {
                            content = book_title
                        }
                    }
                }
            }
        },
        children = blocks
    })
    
    local response_body = {}
    local res, code, headers = http.request({
        url = url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. self.api_token,
            ["Notion-Version"] = "2022-06-28",
            ["Content-Type"] = "application/json"
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    })
    
    if code ~= 200 then
        local response_text = table.concat(response_body)
        logger.warn("NotionClient: Failed to create page: " .. (code or "unknown") .. " - " .. response_text)
        return false, _("Failed to create Notion page: ") .. (code or "unknown")
    end
    
    return true, nil
end

-- Update an existing page in Notion
function NotionClient:updatePage(page_id, book_title, book_author, general_notes, chapter_notes, chapter_parser)
    -- First, clear existing content (get children and delete them)
    local children = self:getPageChildren(page_id)
    if children then
        for _, child_id in ipairs(children) do
            self:deleteBlock(child_id)
        end
    end
    
    -- Build new content blocks
    local blocks = self:buildPageBlocks(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    
    -- Append new blocks
    if #blocks > 0 then
        local url = self.api_base .. "/blocks/" .. page_id .. "/children"
        
        local request_body = json.encode({
            children = blocks
        })
        
        local response_body = {}
        local res, code, headers = http.request({
            url = url,
            method = "PATCH",
            headers = {
                ["Authorization"] = "Bearer " .. self.api_token,
                ["Notion-Version"] = "2022-06-28",
                ["Content-Type"] = "application/json"
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body)
        })
        
        if code ~= 200 then
            local response_text = table.concat(response_body)
            logger.warn("NotionClient: Failed to update page: " .. (code or "unknown") .. " - " .. response_text)
            return false, _("Failed to update Notion page: ") .. (code or "unknown")
        end
    end
    
    return true, nil
end

-- Build Notion blocks from notes
function NotionClient:buildPageBlocks(book_title, book_author, general_notes, chapter_notes, chapter_parser)
    local blocks = {}
    
    -- Book metadata
    table.insert(blocks, {
        object = "block",
        type = "paragraph",
        paragraph = {
            rich_text = {
                {
                    type = "text",
                    text = {
                        content = "Book title: " .. (book_title or "Unknown Book")
                    }
                }
            }
        }
    })
    
    table.insert(blocks, {
        object = "block",
        type = "paragraph",
        paragraph = {
            rich_text = {
                {
                    type = "text",
                    text = {
                        content = "Author: " .. (book_author or "Unknown Author")
                    }
                }
            }
        }
    })
    
    table.insert(blocks, {
        object = "block",
        type = "paragraph",
        paragraph = {
            rich_text = {}
        }
    })
    
    -- General Notes section
    if general_notes and general_notes ~= "" then
        table.insert(blocks, {
            object = "block",
            type = "heading_1",
            heading_1 = {
                rich_text = {
                    {
                        type = "text",
                        text = {
                            content = "General Notes"
                        }
                    }
                }
            }
        })
        
        table.insert(blocks, {
            object = "block",
            type = "paragraph",
            paragraph = {
                rich_text = {
                    {
                        type = "text",
                        text = {
                            content = general_notes
                        }
                    }
                }
            }
        })
    end
    
    -- Chapter notes sections
    local chapters = chapter_parser:getChapters()
    if #chapters > 0 then
        for i = 1, #chapters do
            local chapter = chapters[i]
            local chapter_data = chapter_notes[i]
            
            if chapter_data and (chapter_data.notes or (chapter_data.highlights and #chapter_data.highlights > 0)) then
                -- Chapter heading
                table.insert(blocks, {
                    object = "block",
                    type = "heading_2",
                    heading_2 = {
                        rich_text = {
                            {
                                type = "text",
                                text = {
                                    content = "Chapter " .. i .. " " .. chapter.title
                                }
                            }
                        }
                    }
                })
                
                -- General chapter notes first (if any, not associated with specific highlights)
                if chapter_data.notes and chapter_data.notes ~= "" then
                    table.insert(blocks, {
                        object = "block",
                        type = "paragraph",
                        paragraph = {
                            rich_text = {
                                {
                                    type = "text",
                                    text = {
                                        content = chapter_data.notes
                                    }
                                }
                            }
                        }
                    })
                end
                
                -- Process highlights
                if chapter_data.highlights and #chapter_data.highlights > 0 then
                    for _, highlight in ipairs(chapter_data.highlights) do
                        -- Highlight as code block with page range
                        if highlight.text and highlight.text ~= "" then
                            local page_range = ""
                            if highlight.page_start then
                                if highlight.page_end and highlight.page_start ~= highlight.page_end then
                                    page_range = "[page " .. highlight.page_start .. "-" .. highlight.page_end .. "]"
                                else
                                    page_range = "[page " .. highlight.page_start .. "]"
                                end
                            end
                            
                            table.insert(blocks, {
                                object = "block",
                                type = "code",
                                code = {
                                    rich_text = {
                                        {
                                            type = "text",
                                            text = {
                                                content = page_range .. "```" .. highlight.text .. "```"
                                            }
                                        }
                                    },
                                    language = "plain text"
                                }
                            })
                            
                            -- Note as paragraph with "Note:" prefix
                            local note_text = highlight.note or ""
                            table.insert(blocks, {
                                object = "block",
                                type = "paragraph",
                                paragraph = {
                                    rich_text = {
                                        {
                                            type = "text",
                                            text = {
                                                content = "Note: " .. note_text
                                            }
                                        }
                                    }
                                }
                            })
                        end
                    end
                end
            end
        end
    end
    
    return blocks
end

-- Get page children (blocks)
function NotionClient:getPageChildren(page_id)
    local url = self.api_base .. "/blocks/" .. page_id .. "/children"
    
    local response_body = {}
    local res, code, headers = http.request({
        url = url,
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. self.api_token,
            ["Notion-Version"] = "2022-06-28"
        },
        sink = ltn12.sink.table(response_body)
    })
    
    if code ~= 200 then
        return nil
    end
    
    local response_text = table.concat(response_body)
    local response_data = json.decode(response_text)
    
    if response_data and response_data.results then
        local children = {}
        for _, block in ipairs(response_data.results) do
            table.insert(children, block.id)
        end
        return children
    end
    
    return nil
end

-- Delete a block
function NotionClient:deleteBlock(block_id)
    local url = self.api_base .. "/blocks/" .. block_id
    
    local response_body = {}
    local res, code, headers = http.request({
        url = url,
        method = "DELETE",
        headers = {
            ["Authorization"] = "Bearer " .. self.api_token,
            ["Notion-Version"] = "2022-06-28"
        },
        sink = ltn12.sink.table(response_body)
    })
    
    return code == 200
end

return NotionClient
