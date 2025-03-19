# Firebase API Documentation

## Project Structure
Gista-CrewAI/
│
├── functions/
│   │   ├── src/
│   │   │   ├── auth/
│   │   │   │   └── userManagement.js
│   │   ├── categories/
│   │   │   └── categoriesManagement.js
│   │   ├── gists/
│   │   │   └── gistManagement.js
│   │   ├── links/
│   │   │   └── linkManagement.js
│   │   ├── index.js
│   │   └── service-account.json
│   ├── utilities/
│   │   ├── defaultCategories.js
│   │   └── initCategories.js
│   ├── package.json
│   └── .eslintrc.js
│
├── Firebase/
│   ├── APIs/
│   │   └── API-Documentation.md
│   └── config/
│       ├── firebase_config.py
│       └── test_firebase.py
│
├── .env
├── .gitignore
└── firebase.json

## Overview
This document outlines the APIs for the Gista application, including authentication, gist management, link management, and Firebase services integration. The APIs are built using Firebase Cloud Functions and follow RESTful principles.

## Base URL
- **Development**: `http://localhost:5001`
- **Production**: `https://us-central1-dof-ai.cloudfunctions.net/api`

## Current API Endpoints

### 1. Authentication API (`/auth`)

#### POST https://us-central1-dof-ai.cloudfunctions.net/api/auth/create_user
- **Description**: Create a new user in Firebase Authentication and Firestore.
- **Request Body**:
    ```json
    {
      "user_id": "user123",
      "email": "user@example.com",
      "username": "username123"
    }
    ```
- **Responses**:
    - **201**: User created successfully
        ```json
        {
          "message": "User created successfully",
          "user_id": "user123"
        }
        ```
    - **400**: User already exists or missing required fields
    - **500**: Error creating user

#### DELETE https://us-central1-dof-ai.cloudfunctions.net/api/auth/delete_user/:user_id
- **Description**: Delete a user and all their data from Firestore.
- **Parameters**:
    - `user_id`: User's unique identifier
- **Responses**:
    - **200**: User deleted successfully
        ```json
        {
          "message": "User user123 deleted successfully"
        }
        ```
    - **404**: User not found
    - **500**: Error deleting user

#### PUT https://us-central1-dof-ai.cloudfunctions.net/api/auth/update-user
- **Description**: Update user information in Firestore.
- **Headers**: 
    - `Authorization: Bearer <token>`
- **Request Body**:
    ```json
    {
      "username": "newUsername",
      "email": "newemail@example.com"
    }
    ```
- **Responses**:
    - **200**: User updated successfully
    - **401**: No token provided
    - **500**: Error updating user

### 2. Links API (`/links`)

#### POST https://us-central1-dof-ai.cloudfunctions.net/api/links/store
- **Description**: Store a new link for processing into a gist. Optionally creates a gist automatically.
- **Request Body**:
    ```json
    {
      "user_id": "user123",
      "link": {
        "category": "Technology",
        "url": "https://example.com/article",
        "title": "Article Title"
      },
      "auto_create_gist": true  // Optional, defaults to true
    }
    ```
- **Responses**:
    - **200**: Link stored successfully
        ```json
        {
          "gistId": "gist_9876543210"
        }
        ```
        or (if auto_create_gist is false)
        ```json
        {
          "message": "Link stored successfully"
        }
        ```
    - **400**: Missing required fields
        ```json
        {
          "error": "user_id and link are required"
        }
        ```
    - **500**: Error storing link or creating gist
        ```json
        {
          "error": "Failed to store link"
        }
        ```
        or
        ```json
        {
          "error": "Link stored but failed to create gist"
        }
        ```
- **Notes**:
    - When `auto_create_gist` is true, the endpoint will automatically create a gist from the link
    - The gist will have default values for required fields and empty segments to be filled by CrewAI
    - The link's `gist_created` status will be updated to reflect the gist creation
    - The CrewAI service will be notified about the new gist
    - If gist creation fails, an error response will be returned

#### PUT https://us-central1-dof-ai.cloudfunctions.net/api/links/update-gist-status/:user_id/:link_id
- **Description**: Update link's gist creation status.
- **Parameters**:
    - `user_id`: User's unique identifier
    - `link_id`: Link's unique identifier
- **Request Body**:
    ```json
    {
      "gist_id": "gist_123",
      "image_url": "https://example.com/image.jpg",
      "link_title": "Updated Article Title"
    }
    ```
- **Responses**:
    - **200**: Link updated successfully
        ```json
        {
          "message": "Link gist status updated successfully",
          "link": {
            "category": "Technology",
            "date_added": "2024-01-25T09:00:00Z",
            "gist_created": {
              "gist_created": true,
              "gist_id": "gist_123",
              "image_url": "https://example.com/image.jpg",
              "link_id": "link_1706201234567",
              "link_title": "Updated Article Title",
              "link_type": "Web",
              "url": "https://example.com/article"
            }
          }
        }
        ```
    - **404**: User or link not found
    - **500**: Error updating link

#### GET https://us-central1-dof-ai.cloudfunctions.net/api/links/:user_id
- **Description**: Retrieve all links for a user.
- **Parameters**:
    - `user_id`: User's unique identifier
- **Responses**:
    - **200**: Returns array of links and count
        ```json
        {
          "links": [{
            "category": "Technology",
            "date_added": "2024-01-25T09:00:00Z",
            "gist_created": {
              "gist_created": false,
              "gist_id": null,
              "image_url": null,
              "link_id": "link_1706201234567",
              "link_title": "Article Title",
              "link_type": "Web",
              "url": "https://example.com/article"
            }
          }],
          "count": 1
        }
        ```
    - **404**: User not found
    - **500**: Error fetching links

### 3. Gists API (`/gists`)

#### POST https://us-central1-dof-ai.cloudfunctions.net/api/gists/add/:user_id
- **Description**: Create a new gist from processed content.
- **Parameters**:
    - `user_id`: User's unique identifier
- **Request Body**:
    ```json
    {
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
    }
    ```
- **Responses**:
    - **200**: Gist created successfully
        ```json
        {
          "message": "Gist added successfully",
          "gist": {
            "title": "Tech Trends Gist",
            "category": "Technology",
            "date_created": "2024-01-25T08:30:00Z",
            "image_url": "https://example.com/image.jpg",
            "is_played": false,
            "is_published": true,
            "link": "https://example.com/article",
            "playback_duration": 120,
            "publisher": "theNewGista",
            "ratings": 0,
            "segments": [{
              "segment_audioUrl": "https://example.com/audio.mp3",
              "playback_duration": 120,
              "segment_index": 0,
              "segment_title": "Test Segment"
            }],
            "status": {
              "inProduction": false,
              "production_status": "Reviewing Content",
            },
            "users": 0
          }
        }
        ```
    - **400**: Missing required fields
    - **500**: Error creating gist

#### PUT https://us-central1-dof-ai.cloudfunctions.net/api/gists/update/:user_id/:gist_id
- **Description**: Update gist status and metadata.
- **Parameters**:
    - `user_id`: User's unique identifier
    - `gist_id`: Gist's unique identifier
- **Request Body**:
    ```json
    {
      "status": {
        "inProduction": true,
        "production_status": "In Production"
      },
      "is_played": true,
      "ratings": 4
    }
    ```
- **Responses**:
    - **200**: Gist updated successfully
    - **404**: User or gist not found
    - **500**: Error updating gist

#### PUT https://us-central1-dof-ai.cloudfunctions.net/api/gists/:user_id/:gist_id/status
- **Description**: Update gist production status using a signal-based approach.
- **Parameters**:
    - `user_id`: User's unique identifier
    - `gist_id`: Gist's unique identifier
- **Request Body**: Empty JSON object `{}` (signal-based approach)
- **Responses**:
    - **200**: Gist status updated successfully
        ```json
        {
          "success": true,
          "message": "Gist production status updated"
        }
        ```
    - **404**: User or gist not found
    - **500**: Error updating gist
- **Notes**:
    - This endpoint always sets `inProduction: true` and `production_status: "Reviewing Content"`
    - No request body is needed, but if provided it will be ignored
    - The gist must exist in the system for the update to succeed

#### DELETE https://us-central1-dof-ai.cloudfunctions.net/api/gists/delete/:user_id/:gist_id
- **Description**: Delete a specific gist from a user's gists array.
- **Parameters**:
    - `user_id`: User's unique identifier
    - `gist_id`: Gist's unique identifier
- **Responses**:
    - **200**: Gist deleted successfully
        ```json
        {
          "message": "Gist gist_123 deleted successfully"
        }
        ```
    - **404**: User or gist not found
    - **500**: Error deleting gist

#### GET https://us-central1-dof-ai.cloudfunctions.net/api/gists/:user_id
- **Description**: Retrieve all gists for a user.
- **Parameters**:
    - `user_id`: User's unique identifier
- **Responses**:
    - **200**: Returns array of gists
    - **404**: User not found
    - **500**: Error fetching gists

### 4. Categories API (`/categories`)

#### GET https://us-central1-dof-ai.cloudfunctions.net/api/categories
- **Description**: Retrieve all categories
- **Responses**:
    - **200**: Returns array of categories and count
        ```json
        {
          "categories": [{
            "_id": "cat001",
            "name": "Business",
            "slug": "business",
            "tags": ["finance", "economics", "startups"]
          }],
          "count": 1
        }
        ```
    - **500**: Error fetching categories

#### GET https://us-central1-dof-ai.cloudfunctions.net/api/categories/:slug
- **Description**: Get category by slug
- **Parameters**:
    - `slug`: Category's URL-friendly name
- **Responses**:
    - **200**: Returns category object
    - **404**: Category not found
    - **500**: Error fetching category

#### POST https://us-central1-dof-ai.cloudfunctions.net/api/categories/add
- **Description**: Create a new category with auto-incrementing ID
- **Request Body**:
    ```json
    {
      "name": "New Category",
      "tags": ["tag1", "tag2", "tag3"]
    }
    ```
- **Responses**:
    - **201**: Category created successfully
        ```json
        {
          "message": "Category added successfully",
          "category": {
            "_id": "cat016",
            "name": "New Category",
            "slug": "new-category",
            "tags": ["tag1", "tag2", "tag3"]
          }
        }
        ```
    - **400**: Missing required fields or duplicate slug
    - **500**: Error creating category

#### PUT https://us-central1-dof-ai.cloudfunctions.net/api/categories/update/:id
- **Description**: Update category name and/or tags
- **Parameters**:
    - `id`: Category's unique identifier (e.g., cat001)
- **Request Body**:
    ```json
    {
      "name": "Updated Name",  // Optional
      "tags": ["new", "tags"]  // Optional
    }
    ```
- **Responses**:
    - **200**: Category updated successfully
        ```json
        {
          "message": "Category updated successfully",
          "category": {
            "_id": "cat001",
            "name": "Updated Name",
            "slug": "updated-name",
            "tags": ["new", "tags"]
          }
        }
        ```
    - **400**: No fields to update or duplicate slug
    - **404**: Category not found
    - **500**: Error updating category

### 5. Test Endpoint

#### GET https://us-central1-dof-ai.cloudfunctions.net/api/test
- **Description**: Simple endpoint to test if the API is working.
- **Responses**:
    - **200**: API is working
        ```json
        {
          "message": "Express API is working!"
        }
        ```

## Recommended Testing Flow in Hopscotch

1. Test the API connectivity with `GET /test`
2. Create a test user with `POST /auth/create_user`
3. Store a link and automatically create a gist with `POST /links/store` (with `auto_create_gist=true`)
4. Retrieve the user's gists with `GET /gists/:user_id`
5. Retrieve the user's links with `GET /links/:user_id`
6. Store another link without creating a gist with `POST /links/store` (with `auto_create_gist=false`)
7. Update the gist status using the signal-based approach with `PUT /gists/:user_id/:gist_id/status`
8. Delete the gist with `DELETE /gists/delete/:user_id/:gist_id`
9. Delete the user with `DELETE /auth/delete_user/:user_id`

## Security
- Firebase Authentication for user management
- Secure credential storage using service account
- Environment variable protection for sensitive data
- CORS enabled for specified origins

## Development Setup
1. Install dependencies: `npm install` in functions directory
2. Set up service account JSON file in `functions/src/`
3. Initialize Firebase Admin SDK with service account
4. Run locally: `firebase serve --only functions`

## Deployment
Deploy to Firebase Cloud Functions:
```bash
firebase deploy --only functions
```

The API will be available at: `https://us-central1-dof-ai.cloudfunctions.net/api`
