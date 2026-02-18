# KOReader Chapters Notes Plugin

A KOReader plugin that allows you to manage reading notes, export them, and sync to Notion. Supports general notes and chapter-specific notes with highlights integration.

## Features

- **General Notes**: Write general notes for any book
- **Chapter Notes**: Write notes for specific chapters, with automatic highlight integration
- **Export**: Export notes to text files in a structured format
- **Notion Sync**: Sync notes to Notion database
- **Auto-sync**: Automatically sync notes when finishing a book
- **Highlight Integration**: Associate notes with highlights from the book

## Installation

1. Copy the `notes_sync.koplugin` folder to your KOReader plugins directory:
   ```
   ~/.config/koreader/plugins/
   ```

2. Restart KOReader

3. The plugin will appear in the Tools menu as "Notes Sync"

## Usage

### Basic Setup

1. Open any book in KOReader
2. Go to **Tools → Notes Sync → Settings**
3. Configure:
   - **Notion API Token**: Get from https://www.notion.so/my-integrations
   - **Notion Database ID**: Create a database and get its ID from the URL
   - **Auto-sync**: Enable to sync automatically when finishing books
   - **Export Path**: Default path for exported notes

### Writing Notes

1. **General Notes**: Tools → Notes Sync → Open notes → General notes
2. **Chapter Notes**: Tools → Notes Sync → Open notes → Chapter X

### Exporting Notes

1. Tools → Notes Sync → Export
2. Choose a file path to save the notes

### Syncing to Notion

1. Tools → Notes Sync → Sync
2. Notes will be uploaded to your Notion database

## Notion Database Setup

1. Create a new database in Notion
2. Add a "Title" property (type: Title) - this is where the book name goes
3. The plugin will automatically create pages with your notes

## Export Format

The exported text file, and notes updated to Notion, follow this format:

```
Book title:
Author:

=== General Notes ===
Your general notes here...

=== Chapter 1 Chapter Title ===
Chapter specific notes here...

[page 5-6]```highlighted text```
Note: your note about this highlight

[page 8]```another highlight```
Note: 

=== Chapter n Chapter Title ===
...
```

## License

See LICENSE file for details.