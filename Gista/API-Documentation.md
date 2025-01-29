# Firebase API Documentation

## Project Structure
Project Root/
│
├── functions/
│   │   ├── src/
│   │   │   ├── auth/
│   │   │   │   └── userManagement.js
│   │   │   ├── gists/
│   │   │   │   └── gistManagement.js
│   │   │   ├── links/
│   │   │   │   └── linkManagement.js
│   │   │   ├── index.js
│   │   │   └── service-account.json
│   │   ├── package.json
│   │   └── .eslintrc.js
│   ├── Firebase/
│   │   └── config/
│   │       ├── firebase_config.py
│   │       └── test_firebase.py
│   ├── .env
│   ├── .gitignore
│   └── firebase.json
│
└── utils/
    ├── __init__.py
    └── firebase_utils.py

## Overview
This document outlines the APIs for the Gista application, including authentication, gist management, link management, and Firebase services integration. The APIs are built using Firebase Cloud Functions and follow RESTful principles.

## Base URL
- **Development**: `http://localhost:5001`
- **Production**: `https://us-central1-dof-ai.cloudfunctions.net/api`

## Current API Endpoints

### 1. Authentication API (`/auth`)

#### POST /auth/create-user
- **Description**: Create a new user in Firebase Authentication and Firestore.
- **Request Body**:
    ```json
    {
      "email": "user@example.com",
      "password": "securepassword",
      "username": "username123"
    }
    ```
- **Responses**:
    - **201**: User created successfully
        ```json
        {
          "message": "User created successfully",
          "userId": "user123"
        }
        ```
    - **500**: Error creating user

#### PUT /auth/update-user
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

#### POST /links/store
- **Description**: Store a new link for processing into a gist.
- **Request Body**:
    ```json
    {
      "user_id": "user123",
      "link": {
        "category": "Technology",
        "url": "https://example.com/article",
        "title": "Article Title"
      }
    }
    ```
- **Responses**:
    - **200**: Link stored successfully
        ```json
        {
          "message": "Link stored successfully",
          "link": {
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
          }
        }
        ```
    - **500**: Error storing link

#### PUT /links/update-gist-status/:user_id/:link_id
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

#### GET /links/:user_id
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

#### POST /gists/add/:user_id
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
              "segment_duration": 120,
              "segment_index": 0,
              "segment_title": "Test Segment"
            }],
            "status": {
              "is_done_playing": false,
              "is_now_playing": false,
              "playback_time": 0
            },
            "users": 0
          }
        }
        ```
    - **400**: Missing required fields
    - **500**: Error creating gist

#### PUT /gists/update/:user_id/:gist_id
- **Description**: Update gist status and metadata.
- **Parameters**:
    - `user_id`: User's unique identifier
    - `gist_id`: Gist's unique identifier
- **Request Body**:
    ```json
    {
      "status": {
        "is_done_playing": true,
        "is_now_playing": false,
        "playback_time": 120
      },
      "is_played": true,
      "ratings": 4
    }
    ```
- **Responses**:
    - **200**: Gist updated successfully
    - **404**: User or gist not found
    - **500**: Error updating gist

#### GET /gists/:user_id
- **Description**: Retrieve all gists for a user.
- **Parameters**:
    - `user_id`: User's unique identifier
- **Responses**:
    - **200**: Returns array of gists
    - **404**: User not found
    - **500**: Error fetching gists

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
