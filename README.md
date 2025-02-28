# CleanYourMac

A simple macOS utility to find large files and clean up your disk space.

## Features

- Browse files in any directory
- Sort files by size (largest first)
- Select and delete unwanted files

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

## Building and Running

### Using Xcode

1. Open Terminal
2. Navigate to the project directory
3. Run `open Package.swift` 
4. Xcode will open the project
5. Click the "Run" button (▶️) in the toolbar

### Using Command Line

1. Open Terminal
2. Navigate to the project directory
3. Run `swift build` to build the executable
4. Run `swift run` to run the application

## Usage

1. Enter a path in the search field (defaults to root `/`)
2. Click "Search" to scan the directory
3. Files will be listed by size (largest first)
4. Select files using the checkboxes
5. Click "Delete Selected" to remove the selected files

## Security Note

This application requires permission to access files on your system. When prompted, grant the necessary permissions to allow it to scan directories and delete files.

## License

MIT 