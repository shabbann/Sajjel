# Release Notes - Sajjel (Chat Notes)

## Version [Date - e.g., 2024-07-26]

### ✨ Features & Improvements

*   **Unified Tag Styling:** Modern, colorful tags applied consistently in chat bubbles and input selector across light/dark modes.
*   **Global Tag Filter:** Filter button in AppBar now shows all tags from the entire app.
*   **Tag Management:**
    *   Added "Add Tag" button to chat input tag selector.
    *   Added long-press to remove global tags (with confirmation) in chat input tag selector.
    *   Added long-press to remove tags from individual notes in chat bubbles.
*   **Audio Playback Fix:** Prevented multiple audio notes from playing simultaneously.
*   **Location Performance:** Improved location attachment speed and reliability by checking services/permissions and using last known position.
*   **UI Refinements:**
    *   Removed drawer menu.
    *   Updated chat bubble appearance (using Material 3 surface colors in light mode).
    *   Added "Built with ❤️..." credit to settings.

### 🐛 Bug Fixes

*   Fixed state management errors related to tag removal/addition and screen initialization.
*   Resolved "read-only list" error during tag interactions.
*   Corrected build errors related to theme color usage. 