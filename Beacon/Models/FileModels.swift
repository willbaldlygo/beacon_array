import Foundation

struct FileItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int?
    let modified: String?
    let fileExtension: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, size, modified
        case isDirectory = "is_directory"
        case fileExtension = "extension"
    }
}

struct DirectoryListing: Codable, Sendable {
    let path: String
    let parent: String?
    let items: [FileItem]
    let count: Int
}

struct FileContent: Codable, Identifiable, Sendable {
    var id: String { path }
    let path: String
    let name: String
    let content: String
    let size: Int
    let modified: String
}

struct WriteRequest: Codable, Sendable {
    let path: String
    let content: String
    let create_directories: Bool
}

struct WriteResponse: Codable, Sendable {
    let success: Bool
    let path: String
    let bytes_written: Int
}

enum FileBrowserError: Error, LocalizedError {
    case loadFailed
    case readFailed(message: String)
    case writeFailed(message: String)
    case deleteFailed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load directory listing."
        case .readFailed(let message):
            return "Failed to read file: \(message)"
        case .writeFailed(let message):
            return "Failed to write file: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete file: \(message)"
        }
    }
}
