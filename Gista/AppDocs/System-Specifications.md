# System Specifications


System Specification Document
1. Purpose & Audience
Purpose

The application enables users to share articles (web links, PDFs, or documents) directly from their device (via the iOS Share Sheet) to be converted into AI-generated audio podcasts.
These audio podcasts are organized into “Gists” (playlists) based on article title/category and stored in the app for easy playback.
Audience

General smartphone and tablet users seeking a convenient way to “listen” to their read-later articles.
Users who value time efficiency and prefer audio consumption over reading.
Value Proposition

Streamlined curation of articles and documents into audio form for on-the-go consumption.
Helps users tackle the backlog of “saved for later” content in a user-friendly, accessible format.

2. Core Functionality
User Authentication

Sign-in via Apple or Google.
Collects minimal user details (name/alias, email).
Subscription Model

Free trial period.
Monthly and Annual subscription tiers (discounted annual rate).
In future iterations, potential credit-based limit for AI conversions and additional in-app purchases for extra credits.
Sharing & Podcast Generation

Seamless Share Flow: Users share articles/files to the app from Safari or another app with no additional prompts or previews.
Background Conversion: The app receives the shared link/document and sends it to an AI-driven API for audio generation.
Storage: Generated audio files are stored on the user’s device.
Notifications: Optional push notifications alert the user when the audio is ready.
Audio Playback

Basic audio playback (play, pause, skip forward/back, next/previous track).
Playlists (Gists): Automatically sorts content into categories using the article’s title/metadata.
Ability to listen to entire gist sequentially or select individual items.
Library & Management

Main list view of all generated audio podcasts, plus categorization into gists/playlists.
Ability to delete generated podcasts.
“All Items” tab for a consolidated list regardless of category.
Offline playback once audio is downloaded.
Privacy & Terms

Basic AI Terms & Conditions and Privacy agreement.
Only storing an email address for subscription and usage protection.
No other sensitive data (mic, location, etc.) collected.

3. Data & Integrations
AI Integration

Third-party (NotebookLM/Google-based) API, potentially via a custom backend hosted on Google Cloud.
The client app may directly connect to the API during prototyping; production may route through a backend layer.
Audio File Generation

Audio format, bit rate, and length not strictly defined yet (but must consider local device storage).
No transcripts stored—only audio files once generation is complete.
Local Persistence

Audio files stored directly on the user’s device.
Optionally, iCloud integration can be considered for future updates if needed.
Subscription Validation

Relies on App Store receipt validation to manage subscription status.