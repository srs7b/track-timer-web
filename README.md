# TRACK.TIME ⚡️

**Elite Track & Field Performance Analytics**

TRACK.TIME is a professional-grade timing and analytics platform designed for elite athletes and coaches. By bridging the gap between custom BLE timing hardware and sophisticated data visualization, Track.Time provides real-time insights into sprinting mechanics, velocity curves, and performance trends.

---

## 🚀 Key Modules

### ⏱️ Record & Sync
Live session capture via low-latency Bluetooth (BLE) connection to custom TrackNode hardware.
- **Precision Timing**: Automatically handles multi-gate timing configurations.
- **Audio-Cued Starts**: Integrated "3-2-1-Gunshot" sequence with synchronized hardware trigger.
- **Visual Feedback**: Real-time status indicators for heartbeat, gate hits, and diagnostic logs.

### 📊 Comparison Analytics
Deep-dive into athlete performance with high-fidelity visualizations.
- **Velocity Curves**: Smoothed, high-contrast charts comparing multiple runs or athletes.
- **Pattern Tracking**: Automatic calculation of Personal Bests (PBs) and rolling averages.
- **Series Management**: Group runs by session for consolidated reporting.

### 🏆 Leaderboard (Rank)
Competitive tracking across the entire athlete roster.
- **Dynamic Highlights**: Best-in-class runs are highlighted in signature Velocity branding.
- **Filtered Insights**: Rank athletes by category, distance, or surface type.

### 🤖 AI Coach
Next-generation LLM integration for automated data interpretation.
- **Semantic Analysis**: Detailed coaching feedback based on raw timing data.
- **Trend Identification**: Discover subtle performance plateaus or breakthroughs that traditional stats miss.

---

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Web, macOS, iOS, Android)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Persistence**: [Sqflite](https://pub.dev/packages/sqflite) (with FFI for Desktop/Web)
- **Connectivity**: [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) (BLE)
- **Charts**: [fl_chart](https://pub.dev/packages/fl_chart)
- **AI Engine**: [Google Generative AI](https://pub.dev/packages/google_generative_ai) (Gemini)

---

## 📦 Getting Started

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

---

## 📡 Hardware Integration (TrackNode)

Track.Time is optimized for use with **TrackNode v1.0** hardware.
- **BLE Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Timing Characteristic**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **Control Characteristic**: `83416a4a-1081-424a-a43b-551717f9175a` (Used for START/STOP/CALIBRATE commands)

---

## 🎨 Design Philosophy

Track.Time utilizes a custom **Velocity Design System**:
- **Contrast**: High-visibility dark mode optimized for outdoor track conditions.
- **Typography**: Precision-aligned technical fonts (Outfit, Inter).
- **Aesthetics**: Glassmorphism, vibrant primary accents, and subtle micro-animations for a premium "pro-tools" feel.

---

© 2026 Track.Time Performance Systems. All Rights Reserved.
