import SwiftUI
import AppKit

struct ContentView: View {
    @State private var searchPath: String = "/"
    @State private var files: [FileItem] = []
    @State private var isSearching: Bool = false
    @State private var selectedFiles: Set<URL> = []
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search path (default: /)", text: $searchPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
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
                    
                    List {
                        ForEach(files) { file in
                            FileRowView(file: file, isSelected: selectedFiles.contains(file.url)) { isSelected in
                                if isSelected {
                                    selectedFiles.insert(file.url)
                                } else {
                                    selectedFiles.remove(file.url)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text("Selected: \(selectedFiles.count) files")
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
        .alert(item: $errorMessage) { message in
            Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func scanDirectory() {
        isSearching = true
        files = []
        selectedFiles = []
        
        let path = searchPath.isEmpty ? "/" : searchPath
        
        // Use Task instead of DispatchQueue for actor isolation
        Task {
            let fileManager = FileManager.default
            
            var directoryURL: URL?
            if path.hasPrefix("/") {
                // Absolute path
                directoryURL = URL(fileURLWithPath: path)
            } else if path.hasPrefix("~/") {
                // User's home directory path
                let homePath = fileManager.homeDirectoryForCurrentUser.path
                directoryURL = URL(fileURLWithPath: homePath + path.dropFirst(1))
            } else {
                // Relative path, assume it's relative to the user's home
                directoryURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(path)
            }
            
            if let url = directoryURL, fileManager.fileExists(atPath: url.path) {
                let scannedFiles = await scanFiles(at: url)
                
                // Sort by size (largest first)
                let sortedFiles = scannedFiles.sorted(by: { $0.size > $1.size })
                
                await MainActor.run {
                    self.files = sortedFiles
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
    
    private func scanFiles(at directory: URL) async -> [FileItem] {
        let fileManager = FileManager.default
        var results: [FileItem] = []
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [])
            
            for fileURL in fileURLs {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    
                    if let isDirectory = resourceValues.isDirectory, isDirectory {
                        // Skip directories for now in this simple MVP
                        continue
                    }
                    
                    if let fileSize = resourceValues.fileSize {
                        let fileItem = FileItem(
                            url: fileURL,
                            name: fileURL.lastPathComponent,
                            size: Int64(fileSize),
                            path: fileURL.path
                        )
                        results.append(fileItem)
                    }
                } catch {
                    // Skip files with errors
                    continue
                }
            }
        } catch {
            print("Error scanning directory: \(error.localizedDescription)")
        }
        
        return results
    }
    
    private func deleteSelectedFiles() {
        let fileManager = FileManager.default
        
        for fileURL in selectedFiles {
            do {
                try fileManager.removeItem(at: fileURL)
                if let index = files.firstIndex(where: { $0.url == fileURL }) {
                    files.remove(at: index)
                }
            } catch {
                print("Error deleting file \(fileURL.path): \(error.localizedDescription)")
            }
        }
        
        selectedFiles = []
    }
}

// Alert message identifier
extension String: Identifiable {
    public var id: String { self }
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