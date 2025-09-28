# Design Document

## Overview

The presentation mode feature provides a dedicated screen with left and right navigation controls that send directional commands through the existing socket connection. The design follows KDE Connect's presentation remote interface pattern with two prominent buttons for slide navigation.

## Architecture

The presentation mode will integrate with the existing Flutter application architecture:

- **UI Layer**: New `PresentationModeScreen` widget with navigation controls
- **Service Layer**: Utilizes existing `SocketClient` service for message transmission
- **Navigation**: Integrates with Flutter's navigation system from the home screen

### Component Interaction Flow

```
Home Screen → Presentation Mode Screen → SocketClient → Remote Device
     ↑              ↓                        ↓
Navigation     Button Press              Message Send
```

## Components and Interfaces

### 1. PresentationModeScreen Widget

**Purpose**: Main UI component for presentation control interface

**Key Properties**:
- `deviceName`: String - Connected device name for display
- `deviceIp`: String - Device IP for connection reference
- `socketClient`: SocketClient instance - Shared from home screen

**Key Methods**:
- `_sendLeftCommand()`: Sends "left" message via socket
- `_sendRightCommand()`: Sends "right" message via socket
- `_showConnectionError()`: Displays error when socket unavailable

### 2. Navigation Integration

**Home Screen Integration**:
- Update existing "Presentation remote" tile onTap handler
- Pass required parameters (deviceName, deviceIp, socketClient) to new screen
- Use Navigator.push() for screen transition

### 3. Socket Message Protocol

**Message Format**: Leverages existing SocketClient.sendMessage() method
- Left navigation: `socketClient.sendMessage("left")`
- Right navigation: `socketClient.sendMessage("right")`

**Message Structure**: Uses existing JSON protocol
```json
{
  "type": "message",
  "data": "left" | "right",
  "timestamp": <milliseconds_since_epoch>
}
```

## Data Models

### PresentationCommand Enum
```dart
enum PresentationCommand {
  left,
  right
}
```

### Connection State
- Utilizes existing `SocketClient.isConnected` property
- No additional state management required

## Error Handling

### Connection Errors
- **Detection**: Check `socketClient.isConnected` before sending commands
- **User Feedback**: Display SnackBar with error message
- **Recovery**: Allow retry without leaving screen

### Message Send Failures
- **Graceful Degradation**: Show visual feedback even if send fails
- **Logging**: Utilize existing debug logging in SocketClient
- **User Notification**: Brief error message via SnackBar

### Navigation Errors
- **Parameter Validation**: Ensure required parameters are passed
- **Fallback**: Return to home screen if critical parameters missing

## Testing Strategy

### Unit Tests
1. **Widget Tests**:
   - Verify button rendering and layout
   - Test button press handlers
   - Validate error state display

2. **Integration Tests**:
   - Test navigation from home screen
   - Verify socket message sending
   - Test connection error scenarios

### Manual Testing Scenarios
1. **Happy Path**:
   - Navigate to presentation mode
   - Send left/right commands successfully
   - Verify commands received on server side

2. **Error Scenarios**:
   - Test with disconnected socket
   - Test navigation without proper parameters
   - Test rapid button pressing

3. **UI/UX Testing**:
   - Verify KDE Connect-like appearance
   - Test button feedback and responsiveness
   - Validate device information display

## UI Design Specifications

### Layout Structure
```
AppBar (Device Info)
├── Device Name
└── Connection Status

Body (Centered Layout)
├── Left Button (50% width)
│   ├── Left Arrow Icon
│   └── "Previous" Label
└── Right Button (50% width)
    ├── Right Arrow Icon
    └── "Next" Label
```

### Visual Design
- **Button Style**: Large, prominent buttons similar to existing FeatureTile
- **Color Scheme**: Consistent with app theme (grey.shade700 background)
- **Icons**: Material Design arrow icons (Icons.arrow_back, Icons.arrow_forward)
- **Spacing**: Adequate padding for touch targets
- **Feedback**: Material ripple effects on button press

### Responsive Design
- Buttons scale appropriately on different screen sizes
- Maintain minimum touch target size (48dp)
- Landscape orientation support

## Implementation Notes

### Code Organization
- Create new file: `lib/pages/presentation_mode_screen.dart`
- Follow existing code patterns from `home.dart`
- Maintain consistent naming conventions

### Dependencies
- No additional dependencies required
- Utilizes existing Flutter Material Design components
- Leverages existing SocketClient service

### Performance Considerations
- Minimal state management (stateless where possible)
- Efficient button press handling
- No continuous polling or background tasks