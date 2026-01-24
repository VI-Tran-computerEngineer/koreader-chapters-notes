-- Chapter Parser - Extract chapter info from document TOC

local logger = require("logger")

local ChapterParser = {}
ChapterParser.__index = ChapterParser

function ChapterParser:new(document)
    local o = setmetatable({}, self)
    o.document = document
    o.chapters = {}
    o:parseTOC()
    return o
end

-- Parse table of contents from document
function ChapterParser:parseTOC()
    if not self.document then
        logger.warn("ChapterParser: No document available")
        return
    end
    
    -- Try to get TOC using different methods
    local toc_items = nil
    
    -- Method 1: document:getTOC()
    if self.document.getTOC then
        toc_items = self.document:getTOC()
    end
    
    -- Method 2: document:tocItems()
    if not toc_items and self.document.tocItems then
        toc_items = self.document:tocItems()
    end
    
    if not toc_items or #toc_items == 0 then
        logger.info("ChapterParser: No TOC found in document")
        return
    end
    
    -- Process TOC items
    for i, item in ipairs(toc_items) do
        local chapter = {
            number = i,
            title = item.title or item.name or ("Chapter " .. i),
            page = item.page or nil,
            xpointer = item.xpointer or nil
        }
        
        -- Try to get page number from xpointer if page is not available
        if not chapter.page and chapter.xpointer and self.document.getPageFromXPointer then
            chapter.page = self.document:getPageFromXPointer(chapter.xpointer)
        end
        
        table.insert(self.chapters, chapter)
    end
end

-- Get all chapters
function ChapterParser:getChapters()
    return self.chapters
end

-- Get chapter by number (1-indexed)
function ChapterParser:getChapter(chapter_num)
    if chapter_num < 1 or chapter_num > #self.chapters then
        return nil
    end
    return self.chapters[chapter_num]
end

-- Get chapter number for a given page
function ChapterParser:getChapterForPage(page)
    if not page or #self.chapters == 0 then
        return nil
    end
    
    -- Find the chapter that contains this page
    -- Pages are typically between current chapter and next chapter
    for i = 1, #self.chapters do
        local chapter = self.chapters[i]
        local next_chapter = self.chapters[i + 1]
        
        if chapter.page and chapter.page <= page then
            if not next_chapter or not next_chapter.page or page < next_chapter.page then
                return i
            end
        end
    end
    
    -- If page is before first chapter, return first chapter
    if #self.chapters > 0 and self.chapters[1].page and page < self.chapters[1].page then
        return 1
    end
    
    -- If page is after last chapter, return last chapter
    if #self.chapters > 0 then
        return #self.chapters
    end
    
    return nil
end

-- Get page range for a chapter
function ChapterParser:getPageRangeForChapter(chapter_num)
    local chapter = self:getChapter(chapter_num)
    if not chapter then
        return nil, nil
    end
    
    local page_start = chapter.page
    local page_end = nil
    
    -- Get page_end from next chapter
    local next_chapter = self:getChapter(chapter_num + 1)
    if next_chapter and next_chapter.page then
        page_end = next_chapter.page - 1
    end
    
    return page_start, page_end
end

-- Get chapter title
function ChapterParser:getChapterTitle(chapter_num)
    local chapter = self:getChapter(chapter_num)
    if chapter then
        return chapter.title
    end
    return "Chapter " .. chapter_num
end

return ChapterParser
