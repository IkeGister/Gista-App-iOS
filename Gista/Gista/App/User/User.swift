import Foundation
import Shared

struct User: Codable {
    let userId: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case message
    }
    
    init(userId: String, message: String) {
        self.userId = userId
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode userId, which should always be present
        userId = try container.decode(String.self, forKey: .userId)
        
        // Try to decode message, but use a default if missing
        if let decodedMessage = try? container.decode(String.self, forKey: .message) {
            message = decodedMessage
        } else {
            message = "User operation completed"
        }
    }
}