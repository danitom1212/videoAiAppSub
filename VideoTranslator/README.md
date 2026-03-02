# Video Translator iOS App

An AI-powered iOS application for real-time video translation with subtitles in over 60 languages.

## Features

### Core Functionality
- **Video Player**: Custom video player with AVFoundation integration
- **Speech-to-Text**: AI-powered audio transcription using iOS Speech Framework
- **Neural Translation**: Integration with OpenAI API for high-quality translations
- **Real-time Subtitles**: Synchronized subtitle overlay with customizable styling
- **Multi-language Support**: Support for 60+ languages including RTL languages

### Advanced Features
- **Self-Learning**: Machine learning capabilities that improve translation accuracy based on user corrections
- **Offline Mode**: Built-in translation using Apple's NaturalLanguage framework
- **Subtitle Export**: Export translations in SRT format
- **Language Detection**: Automatic source language detection
- **Customizable UI**: Multiple subtitle styles and themes

### User Experience
- **Modern iOS Design**: Clean, intuitive interface following iOS design guidelines
- **Gesture Controls**: Tap to toggle between original and translated text
- **Picture-in-Picture**: Support for PiP mode
- **File Management**: Import videos from photo library or files
- **Settings & Preferences**: Comprehensive settings for customization

## Technical Architecture

### Project Structure
```
VideoTranslator/
├── VideoTranslator/
│   ├── Models/
│   │   ├── Subtitle.swift
│   │   └── Language.swift
│   ├── Views/
│   │   ├── VideoPlayerViewController.swift
│   │   ├── VideoControlsView.swift
│   │   ├── SubtitleOverlayView.swift
│   │   ├── LanguageSelectionViewController.swift
│   │   ├── SettingsViewController.swift
│   │   └── AVPlayerView.swift
│   ├── Services/
│   │   ├── TranscriptionService.swift
│   │   ├── TranslationService.swift
│   │   └── SubtitleManager.swift
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── ViewController.swift
└── VideoTranslator.xcodeproj/
```

### Key Components

#### Models
- **Subtitle**: Represents timed text segments with original and translated content
- **Language**: Comprehensive language support with metadata

#### Views
- **VideoPlayerViewController**: Main controller coordinating all components
- **VideoControlsView**: Custom playback controls with seek, volume, and fullscreen
- **SubtitleOverlayView**: Rendered subtitles with customizable styling
- **LanguageSelectionViewController**: Dual-language picker interface
- **SettingsViewController**: App configuration and preferences

#### Services
- **TranscriptionService**: Speech-to-text using iOS Speech Framework
- **TranslationService**: OpenAI API integration with fallback to built-in translation
- **SubtitleManager**: Subtitle synchronization and learning capabilities

### Dependencies
- **AVFoundation**: Video playback and audio processing
- **Speech**: On-device speech recognition
- **NaturalLanguage**: Built-in translation capabilities
- **UIKit**: UI framework
- **Foundation**: Core functionality

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 15.0+ target
- Swift 5.0+

### API Configuration
1. Obtain an OpenAI API key from https://platform.openai.com/
2. In `TranslationService.swift`, replace `YOUR_API_KEY_HERE` with your actual API key
3. For production, store the API key securely in Keychain

### Building the App
1. Open `VideoTranslator.xcodeproj` in Xcode
2. Select your development team and signing certificate
3. Build and run on a simulator or physical device

### Permissions
The app requires the following permissions (configured in Info.plist):
- **Microphone Access**: For audio transcription
- **Photo Library Access**: For importing videos

## Usage Guide

### Basic Workflow
1. **Import Video**: Tap "📁 Import Video" to select a video from your library
2. **Select Languages**: Tap "🌐 Language" to choose source and target languages
3. **Transcribe**: The app automatically transcribes audio when video loads
4. **Translate**: Tap "🔄 Translate" to translate subtitles to target language
5. **Watch**: Play the video with real-time translated subtitles

### Advanced Features
- **Toggle Translation**: Tap on subtitles to switch between original and translated text
- **Customize Style**: Go to Settings to change subtitle appearance
- **Export Subtitles**: Export translations in SRT format for external use
- **Learning Mode**: The app learns from your corrections to improve future translations

### Settings Options
- **API Configuration**: Set up OpenAI API key
- **Subtitle Style**: Choose between Default, Minimal, or Prominent styles
- **Auto-translate**: Toggle automatic translation after transcription
- **Learning Data**: Manage and clear translation learning data

## Self-Learning Capabilities

The app includes machine learning features that improve translation accuracy over time:

### How It Works
1. **User Corrections**: When users edit translations, the corrections are stored
2. **Pattern Recognition**: The app identifies patterns in user corrections
3. **Improved Suggestions**: Future translations incorporate learned patterns
4. **Context Awareness**: Learning is context-aware based on language pairs

### Data Management
- All learning data is stored locally on device
- Users can clear learning data at any time
- No personal data is transmitted to external servers
- Learning data is encrypted using iOS Keychain

## API Integration

### OpenAI API
- Used for high-quality neural translations
- Supports all major languages
- Rate limiting implemented to avoid API limits
- Fallback to built-in translation when API is unavailable

### Built-in Translation
- Uses Apple's NaturalLanguage framework
- Available offline
- Supports major language pairs
- Lower quality but faster and more reliable

## Performance Considerations

### Optimization
- **Chunked Processing**: Audio is processed in 10-second chunks
- **Batch Translation**: Subtitles are translated in batches to respect API limits
- **Memory Management**: Proper cleanup of audio and video resources
- **Background Processing**: Transcription continues in background

### Limitations
- **API Rate Limits**: OpenAI API has usage limits
- **Processing Time**: Large videos may take time to transcribe
- **Accuracy**: Speech recognition accuracy varies with audio quality
- **Battery Usage**: Continuous processing can impact battery life

## Future Enhancements

### Planned Features
- **Voice Commands**: Control playback with voice commands
- **Cloud Sync**: Sync translations and learning data across devices
- **Collaborative Translation**: Share and improve translations with community
- **Video Export**: Export videos with burned-in subtitles
- **Real-time Translation**: Live translation during video calls

### Technical Improvements
- **Core ML Integration**: On-device ML models for faster processing
- **Advanced Audio Processing**: Noise reduction and audio enhancement
- **Multi-track Support**: Handle videos with multiple audio tracks
- **Streaming Support**: Support for online video sources

## Contributing

### Development Guidelines
- Follow Swift coding conventions
- Use SwiftUI for new components where appropriate
- Implement comprehensive unit tests
- Document all public APIs
- Ensure iOS accessibility guidelines are met

### Code Style
- Use meaningful variable and function names
- Implement proper error handling
- Use extensions for code organization
- Follow MVC/MVVM patterns
- Implement proper memory management

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Support

For issues and feature requests:
1. Check existing issues on GitHub
2. Create detailed bug reports with device and iOS version
3. Include logs and reproduction steps
4. Provide sample videos if applicable

## Acknowledgments

- OpenAI for the translation API
- Apple for the Speech and NaturalLanguage frameworks
- The iOS developer community for inspiration and feedback
