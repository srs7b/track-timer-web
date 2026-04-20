# tt_flutter
## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Web, macOS, iOS, Android)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Persistence**: [Sqflite](https://pub.dev/packages/sqflite) (with FFI for Desktop/Web)
- **Connectivity**: [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (BLE)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **AI Engine**: [Google Generative AI](https://pub.dev/packages/google_generative_ai) (Gemini)

---

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- TrackNode Hardware (for live recording)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/srs7b/track-timer-web.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d chrome
   ```

### Deployment
To deploy to GitHub Pages, use the provided deployment script:
```bash
chmod +x deploy.sh
./deploy.sh
```
Track.Time is optimized for use with **TrackNode v1.0** hardware.
- **BLE Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Timing Characteristic**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Control Characteristic**: `83416a4a-1081-424a-a43b-551717f9175a` (Used for START/STOP/CALIBRATE commands)

