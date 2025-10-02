# LeafReader

A modern EPUB reader for iOS 18+ built with Swift 6, UIKit, and SwiftUI.

## Features (v0.1)

- EPUB import from Files app, AirDrop, and other sources
- Library view with UICollectionView + DiffableDataSource
- SwiftUI book cards with cover images
- Readium-based EPUB reader
- Reading position persistence
- Table of contents navigation
- Automatic reading progress tracking
- Modern Swift 6 concurrency with async/await
- iOS 18+ with latest APIs

## Architecture

### Core Layer
- **Models**: `Book`, `BookMetadata` - Sendable data models
- **Storage**: `BookRepository` protocol with `FileSystemBookRepository` implementation
- **Services**: `EPUBParser` for Readium integration

### Features
- **Library**: UICollectionView with DiffableDataSource, SwiftUI book cards
- **Reader**: Readium Navigator integration with TOC support

### Dependencies
- Readium Swift Toolkit 3.4.0+
  - ReadiumShared
  - ReadiumStreamer
  - ReadiumNavigator
  - ReadiumLCP
  - ReadiumOPDS
  - ReadiumAdapterGCDWebServer
  - ReadiumAdapterLCPSQLite

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0

## Getting Started

1. Open `LeafReader.xcodeproj` in Xcode
2. Build and run on iOS 18+ device or simulator
3. Tap the + button to import EPUB files
4. Tap a book to start reading

## Project Structure

```
LeafReader/
├── Core/
│   ├── Models/          # Data models
│   ├── Storage/         # Repository implementations
│   ├── Services/        # Business logic services
│   └── Coordinator/     # App coordination
├── Features/
│   ├── Library/         # Book library UI
│   │   ├── Views/
│   │   └── ViewModels/
│   └── Reader/          # EPUB reader UI
│       ├── Views/
│       └── ViewModels/
└── Support/             # Extensions and utilities
```

## Development Plan

This is v0.1 implementation. Future versions will include:

- **v0.2**: Custom rendering for full-screen chapters, CSS injection pipeline
- **v0.3**: Footnote popup support (standard, Duokan, Zhangyue)
- **v0.4**: Font mapping, reading settings (font size, line spacing, themes)
- **v0.5**: LCP DRM support

## License

See LICENSE file for details.