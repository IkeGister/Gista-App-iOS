//
//  ArticleResponse.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import SwiftUI
import Foundation

struct ArticleData: Codable {
    let message: String
    let link: LinkData
    
    struct LinkData: Codable {
        let category: String
        let dateAdded: Date?
        let gistCreated: ArticleGistStatus
        
        enum CodingKeys: String, CodingKey {
            case category
            case dateAdded = "date_added"
            case gistCreated = "gist_created"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode category
            category = try container.decode(String.self, forKey: .category)
            
            // Try to decode dateAdded, but use current date if missing
            if let dateString = try? container.decode(String.self, forKey: .dateAdded),
               let date = ISO8601DateFormatter().date(from: dateString) {
                dateAdded = date
            } else {
                dateAdded = nil
            }
            
            // Get the raw value for gistCreated
            do {
                // Try to decode the gistCreated field as a nested object with proper types
                let nestedContainer = try container.nestedContainer(keyedBy: GistCreatedKeys.self, forKey: .gistCreated)
                
                // Extract values with proper types
                let gistCreatedBool = try nestedContainer.decodeIfPresent(Bool.self, forKey: .gistCreated) ?? false
                let gistId = try nestedContainer.decodeIfPresent(String.self, forKey: .gistId)
                let imageUrl = try nestedContainer.decodeIfPresent(String.self, forKey: .imageUrl)
                let linkId = try nestedContainer.decodeIfPresent(String.self, forKey: .linkId) ?? UUID().uuidString
                let linkTitle = try nestedContainer.decodeIfPresent(String.self, forKey: .linkTitle) ?? "Unknown Title"
                let linkType = try nestedContainer.decodeIfPresent(String.self, forKey: .linkType) ?? "Web"
                let url = try nestedContainer.decodeIfPresent(String.self, forKey: .url) ?? "https://example.com"
                
                // Create the ArticleGistStatus with the extracted values
                gistCreated = ArticleGistStatus(
                    gistCreated: gistCreatedBool,
                    gistId: gistId,
                    imageUrl: imageUrl,
                    articleId: linkId,
                    title: linkTitle,
                    type: linkType,
                    url: url
                )
                print("Successfully decoded gistCreated as nested object")
            } catch {
                print("Error decoding gistCreated as nested object: \(error)")
                
                // Try to decode as a dictionary of AnyDecodable
                do {
                    if let gistCreatedDict = try? container.decode([String: AnyDecodable].self, forKey: .gistCreated) {
                        // Extract values from the dictionary
                        let gistCreatedBool = (gistCreatedDict["gist_created"]?.value as? Bool) ?? false
                        let gistId = gistCreatedDict["gist_id"]?.value as? String
                        let imageUrl = gistCreatedDict["image_url"]?.value as? String
                        let linkId = (gistCreatedDict["link_id"]?.value as? String) ?? UUID().uuidString
                        let linkTitle = (gistCreatedDict["link_title"]?.value as? String) ?? "Unknown Title"
                        let linkType = (gistCreatedDict["link_type"]?.value as? String) ?? "Web"
                        let url = (gistCreatedDict["url"]?.value as? String) ?? "https://example.com"
                        
                        // Create the ArticleGistStatus with the extracted values
                        gistCreated = ArticleGistStatus(
                            gistCreated: gistCreatedBool,
                            gistId: gistId,
                            imageUrl: imageUrl,
                            articleId: linkId,
                            title: linkTitle,
                            type: linkType,
                            url: url
                        )
                        print("Successfully created gistCreated from dictionary")
                    } else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(
                            codingPath: container.codingPath + [CodingKeys.gistCreated],
                            debugDescription: "Failed to decode gistCreated as dictionary"
                        ))
                    }
                } catch {
                    print("Error decoding gistCreated as dictionary: \(error)")
                    
                    // Create a fallback ArticleGistStatus with default values
                    gistCreated = ArticleGistStatus(
                        gistCreated: false,
                        gistId: nil,
                        imageUrl: nil,
                        articleId: UUID().uuidString,
                        title: "Unknown Title",
                        type: "Web",
                        url: "https://example.com"
                    )
                    print("Created fallback gistCreated")
                }
            }
        }
        
        // Define nested keys for gistCreated
        enum GistCreatedKeys: String, CodingKey {
            case gistCreated = "gist_created"
            case gistId = "gist_id"
            case imageUrl = "image_url"
            case linkId = "link_id"
            case linkTitle = "link_title"
            case linkType = "link_type"
            case url
        }
    }
}
