import SwiftUI
import AppKit

struct ContentView: View {
    @State private var searchPath: String = ""
    @State private var files: [FileItem] = []
    @State private var isSearching: Bool = false
    @State private var selectedFiles: Set<URL> = []
    @State private var errorMessage: String? = nil
    @State private var scanDepth: Int = 3 // Default recursive depth
    @State private var freedSpace: Int64 = 0 // To track freed space
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search path (default: home directory)", text: $searchPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isSearchFieldFocused)
                    .onAppear {
                        // Request focus after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.isSearchFieldFocused = true
                        }
                    }
                
                Picker("Depth", selection: $scanDepth) {
                    Text("1 level").tag(1)
                    Text("2 levels").tag(2)
                    Text("3 levels").tag(3)
                    Text("5 levels").tag(5)
                    Text("10 levels").tag(10)
                }
                .frame(width: 120)
                .help("How many levels of directories to scan")
                
                Button("Search") {
                    scanDirectory()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSearching)
            }
            .padding()
            
            if isSearching {
                ProgressView("Scanning directory...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Name")
                            .frame(width: 300, alignment: .leading)
                        Text("Size")
                            .frame(width: 100, alignment: .trailing)
                        Text("Path")
                            .frame(minWidth: 200, alignment: .leading)
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.horizontal)
                    
                    if files.isEmpty {
                        Text("No files found in this directory.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .foregroundColor(.secondary)
                            .font(.title3)
                    } else {
                        List {
                            ForEach(files) { file in
                                FileRowView(file: file, isSelected: selectedFiles.contains(file.url)) { isSelected in
                                    if isSelected {
                                        selectedFiles.insert(file.url)
                                    } else {
                                        selectedFiles.remove(file.url)
                                    }
                                }
                                .contextMenu {
                                    Button("Open in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                    }
                                    
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                                    }
                                    
                                    Button("Copy Path") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(file.path, forType: .string)
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Selected: \(selectedFiles.count) files")
                            if freedSpace > 0 {
                                Text("Freed space: \(formatFileSize(freedSpace))")
                                    .foregroundColor(.green)
                                    .bold()
                            }
                        }
                        
                        Spacer()
                        Button("Delete Selected") {
                            deleteSelectedFiles()
                        }
                        .disabled(selectedFiles.isEmpty)
                    }
                    .padding()
                }
            }
        }
        .alert(item: errorMessageBinding) { message in
            Alert(
                title: Text("Error"),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Start scanning the user's home directory when the app loads
            scanHomeDirectory()
        }
    }
    
    private func scanHomeDirectory() {
        // Default to home directory on first load
        let fileManager = FileManager.default
        searchPath = fileManager.homeDirectoryForCurrentUser.path
        scanDirectory()
    }
    
    private func scanDirectory() {
        isSearching = true
        files = []
        selectedFiles = []
        
        let path = searchPath.isEmpty ? FileManager.default.homeDirectoryForCurrentUser.path : searchPath
        
        // Use Task instead of DispatchQueue for actor isolation
        Task {
            let fileManager = FileManager.default
            
            var directoryURL: URL?
            if path.hasPrefix("/") {
                // Absolute path
                directoryURL = URL(fileURLWithPath: path)
            } else if path.hasPrefix("~") {
                // User's home directory path
                let homePath = fileManager.homeDirectoryForCurrentUser.path
                let relativePath = path.hasPrefix("~/") ? String(path.dropFirst(2)) : String(path.dropFirst(1))
                directoryURL = URL(fileURLWithPath: homePath).appendingPathComponent(relativePath)
            } else {
                // Relative path, assume it's relative to the user's home
                directoryURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(path)
            }
            
            if let url = directoryURL, fileManager.fileExists(atPath: url.path) {
                let scannedFiles = await scanFilesRecursively(at: url, currentDepth: 0, maxDepth: scanDepth)
                
                // Sort by size (largest first)
                let sortedFiles = scannedFiles.sorted(by: { $0.size > $1.size })
                    .prefix(1000) // Limit to 1000 files to avoid overwhelming the UI
                
                await MainActor.run {
                    self.files = Array(sortedFiles)
                    self.isSearching = false
                }
            } else {
                await MainActor.run {
                    self.isSearching = false
                    self.errorMessage = "The specified directory could not be found. Please check the path and try again."
                }
            }
        }
    }
    
    private func scanFilesRecursively(at directory: URL, currentDepth: Int, maxDepth: Int) async -> [FileItem] {
        let fileManager = FileManager.default
        var results: [FileItem] = []
        
        // Don't go beyond the max depth
        guard currentDepth <= maxDepth else {
            return results
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [])
            
            for fileURL in fileURLs {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    
                    if let isDirectory = resourceValues.isDirectory {
                        if isDirectory {
                            // Skip some system directories and invisible folders
                            if !shouldSkipDirectory(fileURL) {
                                // Recursively scan subdirectories
                                let subResults = await scanFilesRecursively(at: fileURL, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                                results.append(contentsOf: subResults)
                            }
                        } else if let fileSize = resourceValues.fileSize {
                            // Add file to results
                            let fileItem = FileItem(
                                url: fileURL,
                                name: fileURL.lastPathComponent,
                                size: Int64(fileSize),
                                path: fileURL.path
                            )
                            results.append(fileItem)
                        }
                    }
                } catch {
                    // Skip files with errors
                    continue
                }
            }
        } catch {
            print("Error scanning directory \(directory.path): \(error.localizedDescription)")
        }
        
        return results
    }
    
    private func shouldSkipDirectory(_ url: URL) -> Bool {
        // Skip invisible directories and system directories
        let path = url.path.lowercased()
        let name = url.lastPathComponent
        
        // Skip hidden directories (start with .)
        if name.hasPrefix(".") {
            return true
        }
        
        // Skip certain system directories
        let skipDirs = [
            "/library", "/system", "/private", 
            "/volumes", "/network", "/dev",
            "/bin", "/sbin", "/usr/bin", "/usr/sbin",
            "/usr/libexec", "/Applications/Xcode.app"
        ]
        
        return skipDirs.contains { path.contains($0.lowercased()) }
    }
    
    private func scanFiles(at directory: URL) async -> [FileItem] {
        // For backward compatibility, redirect to recursive scan with depth 1
        return await scanFilesRecursively(at: directory, currentDepth: 0, maxDepth: 1)
    }
    
    private func deleteSelectedFiles() {
        let fileManager = FileManager.default
        var failedFiles: [String] = []
        var spaceFreed: Int64 = 0
        
        for fileURL in selectedFiles {
            do {
                if let fileSize = getFileSize(at: fileURL) {
                    spaceFreed += fileSize
                }
                
                try fileManager.removeItem(at: fileURL)
                if let index = files.firstIndex(where: { $0.url == fileURL }) {
                    files.remove(at: index)
                }
            } catch {
                print("Error deleting file \(fileURL.path): \(error.localizedDescription)")
                failedFiles.append(fileURL.lastPathComponent)
            }
        }
        
        // Update the total freed space
        freedSpace += spaceFreed
        
        selectedFiles = []
        
        if !failedFiles.isEmpty {
            let failedFilesList = failedFiles.joined(separator: ", ")
            self.errorMessage = "Failed to delete some files: \(failedFilesList). You might not have permission to delete these files."
        }
    }
    
    private func getFileSize(at url: URL) -> Int64? {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// Create a proper error message type instead of extending String
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

extension ContentView {
    // Convert between String and ErrorMessage
    var errorMessageBinding: Binding<ErrorMessage?> {
        Binding<ErrorMessage?>(
            get: { errorMessage.map { ErrorMessage(message: $0) } },
            set: { errorMessage = $0?.message }
        )
    }
}

struct FileRowView: View {
    let file: FileItem
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onSelectionChanged($0) }
            ))
            .toggleStyle(.checkbox)
            
            Text(file.name)
                .frame(width: 300, alignment: .leading)
            
            Text(formatFileSize(file.size))
                .frame(width: 100, alignment: .trailing)
                .foregroundColor(.secondary)
            
            Text(file.path)
                .frame(minWidth: 200, alignment: .leading)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let path: String
}

#Preview {
    ContentView()
} 