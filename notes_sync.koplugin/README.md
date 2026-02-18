
## Development

The plugin structure:
```
notes_sync.koplugin/
├── _meta.lua              # Plugin metadata
├── main.lua               # Main plugin entry point
├── insert_menu.lua        # Menu integration
├── lib/
│   ├── config.lua         # Settings management
│   ├── notes_manager.lua  # Core notes storage/retrieval
│   ├── chapter_parser.lua # TOC parsing for chapters
│   ├── export_handler.lua # Export functionality
│   ├── notion_client.lua  # Notion API integration
│   └── events.lua         # Event handling
└── ui/
    ├── general_notes_dialog.lua    # General notes editor
    ├── chapter_notes_dialog.lua    # Chapter notes editor
    └── settings_dialog.lua         # Settings dialog
```

