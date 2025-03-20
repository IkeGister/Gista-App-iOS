# UI Wireframes

1. Onboarding Screen

-------------------------------------
| [Logo / App Name]                 |
|                                   |
| [Short tagline:                   ||  "Listen to your saved articles"] |
|                                   |
| [Illustration or icon]            |
|                                   |
| [Bullet points or quick steps]:   |
|   1. Share an article             |
|   2. Convert to audio             |
|   3. Listen offline anywhere      |
|                                   |
| [Button: "Get Started"]           |
-------------------------------------

Key Elements

Logo/App Name: A simple brand representation at the top (center-aligned).
Tagline: One to two lines explaining the app’s core benefit.
Illustration/Icon: Could show a visual metaphor (e.g., phone with audio wave, or headphones around a document).
Quick Steps: Three short bullet points describing how to use the app.
Primary CTA (“Get Started”): Tapping this leads to sign-in/sign-up flow.
Figma/Sketch Tips

Create a Frame/Artboard matching iPhone size (e.g., iPhone 14).
Add a Text layer for the tagline and bullet points.
Use a Shape/Vector or imported illustration for the visual element.
Style the button with a brand color and round corners to maintain iOS design language.

2. Main Library (Home) Screen
Wireframe Description

---------------------------------------------------
| Navigation Bar (Title: "Your Library")          |
|  [Menu Icon]          [Search Icon]             |
---------------------------------------------------
| [Mini Player (collapsed at bottom)              |
|  showing current or last played item]           |
|-------------------------------------------------|
| [Scroll/List of Gists / Categories]            |
|   Gist 1: "Tech Articles"  (X items)            |
|   Gist 2: "Travel"         (X items)            |
|   Gist 3: "Misc"           (X items)            |
|-------------------------------------------------|
| [All Items Section]                             |
|   - Item 1 (Title, small artwork, date added)   |
|   - Item 2                                      |
|   - Item 3                                      |
|    ...                                          |
---------------------------------------------------
| [Tab Bar or Quick Navigation Buttons]           |
|  (Home)  (Profile) (Subscriptions)             |
---------------------------------------------------

Key Elements

Navigation Bar:

Title: “Your Library” or “Home.”
Menu Icon to open Settings/Profile if you prefer a side drawer, or a direct nav button.
Search Icon to filter articles/podcasts.
Mini Player (Collapsed):

Displays the currently playing (or last played) item’s title/artwork.
Tapping it opens the Playback Screen in full view.
Main Content:

A list of Gists (categories/playlists). Each gist might have an icon or artwork representing that category.
An All Items section or a dedicated tab showing all articles in one list.
Tab Bar or Additional Navigation:

Could include Home, Profile, and Subscription or Settings.
Figma/Sketch Tips

For the List layout, consider using a vertical scrolling frame with Auto Layout in Figma.
Use Components for repeated items (e.g., gist cells, article cells) to keep design consistent.
The mini player can be a floating component pinned to the bottom with an elevated background.

3. Playback Screen (Full Player)
Wireframe Description

---------------------------------------------------
| [Artwork Thumbnail]          (X icon to close)  |
|-------------------------------------------------|
| [Article Title]                                 |
| [Category or Gist Name]                         |
| [Progress Bar: 00:00 -------------- 05:30 ]     |
|-------------------------------------------------|
| [ Play/Pause ] [<< Prev] [ Next >>] [... More]  |
|-------------------------------------------------|
| [Audio Settings/Volume Slider (optional)]       |
| [Playback Speed (optional, future)]             |
---------------------------------------------------
| [Additional Info Panel (toggle?) ]              |
|   - Date added                                  |
|   - Original Source Link (opens Safari)         |
---------------------------------------------------

Key Elements

Artwork & Title: Prominently display the article cover or placeholder image.
Playback Controls: Standard audio buttons (play/pause, next/previous track).
Progress Bar: Visual timeline with current time and total duration.
Additional Info: Could be a dropdown or swipe-up panel showing extended metadata.
Close Button or Swipe Down: A common iOS pattern is to swipe down to close the fullscreen player.
Figma/Sketch Tips

Use a vertical layout with Auto Layout in Figma.
The progress bar can be designed with a rectangle and circle overlay for the scrubber.
Include a “close” icon in the top-right corner to return to the main library.

Putting It All Together
Create a Figma File (or Sketch) with separate Frames/Artboards for each screen size (iPhone 14, iPad, etc.).
Onboarding Flow: Link the “Get Started” button to your Sign-in/Sign-up screens.
Home/Main Library: Link Gist items and “All Items” to the List of Podcasts (or the Playback Screen if a user taps a podcast).
Playback Screen: Link the “X icon” (close) or the device’s swipe-down gesture back to the Home screen.
Menu/Profile: If you have a separate Profile or Settings screen, link it from the navigation bar or tab bar.