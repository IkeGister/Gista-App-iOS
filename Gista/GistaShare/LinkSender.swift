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
        Logger.log("Preparing to send link request", level: .debug)
        Logger.log("User ID: \(userId)", level: .debug)
        Logger.log("URL: \(url.absoluteString)", level: .debug)
        Logger.log("Title: \(title)", level: .debug)
        Logger.log("Category: \(category)", level: .debug)
        
        // Construct the API endpoint URL
        let endpoint = "/links/store"
        guard let apiURL = URL(string: baseURL.absoluteString + endpoint) else {
            Logger.log("Invalid API URL", level: .error)
            return .failure(.invalidURL)
        }
        
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
        
        // Convert the request body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            Logger.log("Failed to serialize request body", level: .error)
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
                Logger.log("Invalid HTTP response", level: .error)
                return .failure(.networkError)
            }
            
            // Log response status
            Logger.log("Received response with status code: \(httpResponse.statusCode)", level: .debug)
            
            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.log("Response body: \(responseString)", level: .debug)
                
                // Check for user authentication errors
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
                    
                    Logger.log("Successfully sent link: \(message)", level: .debug)
                    return .success(response)
                } else {
                    Logger.log("Failed to parse response", level: .error)
                    return .failure(.decodingError)
                }
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Handle authentication errors
                Logger.log("Authentication error (\(httpResponse.statusCode))", level: .error)
                return .failure(.unauthorized)
            } else {
                // Handle other error responses
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                Logger.log("API error (\(httpResponse.statusCode)): \(errorMessage)", level: .error)
                
                return .failure(.apiError(statusCode: httpResponse.statusCode, message: errorMessage))
            }
        } catch let error as URLError {
            // Handle specific URL session errors
            if error.code == .timedOut {
                Logger.log("Request timed out", level: .error)
                return .failure(.timeoutError)
            } else if error.code == .notConnectedToInternet {
                Logger.log("No internet connection", level: .error)
                return .failure(.noInternetConnection)
            } else {
                Logger.log("URL error: \(error.localizedDescription)", level: .error)
                return .failure(.networkError)
            }
        } catch {
            Logger.log("Network error: \(error.localizedDescription)", level: .error)
            return .failure(.networkError)
        }
    }
    
}
