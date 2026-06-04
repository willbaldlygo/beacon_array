import Foundation
import Combine

@MainActor
class FileBrowserService: ObservableObject {
    @Published var currentPath: String = ""
    @Published var items: [FileItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "https://array.baldlygo.uk"
    
    private func getAPIKey() throws -> String {
        guard let key = KeychainHelper.get(key: "array_api_key"), !key.isEmpty else {
            throw FileBrowserError.loadFailed // Or a more specific auth error
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func loadDirectory(path: String = "") async {
        isLoading = true
        error = nil
        
        do {
            var components = URLComponents(string: "\(baseURL)/api/v1/files")!
            components.queryItems = [URLQueryItem(name: "path", value: path)]
            
            guard let url = components.url else { throw URLError(.badURL) }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(try getAPIKey())", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw FileBrowserError.loadFailed
            }
            
            let listing = try JSONDecoder().decode(DirectoryListing.self, from: data)
            
            self.currentPath = listing.path
            self.items = listing.items
            self.isLoading = false
            
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    func readFile(path: String) async throws -> FileContent {
        var components = URLComponents(string: "\(baseURL)/api/v1/files/read")!
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try getAPIKey())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FileBrowserError.readFailed(message: errorBody)
        }
        
        return try JSONDecoder().decode(FileContent.self, from: data)
    }
    
    func writeFile(path: String, content: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1/files/write") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try getAPIKey())", forHTTPHeaderField: "Authorization")
        
        let body = WriteRequest(path: path, content: content, create_directories: true)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FileBrowserError.writeFailed(message: errorBody)
        }
    }
    
    func deleteFile(path: String) async throws {
         var components = URLComponents(string: "\(baseURL)/api/v1/files")!
         components.queryItems = [URLQueryItem(name: "path", value: path)]
         
         guard let url = components.url else { throw URLError(.badURL) }
         
         var request = URLRequest(url: url)
         request.httpMethod = "DELETE"
         request.setValue("Bearer \(try getAPIKey())", forHTTPHeaderField: "Authorization")
         
         let (data, response) = try await URLSession.shared.data(for: request)
         
         guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
             let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
             throw FileBrowserError.deleteFailed(message: errorBody)
         }
    }
}
