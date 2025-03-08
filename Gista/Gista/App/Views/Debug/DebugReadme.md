# Gista Debug Documentation

## Gist Creation and Article Update Issue

### Problem Overview

We've identified and fixed an issue with gist creation, but there's still a problem with the article update process that happens after a gist is created. This document explains both issues and their solutions.

### 1. Gist Creation Issue (FIXED)

**Problem:** The server was returning a 500 error when attempting to create a gist.

**Root Cause:** The field names in the JSON request body didn't match what the API expected. This was due to inconsistent naming conventions in the model's `CodingKeys`.

**Solution:** We updated the following models to match the expected API format:

1. **GistSegment Model:**
   ```swift
   enum CodingKeys: String, CodingKey {
       case duration
       case title
       case audioUrl = "audioUrl"
       case segmentIndex = "index"
   }
   ```

2. **GistRequest Model:**
   ```swift
   enum CodingKeys: String, CodingKey {
       case title, link, category, segments, status
       case imageUrl = "image_url"
       case playbackDuration = "playback_duration"
       case linkId = "link_id"
       case gistId = "gist_id"
       case isFinished
       case playbackTime = "playback_time"
   }
   ```

3. **GistStatus Model:**
   ```swift
   enum CodingKeys: String, CodingKey {
       case inProduction
       case productionStatus = "production_status"
   }
   ```

These changes ensured that the JSON sent to the API matched the expected format, resolving the 500 error.

### 2. Article Update Issue (NEEDS FIXING)

**Problem:** After successfully creating a gist, the application attempts to update the article with the gist information, but this request fails with a 404 error.

**Error Message:**
```
Cannot PUT /links/update_gist_status/user_-5869685454119081661/1F4F8E62-B911-4A92-8C93-5D77517C21CB
```

**Root Cause:** The application is using UUIDs for article and gist IDs in the update request, but the server expects string IDs with specific prefixes (like "link_1741404766276").

**Current Request:**
- URL: `https://us-central1-dof-ai.cloudfunctions.net/api/links/update_gist_status/user_-5869685454119081661/1F4F8E62-B911-4A92-8C93-5D77517C21CB`
- Body:
  ```json
  {
    "gist_id": "2D805F90-7D37-414D-B3E2-83DB75933AF6",
    "link_title": "iOS Client Test Article - iPhone-16 - 1741404688",
    "image_url": "https://example.com/image.jpg"
  }
  ```

**Expected Request:**
- URL: `https://us-central1-dof-ai.cloudfunctions.net/api/links/update_gist_status/user_-5869685454119081661/link_1741404766276`
- Body:
  ```json
  {
    "gist_id": "link_1741404766276",
    "link_title": "iOS Client Test Article - iPhone-16 - 1741404688",
    "image_url": "https://example.com/image.jpg"
  }
  ```

### Solution Steps

To fix the article update issue:

1. **Identify where `updateArticleGistStatus` is called** - This is likely in the `createGist` method of your test view.

2. **Use the correct article ID** - When calling `updateArticleGistStatus`, use the string `linkId` (like "link_1741404766276") instead of the UUID string.

3. **Use the correct gist ID** - For the `gistId` parameter, use the string ID returned by the server (which in this case is also "link_1741404766276") instead of a UUID.

4. **Update the `GistaService.updateArticleGistStatus` method** - Make sure it's using the correct IDs in both the URL and request body.

### Code Example (Pseudo-code)

```swift
// After successfully creating a gist
let createdGist = try await viewModel.gistaService.createGist(userId: userId, gist: gistRequest)

// Store the string IDs returned by the server
let linkId = article.gistStatus?.articleId // This should be something like "link_1741404766276"
let gistId = createdGist.gistId // This should be the string ID returned by the server

// Update the article with the correct IDs
let updatedArticle = try await viewModel.gistaService.updateArticleGistStatus(
    userId: userId,
    articleId: linkId, // Use the string ID, not UUID.uuidString
    gistId: gistId, // Use the string ID returned by the server
    imageUrl: "https://example.com/image.jpg",
    title: article.title
)
```

### API Endpoint Reference

According to the API documentation, the endpoint for updating an article's gist status is:

```
PUT https://us-central1-dof-ai.cloudfunctions.net/api/links/update-gist-status/:user_id/:link_id
```

Where:
- `:user_id` is the user's unique identifier
- `:link_id` is the link's unique identifier (string format like "link_1741404766276")

The request body should include:
```json
{
  "gist_id": "gist_123",
  "image_url": "https://example.com/image.jpg",
  "link_title": "Updated Article Title"
}
```

### Testing the Fix

After implementing the fix:

1. Create a user
2. Add an article
3. Create a gist
4. Verify that the article is successfully updated with the gist information

If the article update is successful, you should see a 200 response with the updated article information.
