//
//  LinkSender.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/15/25.
//


import Foundation
import Shared

class LinkSender {
    // MARK: - Properties
    private let baseURL = URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!
    
    // MARK: - Initialization
    init() {
        Logger.log("LinkSender initialized with baseURL: \(baseURL.absoluteString)", level: .debug)
    }
    
    // MARK: - Send Link
    func sendLink(userId: String, url: URL, title: String, category: String) async -> Result<LinkResponse, LinkError> {
        // Enhanced diagnostic logging
        Logger.log("🚀 LINK SENDER - PREPARING TO SEND REQUEST", level: .debug)
        Logger.log("---------------------------------------------------", level: .debug)
        
        // User ID detailed checks
        Logger.log("🔑 User ID: \(userId)", level: .debug)
        Logger.log("🔍 User ID format check:", level: .debug)
        Logger.log("   - Length: \(userId.count) characters", level: .debug)
        Logger.log("   - Contains underscore: \(userId.contains("_"))", level: .debug)
        
        if userId.contains("_") {
            let components = userId.split(separator: "_", maxSplits: 1)
            Logger.log("   - Username part: \(components[0])", level: .debug)
            if components.count > 1 {
                Logger.log("   - UUID part: \(components[1])", level: .debug)
                if let _ = UUID(uuidString: String(components[1])) {
                    Logger.log("   - UUID validation: ✅ Valid UUID format", level: .debug)
                } else {
                    Logger.log("   - UUID validation: ❌ Invalid UUID format", level: .debug)
                }
            }
        }
        
        // Existing logging
        Logger.log("📤 URL: \(url.absoluteString)", level: .debug)
        Logger.log("📝 Title: \(title)", level: .debug)
        Logger.log("🏷️ Category: \(category)", level: .debug)
        Logger.log("---------------------------------------------------", level: .debug)
        
        // Construct the API endpoint URL
        let endpoint = "/links/store"
        guard let apiURL = URL(string: baseURL.absoluteString + endpoint) else {
            Logger.log("LinkSender: Invalid API URL", level: .error)
            return .failure(.invalidURL)
        }
        
        // Create the request body
        // Ensure category is never null or undefined by providing a default value
        let safeCategory = category.isEmpty ? "Uncategorized" : category
        
        // If the category is "Reference", change it to "Article" which might be more compatible
        let finalCategory = safeCategory == "Reference" ? "Article" : safeCategory
        
        // Create request body according to API documentation
        let requestBody: [String: Any] = [
            "user_id": userId,
            "link": [
                "category": finalCategory,
                "url": url.absoluteString,
                "title": title
            ],
            "auto_create_gist": true
        ]
        
        // Log the final request body for debugging
        print("🔄 FINAL REQUEST BODY:")
        print("- user_id: \(userId)")
        print("- link.url: \(url.absoluteString)")
        print("- link.title: \(title)")
        print("- link.category: \(finalCategory) (original: \(category))")
        print("- auto_create_gist: true")
        
        // Add detailed logging of the request body, especially the userId
        Logger.log("LinkSender: Request body - userId: \(userId)", level: .debug)
        Logger.log("LinkSender: User ID format check - contains underscore: \(userId.contains("_"))", level: .debug)
        if let requestJSON = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
           let jsonString = String(data: requestJSON, encoding: .utf8) {
            Logger.log("LinkSender: Full request body JSON: \(jsonString)", level: .debug)
        }
        
        // Convert the request body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            Logger.log("LinkSender: Failed to serialize request body", level: .error)
            return .failure(.encodingError)
        }
        
        // Create the HTTP request
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add a timeout
        request.timeoutInterval = 30
        
        do {
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check the HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.log("LinkSender: Invalid HTTP response", level: .error)
                return .failure(.networkError)
            }
            
            // Log response for debugging
            Logger.log("LinkSender: Received response with status code: \(httpResponse.statusCode)", level: .debug)
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.log("LinkSender: Response body: \(responseString)", level: .debug)
                print("🔍 DETAILED API RESPONSE: \(responseString)")
                
                // Check for category-related errors
                if responseString.contains("category") {
                    print("⚠️ CATEGORY ISSUE DETECTED IN RESPONSE")
                    print("📊 Category being sent: \(category)")
                    
                    // Try to debug the request body
                    if let requestBodyJSON = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let article = requestBodyJSON["article"] as? [String: Any] {
                        print("📦 Request article object: \(article)")
                        print("📦 Category in request: \(article["category"] ?? "MISSING")")
                    }
                }
                
                // Enhanced error detection with more patterns
                let errorPatterns = [
                    "user not found",
                    "userId not found",
                    "user doesn't exist",
                    "User doesn't exist",
                    "invalid user",
                    "user invalid",
                    "authentication required",
                    "unauthorized",
                    "not authorized"
                ]
                
                for pattern in errorPatterns {
                    if responseString.lowercased().contains(pattern.lowercased()) {
                        Logger.log("LinkSender: Error pattern detected: \(pattern)", level: .error)
                        return .failure(.apiError(
                            statusCode: httpResponse.statusCode,
                            message: "User not found. Please open the Gista app and sign in first."
                        ))
                    }
                }
            }
            
            // Check for successful status code
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                // Parse the response
                if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let success = responseJSON["success"] as? Bool ?? true
                    let message = responseJSON["message"] as? String ?? "Link stored successfully"
                    let linkId = responseJSON["linkId"] as? String
                    let gistId = responseJSON["gistId"] as? String
                    
                    let response = LinkResponse(
                        success: success,
                        message: message,
                        linkId: linkId,
                        gistId: gistId
                    )
                    
                    Logger.log("LinkSender: Successfully sent link: \(message)", level: .debug)
                    return .success(response)
                } else {
                    Logger.log("LinkSender: Failed to parse response", level: .error)
                    return .failure(.decodingError)
                }
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Handle authentication errors
                Logger.log("LinkSender: Authentication error (\(httpResponse.statusCode))", level: .error)
                return .failure(.unauthorized)
            } else {
                // Handle other error responses
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.log("LinkSender: API error (\(httpResponse.statusCode)): \(errorMessage)", level: .error)
                
                // Try to parse more details from the error response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📛 DETAILED ERROR INFO: \(errorData)")
                    
                    // Check for specific error types
                    if errorMessage.contains("category") {
                        // Category-related error
                        return .failure(.apiError(
                            statusCode: httpResponse.statusCode,
                            message: "Category error: Please try again later. Technical details: \(errorMessage)"
                        ))
                    } else if errorMessage.contains("undefined") {
                        // Missing field error
                        return .failure(.apiError(
                            statusCode: httpResponse.statusCode,
                            message: "Missing required field. Technical details: \(errorMessage)"
                        ))
                    }
                }
                
                return .failure(.apiError(statusCode: httpResponse.statusCode, message: errorMessage))
            }
        } catch let error as URLError {
            // Handle specific URL session errors
            if error.code == .timedOut {
                Logger.log("LinkSender: Request timed out", level: .error)
                return .failure(.timeoutError)
            } else if error.code == .notConnectedToInternet {
                Logger.log("LinkSender: No internet connection", level: .error)
                return .failure(.noInternetConnection)
            } else {
                Logger.log("LinkSender: URL error: \(error.localizedDescription)", level: .error)
                return .failure(.networkError)
            }
        } catch {
            Logger.log("LinkSender: Network error: \(error.localizedDescription)", level: .error)
            return .failure(.networkError)
        }
    }
    
}
