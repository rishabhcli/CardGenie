# Microphone & Speech Recognition Permissions Setup Required

## Overview
The voice recording feature requires microphone access and speech recognition permissions. These need to be added to the Xcode project settings.

## Required Permissions

Add these keys to your project's Info section in Xcode:

### 1. Microphone Usage Description
- **Key**: `NSMicrophoneUsageDescription`
- **Type**: String
- **Value**: `CardGenie needs microphone access to record your lectures and convert them to flashcards.`

### 2. Speech Recognition Usage Description
- **Key**: `NSSpeechRecognitionUsageDescription`
- **Type**: String
- **Value**: `CardGenie uses speech recognition to transcribe your voice recordings into text for flashcard generation.`

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

✅ **Microphone Access** - Users can record lectures, study notes, and verbal explanations
✅ **Speech Recognition** - Convert spoken words to text automatically
✅ **Real-Time Transcription** - Live transcription as the user speaks
✅ **Offline Support** - After first use, works without internet connection

## Privacy First

All voice and speech operations:
- Are on-device after initial setup
- Never uploaded to any server
- Audio files stored locally only
- Transcription happens locally via Speech framework
- Can be deleted anytime
- User has full control

## How It Works

### First Time Setup
1. User taps "Record Lecture"
2. App requests microphone permission
3. App requests speech recognition permission
4. Initial transcription may require internet (downloads language model)
5. Subsequent uses work completely offline

### Recording Flow
1. User starts recording
2. Real-time transcription begins
3. Live text appears as they speak
4. User stops recording
5. Audio saved locally
6. User can generate flashcards or reset

### Audio Storage
- Audio files saved to app's Documents directory
- Format: M4A (AAC encoding)
- Quality: High (44.1 kHz)
- Linked to StudyContent for reference
- Deleted when content deleted

## Testing

After adding permissions:
1. Clean build folder (Cmd+Shift+K)
2. Rebuild project
3. Run on simulator or device
4. Tap "Record Lecture" from the + menu
5. Grant microphone permission
6. Grant speech recognition permission
7. Speak clearly and watch live transcription

## Note

### For iOS Simulator
- Microphone works in simulator (uses Mac mic)
- Speech recognition works with internet
- Audio recording works fully
- Great for testing transcription quality

### For Physical Device
- Full offline support after first use
- Better microphone quality
- Native audio experience
- Recommended for final testing

## Technical Details

### Speech Framework
- Uses `SFSpeechRecognizer` for transcription
- Supports real-time recognition
- Automatic punctuation and capitalization
- Language-aware (currently English)

### Audio Recording
- Uses `AVAudioEngine` for capture
- Uses `AVAudioRecorder` for saving
- High quality AAC encoding
- Mono channel for efficiency

### Authorization States
1. `.notDetermined` - Never asked
2. `.denied` - User denied
3. `.restricted` - Device restrictions
4. `.authorized` - Permission granted

## Troubleshooting

### "Microphone Permission Required"
- User denied microphone access
- Guide them to Settings > Privacy & Security > Microphone
- Enable CardGenie in the list

### "Speech Recognition Not Available"
- First use requires internet connection
- Language model needs to download
- After download, works offline
- Check device supports speech recognition

### "Audio Engine Error"
- Another app is using microphone
- Close other audio apps
- Restart CardGenie
- Check device microphone works

## Languages Supported

Currently configured for:
- 🇺🇸 English (US)

Can be extended to support:
- 🇬🇧 English (UK)
- 🇪🇸 Spanish
- 🇫🇷 French
- 🇩🇪 German
- 🇨🇳 Chinese
- 🇯🇵 Japanese
- And 50+ more languages

To add more languages, modify `SpeechToTextConverter.swift`:
```swift
private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
```

## Performance Notes

### Optimal Recording Conditions
✅ Quiet environment
✅ Clear speech
✅ Normal speaking pace
✅ Good microphone position
✅ Minimize background noise

### Recording Limits
- iOS typically allows ~1 minute of continuous recognition
- For longer recordings, stop and restart
- Or transcribe saved audio files offline

### Battery Usage
- Moderate battery usage during recording
- Audio engine is power-efficient
- Speech recognition is on-device (low power)

## Related Documentation

See also:
- `CAMERA_PERMISSIONS_SETUP.md` - Photo scanning permissions
- `TASK_1.4_COMPLETE.md` - Photo scanning implementation
- `TASK_2.1_COMPLETE.md` - Voice recording implementation (when available)

---

**Status**: Documentation complete. Ready to add permissions to Xcode project.

After adding these permissions, rebuild the app and test the voice recording feature for the full multi-modal CardGenie experience!
