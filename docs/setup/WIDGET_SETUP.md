# Widget Extension Setup Guide

This guide explains how to add the CardGenie Widgets extension to your Xcode project.

## Overview

The widget files have been created in the `CardGenieWidgets/` directory:
- `CardGenieWidgets.swift` - Widget bundle and shared data provider
- `DueCardsWidget.swift` - Small widget showing due flashcard count
- `StudyStreakWidget.swift` - Small widget showing study streak
- `Info.plist` - Widget extension metadata
- `CardGenieWidgets.entitlements` - App Group entitlements

## Adding the Widget Extension to Xcode

### Step 1: Create Widget Extension Target

1. Open `CardGenie.xcodeproj` in Xcode
2. In the project navigator, select the `CardGenie` project (blue icon at the top)
3. At the bottom of the targets list, click the `+` button to add a new target
4. Select **Widget Extension** from the template chooser
5. Configure the extension:
   - **Product Name**: `CardGenieWidgets`
   - **Include Configuration Intent**: ❌ Unchecked (we don't need configuration)
   - Click **Finish**
6. When prompted "Activate 'CardGenieWidgets' scheme?", click **Activate**

### Step 2: Replace Auto-Generated Files

Xcode will generate some default widget files. Replace them with our implementation:

1. Delete the auto-generated files:
   - `CardGenieWidgets.swift` (the default one Xcode created)
   - `CardGenieWidgetsBundle.swift` (if exists)
   - `CardGenieWidgetsLiveActivity.swift` (if exists)

2. Add our widget files to the target:
   - In Finder, navigate to `CardGenie/CardGenieWidgets/`
   - Drag these files into the `CardGenieWidgets` group in Xcode:
     - `CardGenieWidgets.swift`
     - `DueCardsWidget.swift`
     - `StudyStreakWidget.swift`
   - When prompted, ensure **"CardGenieWidgets" target** is checked

3. Replace the entitlements file:
   - Delete the auto-generated `CardGenieWidgets.entitlements` in Xcode
   - Add our `CardGenieWidgets.entitlements` file to the project

### Step 3: Configure App Groups

Widgets need to share data with the main app using App Groups.

#### For the Main App Target:

1. Select the `CardGenie` target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Click the **+** button under App Groups
5. Enter: `group.com.cardgenie.shared`
6. Click **OK**
7. Verify that `CardGenie.entitlements` is added to the project (it should be in `CardGenie/` folder)

#### For the Widget Extension Target:

1. Select the `CardGenieWidgets` target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** and add **App Groups**
4. Check the box next to `group.com.cardgenie.shared` (should already exist from main app)

### Step 4: Update Deployment Target

1. Select the `CardGenieWidgets` target
2. Go to **Build Settings**
3. Search for "Deployment Target"
4. Set **iOS Deployment Target** to **26.0** (match the main app)

### Step 5: Link SwiftData Models

The widgets need access to the main app's SwiftData models:

1. In the project navigator, expand the `CardGenie/Data/` folder
2. Select these model files:
   - `CoreModels.swift` (or equivalent with `Flashcard`, `StudyContent`, etc.)
   - `FlashcardModels.swift`
   - `SourceModels.swift`
3. In the File Inspector (right sidebar), under **Target Membership**:
   - Ensure ✅ `CardGenie` is checked
   - Also check ✅ `CardGenieWidgets`

This allows the widget to import and use the same models as the main app.

### Step 6: Update ModelContainer Configuration

Update the main app's `CardGenieApp.swift` to use the App Group:

```swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    groupContainer: .identifier("group.com.cardgenie.shared") // Add this line
)
```

Do the same in the fallback configuration (the `catch` block).

### Step 7: Build and Test

1. Select the **CardGenieWidgets** scheme from the scheme picker
2. Choose a simulator or device running iOS 26+
3. Build and run (⌘R)
4. This will launch the widget gallery where you can add the widgets to the home screen
5. Test both widgets:
   - **Due Cards Widget**: Shows count of flashcards due for review
   - **Study Streak Widget**: Shows current study streak with flame icon

## Troubleshooting

### Build Errors

**"No such module 'WidgetKit'"**
- Ensure deployment target is iOS 26.0+
- Clean build folder (⇧⌘K) and rebuild

**"Cannot find type 'Flashcard' in scope"**
- Verify model files are added to both targets (Step 5)
- Check that `import SwiftData` is in the widget files

**"Failed to create ModelContainer"**
- Verify App Groups are configured correctly (Step 3)
- Ensure both targets use the same group identifier: `group.com.cardgenie.shared`
- Check that entitlements files are added to the project

### Runtime Errors

**Widgets show "0" when data exists**
- Verify the main app's `ModelConfiguration` includes `groupContainer` (Step 6)
- Check that both app and widget use the same App Group identifier
- Try deleting the app and widgets, then reinstalling

**Widgets don't update**
- Widgets refresh on their own schedule (1-6 hours)
- Force refresh by:
  1. Long-press the widget
  2. Select "Edit Widget"
  3. Tap outside to dismiss
- Check Console.app for widget errors

## App Shortcuts Setup

The App Intents are already implemented in `CardGenie/App/AppIntents.swift` and will be automatically available once the main app is built. No additional configuration needed!

Available shortcuts:
- **Start Study Session** - Opens app and starts reviewing due cards
- **Ask Study Question** - Opens AI chat to ask a question
- **Get Due Cards Count** - Returns count of due flashcards
- **Generate Flashcards** - Generate cards from text input
- **Quick Add Flashcard** - Add a flashcard with front/back text

These will appear in:
- Settings → Siri & Search → CardGenie
- Shortcuts app → All Shortcuts → + → Apps → CardGenie

## Next Steps

Once the widget extension is set up, you can:

1. Add more widget sizes (Medium, Large)
2. Create additional widget types (Quick Study, AI Chat, etc.)
3. Add widget configuration options
4. Implement Live Activities for study sessions
5. Add more App Shortcuts

See `docs/features/WIDGETS_ROADMAP.md` for planned features.
