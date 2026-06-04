import Foundation

struct UserProfileData: Codable {
    var bio: String
    var preferences: [String]
}

class UserProfile {
    static let shared = UserProfile()
    
    // Default profile based on ContextBuilder's previous hardcoded values
    private let defaultProfile = UserProfileData(
        bio: """
        - Digital Skills Tutor at Digital Peninsula Network
        - Teaches AI bootcamps with a "builders not button pushers" philosophy
        - Has ADHD - values direct, practical, actionable responses
        - Lives near Barnsley, South Yorkshire (works remotely)
        """,
        preferences: [
            "Be concise and direct",
            "Avoid unnecessary preamble",
            "Use plain language, not corporate speak",
            "If you need clarification, ask one question at a time",
            "Don't use bullet points unless specifically helpful"
        ]
    )
    
    private init() {}
    
    var bio: String {
        return defaultProfile.bio
    }
    
    var preferences: [String] {
        return defaultProfile.preferences
    }
    
    func getFormattedProfile() -> String {
        var profile = "## About Will\n"
        profile += bio + "\n\n"
        
        profile += "## Communication Style\n"
        for pref in preferences {
            profile += "- \(pref)\n"
        }
        
        return profile
    }
}
