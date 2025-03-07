# Gista Integration Tests

This directory contains integration tests for the Gista app that make actual network calls to the API.

## ⚠️ IMPORTANT: DO NOT RUN THESE TESTS DIRECTLY FROM XCODE

These tests make actual network calls to the API and should only be run:
1. When specifically testing API integration
2. With proper test credentials
3. In a controlled environment (not production)
4. After proper configuration

## Running Integration Tests

Integration tests are disabled by default to avoid making unnecessary network calls during regular development and CI/CD pipelines.

### Command Line Method (Recommended)

Run the tests from the command line where you can easily set environment variables:

```bash
# Set environment variables
export RUN_INTEGRATION_TESTS=YES
export TEST_EMAIL="your-test-email@example.com"
export TEST_PASSWORD="your-test-password"
export TEST_USERNAME="your-test-username"
export TEST_AUTH_TOKEN="your-test-auth-token"

# Run the tests
xcodebuild test -scheme Gista -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Xcode Configuration (For Future Setup)

To run these tests from Xcode, a test plan must be properly configured with environment variables. This setup is pending and should not be attempted without guidance.

## API Endpoints Reference

For manual testing or debugging, you can use these curl commands to interact with the API directly:

### Authentication

```bash
# Create a user
curl -X POST https://us-central1-dof-ai.cloudfunctions.net/api/auth/create-user \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123", "username": "testuser"}'

# Update a user
curl -X PUT https://us-central1-dof-ai.cloudfunctions.net/api/auth/update-user \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"username": "newUsername", "email": "newemail@example.com"}'

# Delete a user
curl -X DELETE https://us-central1-dof-ai.cloudfunctions.net/api/auth/delete_user/USER_ID
```

### Links/Articles

```bash
# Store a link
curl -X POST https://us-central1-dof-ai.cloudfunctions.net/api/links/store \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user123", "link": {"category": "Technology", "url": "https://example.com/article", "title": "Article Title"}}'

# Update link gist status
curl -X PUT https://us-central1-dof-ai.cloudfunctions.net/api/links/update-gist-status/USER_ID/LINK_ID \
  -H "Content-Type: application/json" \
  -d '{"gist_id": "gist_123", "image_url": "https://example.com/image.jpg", "link_title": "Updated Article Title"}'

# Fetch links
curl -X GET https://us-central1-dof-ai.cloudfunctions.net/api/links/USER_ID
```

### Gists

```bash
# Create a gist
curl -X POST https://us-central1-dof-ai.cloudfunctions.net/api/gists/add/USER_ID \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Tech Trends Gist",
    "link": "https://example.com/article",
    "image_url": "https://example.com/image.jpg",
    "category": "Technology",
    "segments": [{
      "duration": 120,
      "title": "Test Segment",
      "audioUrl": "https://example.com/audio.mp3"
    }],
    "playback_duration": 120
  }'

# Update gist status
curl -X PUT https://us-central1-dof-ai.cloudfunctions.net/api/gists/update/USER_ID/GIST_ID \
  -H "Content-Type: application/json" \
  -d '{
    "status": {
      "inProduction": true,
      "production_status": "In Production"
    },
    "is_played": true,
    "ratings": 4
  }'

# Delete a gist
curl -X DELETE https://us-central1-dof-ai.cloudfunctions.net/api/gists/delete/USER_ID/GIST_ID

# Fetch gists
curl -X GET https://us-central1-dof-ai.cloudfunctions.net/api/gists/USER_ID
```

### Categories

```bash
# Fetch all categories
curl -X GET https://us-central1-dof-ai.cloudfunctions.net/api/categories

# Fetch a specific category
curl -X GET https://us-central1-dof-ai.cloudfunctions.net/api/categories/CATEGORY_SLUG

# Create a category
curl -X POST https://us-central1-dof-ai.cloudfunctions.net/api/categories/add \
  -H "Content-Type: application/json" \
  -d '{"name": "New Category", "tags": ["tag1", "tag2", "tag3"]}'

# Update a category
curl -X PUT https://us-central1-dof-ai.cloudfunctions.net/api/categories/update/CATEGORY_ID \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name", "tags": ["new", "tags"]}'
```

## Test Coverage

The integration tests cover:

1. **User Management**
   - Creating users
   - Updating user information
   - Deleting users

2. **Article Management**
   - Storing articles
   - Fetching articles

3. **Gist Management**
   - Creating gists
   - Updating gist status
   - Fetching gists
   - Deleting gists

4. **Category Management**
   - Fetching all categories
   - Fetching specific categories by slug

## Best Practices

- Run integration tests in a development or staging environment, not production
- Use dedicated test accounts, not real user accounts
- Clean up test data after tests complete
- Do not commit real credentials to source control 