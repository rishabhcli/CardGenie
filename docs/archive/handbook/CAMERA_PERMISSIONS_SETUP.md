# Camera Permissions Setup Required

## Overview
The photo scanning feature requires camera and photo library access permissions. These need to be added to the Xcode project settings.

## Required Permissions

Add these keys to your project's Info section in Xcode:

### 1. Camera Usage Description
- **Key**: `NSCameraUsageDescription`
- **Type**: String
- **Value**: `CardGenie needs camera access to scan your notes and textbooks for instant flashcard generation.`

### 2. Photo Library Usage Description
- **Key**: `NSPhotoLibraryUsageDescription`
- **Type**: String
- **Value**: `CardGenie needs photo library access to let you select images of your notes for text extraction.`

### 3. Photo Library Add Usage Description (iOS 14+)
- **Key**: `NSPhotoLibraryAddUsageDescription`
- **Type**: String
- **Value**: `CardGenie can save scanned images to your photo library for future reference.`

## How to Add in Xcode

### Method 1: Using Info Tab
1. Open CardGenie.xcodeproj in Xcode
2. Select the CardGenie target
3. Go to the "Info" tab
4. Click the "+" button under "Custom iOS Target Properties"
5. Add each key above with its corresponding value

### Method 2: Using Target Settings
1. Open CardGenie.xcodeproj in Xcode
2. Select the CardGenie target
3. Go to "Build Settings"
4. Search for "Info.plist"
5. Find "Info.plist Values"
6. Add the keys and values there

## What These Permissions Enable

✅ **Camera Access** - Users can take photos of notes/textbooks directly in the app
✅ **Photo Library** - Users can select existing photos from their library
✅ **Save to Library** - Users can save scanned content for later reference

## Privacy First

All camera and photo operations:
- Are on-device only
- Never uploaded to any server
- Processed locally using Vision framework
- Deleted after flashcard generation (unless user saves)

## Testing

After adding permissions:
1. Clean build folder (Cmd+Shift+K)
2. Rebuild project
3. Run on simulator or device
4. Tap "Scan Notes" from the + menu
5. App will request camera/photo permissions on first use

## Note

For iOS Simulator testing, the camera won't work (no camera hardware), but the photo library picker will work with sample images.
