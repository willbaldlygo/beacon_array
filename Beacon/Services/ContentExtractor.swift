import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

enum ContentExtractionError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case pdfAnalysisFailed
    case emptyContent
    case unsupportedContentType
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .pdfAnalysisFailed: return "Failed to analyze PDF content"
        case .emptyContent: return "No readable text found"
        case .unsupportedContentType: return "Unsupported content type"
        }
    }
}

/// Helper service to extract text from URLs (Web pages or PDFs)
class ContentExtractor {
    
    static let shared = ContentExtractor()
    
    private init() {}
    
    /// Extract text content from a URL.
    ///
    /// **Strategy:**
    /// 1. Try the Array's `/api/v1/extract` endpoint (server-side Readability — handles
    ///    Webflow, SPAs, and complex markup).
    /// 2. If the Array is unreachable or fails, fall back to on-device fetch + HTML stripping.
    func extract(from url: URL) async throws -> FileContent {
        // 1. Try Array-side extraction first
        do {
            let result = try await ArrayService.shared.extractURL(url)
            print("✅ Array extracted \(result.size) chars from \(url.host ?? url.absoluteString)")
            return result
        } catch {
            print("⚠️ Array extraction failed, falling back to on-device: \(error.localizedDescription)")
        }

        // 2. Fallback: on-device fetch
        let isPDF = url.pathExtension.lowercased() == "pdf"

        if isPDF {
            return try await extractPDF(from: url)
        } else {
            return try await extractWebPage(from: url)
        }
    }
    
    // MARK: - PDF Extraction
    
    private func extractPDF(from url: URL) async throws -> FileContent {
        // Download data first
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.networkError(
                NSError(domain: "ContentExtractor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download PDF"])
            )
        }
        
        guard let pdfDocument = PDFDocument(data: data) else {
            throw ContentExtractionError.pdfAnalysisFailed
        }
        
        var fullText = ""
        let pageCount = pdfDocument.pageCount
        
        for i in 0..<pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContentExtractionError.emptyContent
        }
        
        return FileContent(
            path: url.absoluteString,
            name: url.lastPathComponent,
            content: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            size: fullText.count,
            modified: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    // MARK: - Web Extraction
    
    private func extractWebPage(from url: URL) async throws -> FileContent {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ContentExtractionError.networkError(
                NSError(domain: "ContentExtractor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load page (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))"])
            )
        }
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw ContentExtractionError.unsupportedContentType
        }
        
        // Extract page title
        let pageTitle = extractTitle(from: htmlString) ?? url.host ?? "Web Page"
        
        // Strip HTML tags to get visible text
        let visibleText = stripHTMLTags(from: htmlString)
        
        // Check if the site returned meaningful content
        // JS-rendered sites (X/Twitter, SPAs) return HTML shells with almost no visible text
        let trimmedText = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedText.count < 100 {
            // Too little content — likely a JS-rendered page
            let fallbackContent = """
            [Could not extract readable content from this URL]
            URL: \(url.absoluteString)
            Title: \(pageTitle)
            
            This site likely requires JavaScript to render its content (common with X/Twitter, SPAs, and similar platforms). The raw HTML contained no meaningful text.
            
            To share this content with Beacon, try:
            - Copy-pasting the text directly into the chat
            - Taking a screenshot (image support coming soon)
            """
            
            return FileContent(
                path: url.absoluteString,
                name: pageTitle,
                content: fallbackContent,
                size: fallbackContent.count,
                modified: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        return FileContent(
            path: url.absoluteString,
            name: pageTitle,
            content: trimmedText,
            size: trimmedText.count,
            modified: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    // MARK: - HTML Helpers
    
    /// Extract the <title> tag content from HTML
    private func extractTitle(from html: String) -> String? {
        guard let titleStart = html.range(of: "<title", options: .caseInsensitive),
              let tagClose = html[titleStart.upperBound...].range(of: ">"),
              let titleEnd = html[tagClose.upperBound...].range(of: "</title>", options: .caseInsensitive) else {
            return nil
        }
        let title = String(html[tagClose.upperBound..<titleEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
    
    /// Strip HTML tags and decode common entities to extract visible text
    private func stripHTMLTags(from html: String) -> String {
        var text = html
        
        // Remove script and style blocks entirely (content and tags)
        let blockPatterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>",
            "<noscript[^>]*>[\\s\\S]*?</noscript>"
        ]
        for pattern in blockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        
        // Replace block-level tags with newlines for readability
        let blockTags = ["<br[^>]*>", "</?p[^>]*>", "</?div[^>]*>", "</?h[1-6][^>]*>", "</?li[^>]*>", "</?tr[^>]*>"]
        for pattern in blockTags {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n")
            }
        }
        
        // Strip remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&nbsp;", " "), ("&#x27;", "'"), ("&mdash;", "—"),
            ("&ndash;", "–"), ("&hellip;", "…")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Collapse excessive whitespace and blank lines
        if let regex = try? NSRegularExpression(pattern: "[ \\t]+", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        if let regex = try? NSRegularExpression(pattern: "\\n{3,}", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n")
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
