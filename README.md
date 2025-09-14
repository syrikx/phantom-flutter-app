# Phantom Flutter App

Flutter equivalent of phantom-test-app with Phantom wallet integration

## Features

- **Dual Connection Methods**: Toggle between SDK-style and Deep Link wallet connections
- **Mock Phantom SDK**: Simulated wallet functionality with Google authentication
- **Deep Link Integration**: Real Phantom app connection via custom URL schemes
- **Message Signing**: Sign arbitrary messages with connected wallet
- **SOL Transactions**: Send test transactions on Solana devnet
- **Korean UI**: Matching the original React Native app interface

## Getting Started

### Prerequisites
- Flutter SDK (version >=3.0.0)
- Android Studio/Xcode for platform builds
- Phantom wallet app (for deep link testing)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/syrikx/phantom-flutter-app.git
cd phantom-flutter-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building APK

To build a release APK:
```bash
flutter build apk --release
```

## Architecture

- **main.dart**: App entry point with connection method toggle
- **wallet_screen.dart**: SDK-style wallet interface
- **phantom_deep_link_screen.dart**: Deep link wallet interface
- **phantom_wallet_service.dart**: Mock wallet service implementation

## Configuration

The app includes pre-configured URL schemes for deep linking:
- Android: `phantomflutterapp://`
- iOS: `phantomflutterapp://`

## Testing

Run tests with:
```bash
flutter test
```

## License

This project is for educational and testing purposes.
