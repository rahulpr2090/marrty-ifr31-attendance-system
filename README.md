# Marrty IFR31 — Intelligent Face Recognition Attendance System

> AI-powered attendance management with face recognition, geofence validation, and real-time analytics.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![AWS CDK](https://img.shields.io/badge/AWS-CDK-orange.svg)](https://aws.amazon.com/cdk/)
[![ESP32](https://img.shields.io/badge/ESP32S3-Firmware-red.svg)](https://www.espressif.com/)

## Overview

Marrty IFR31 is a complete attendance management system designed for educational institutions. It combines **face recognition**, **liveness detection**, **GPS geofencing**, and **real-time analytics** into a single, deployable system.

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Flutter App │────▶│  API Gateway  │────▶│  Lambda (51 fn) │
│  (Mobile)    │     │  + Cognito    │     │  + DynamoDB     │
└─────────────┘     └──────────────┘     │  + Rekognition  │
                                          │  + S3            │
┌─────────────┐                          └─────────────────┘
│  ESP32S3    │──────────────────────────────────┘
│  (Kiosk)    │
└─────────────┘
```

## Components

| Component | Tech Stack | Location |
|-----------|-----------|----------|
| **Mobile App** | Flutter 3.x, Riverpod, ML Kit, GoRouter | `app/` |
| **Backend** | AWS Lambda (Node 18), TypeScript, Zod | `backend/` |
| **Infrastructure** | AWS CDK, Cognito, DynamoDB, API Gateway, Rekognition | `infrastructure/` |
| **Firmware** | ESP32S3, Arduino C++, TFT Display, Camera | `firmware/` |

## Features

### Authentication & Security
- 🔐 AWS Cognito with MFA (TOTP) support
- 🔑 Role-based access (HOD / Lecturer / Sub-Admin)
- 🛡️ JWT authorization on all API endpoints
- 🔄 Force password change on first login

### Attendance
- 📸 Face recognition via AWS Rekognition
- 👁️ Liveness detection (blink detection via ML Kit)
- 📍 GPS geofence validation
- 📋 Manual attendance with audit trail
- 🔄 Offline queue for kiosk (auto-syncs when online)

### Management
- 👨‍🎓 Student CRUD with semester shift and passout
- 👨‍🏫 Faculty management
- ⏰ Configurable session timings (Morning, Interval, Afternoon, Evening)
- 📊 Reports (Excel/PDF generation)
- 📈 Analytics: streaks, defaulters, anomalies, mood trends

### Hardware (Kiosk)
- ESP32S3 with camera module
- 1.8" TFT display with touch input
- Buzzer feedback for scan results
- SPIFFS offline queue (30 scans)
- Auto WiFi reconnection

## Quick Start

### Prerequisites
- [Flutter 3.x](https://flutter.dev/docs/get-started/install)
- [Node.js 18+](https://nodejs.org/)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [AWS CDK](https://docs.aws.amazon.com/cdk/latest/guide/getting_started.html)

### 1. Deploy Infrastructure

```bash
cd infrastructure
npm install
npx cdk bootstrap   # First time only
npx cdk deploy
```

Copy the output values:
- `ApiUrl` → paste in `app/lib/core/constants/api_constants.dart`
- `UserPoolId` → for Cognito configuration
- `ApiUrl` → paste in `firmware/config.h`

### 2. Build Backend

```bash
cd backend
npm install
npx esbuild src/handlers/**/*.ts \
  --bundle --platform=node --target=node18 \
  --outdir=dist/handlers --external:@aws-sdk/* --format=cjs
```

### 3. Configure & Run App

1. Update `app/lib/core/constants/api_constants.dart` with your API URL
2. Run:

```bash
cd app
flutter pub get
flutter run        # Debug
flutter build apk  # Release APK
```

### 4. Flash Firmware (Optional)

1. Update `firmware/config.h` with WiFi, API URL, and API key
2. Flash to ESP32S3 using Arduino IDE or PlatformIO

## Project Structure

```
Marrty_IF31/
├── app/                          # Flutter mobile app
│   ├── lib/
│   │   ├── core/                 # Theme, network, constants
│   │   ├── features/             # Feature modules
│   │   │   ├── auth/             # Login, MFA, password change
│   │   │   ├── dashboard/        # Today stats, streaks, anomalies
│   │   │   ├── students/         # CRUD, enrollment
│   │   │   ├── attendance/       # Manual + history tabs
│   │   │   ├── face_scan/        # Camera, liveness, recognition
│   │   │   ├── settings/         # Profile, security, HOD config
│   │   │   └── geofence/         # Zone management
│   │   └── shared/               # Common widgets
│   └── pubspec.yaml
├── backend/                      # Lambda handlers
│   └── src/
│       ├── handlers/             # 51 Lambda functions
│       │   ├── auth/             # login, me, verify-mfa, change-password
│       │   ├── student/          # CRUD, semester-shift, bulk-import
│       │   ├── faculty/          # CRUD
│       │   ├── face/             # enroll, search, remove
│       │   ├── attendance/       # mark, manual, records, analytics
│       │   ├── session/          # init, list, update
│       │   ├── geofence/         # get, update, check
│       │   ├── report/           # generate, share
│       │   ├── audit/            # logs
│       │   └── bugs/             # create, list, update
│       ├── lib/                  # Shared utilities
│       │   ├── auth.ts           # JWT extraction, role enforcement
│       │   ├── db.ts             # DynamoDB helpers
│       │   ├── validators.ts     # Zod schemas
│       │   └── index.ts          # Barrel export
│       └── types/                # TypeScript interfaces
├── infrastructure/               # AWS CDK stack
│   ├── lib/
│   │   ├── marrty-stack.ts       # Main CDK stack
│   │   └── constructs/
│   │       └── lambda-api.ts     # API Gateway + Lambda construct
│   └── bin/
│       └── infrastructure.ts     # CDK app entry
└── firmware/                     # ESP32S3 Arduino firmware
    ├── firmware.ino              # Main entry
    ├── config.h                  # WiFi, API, pin configuration
    ├── camera.h/cpp              # OV2640 camera driver
    ├── display.h/cpp             # ST7735 TFT display
    ├── wifi_mgr.h/cpp            # WiFi connection manager
    ├── api_client.h/cpp          # HTTPS API client
    ├── offline_queue.h/cpp       # SPIFFS scan queue
    ├── state_machine.h/cpp       # App state machine
    ├── touch.h/cpp               # Capacitive touch input
    └── buzzer.h/cpp              # Audio feedback
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/login` | No | Login with email/password |
| POST | `/auth/verify-mfa` | No | Verify MFA code |
| POST | `/auth/change-password` | No | Change temp password |
| GET | `/auth/me` | Yes | Get current user profile |
| POST | `/auth/sub-admins` | HOD | Create sub-admin |
| GET | `/students` | Yes | List students |
| POST | `/students` | Yes | Create student |
| POST | `/face/enroll` | Yes | Enroll face images |
| POST | `/face/search` | Yes | Search face in collection |
| POST | `/attendance/mark` | API Key | Mark via kiosk |
| POST | `/attendance/mark-mobile` | Yes | Mark via mobile app |
| POST | `/attendance/manual` | Yes | Manual attendance |
| GET | `/attendance/today` | Yes | Today's stats |
| GET | `/sessions` | Yes | List sessions |
| POST | `/sessions/init` | HOD | Initialize default sessions |
| GET | `/geofence` | Yes | Get geofence config |
| PUT | `/geofence` | HOD | Update geofence |
| POST | `/geofence/check` | Yes | Check if point is in zone |

## Configuration

### App Configuration
Edit `app/lib/core/constants/api_constants.dart`:
```dart
static const baseUrl = 'https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/api';
```

### Firmware Configuration
Edit `firmware/config.h`:
```c
#define WIFI_SSID     "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define API_BASE_URL  "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/api"
#define API_KEY       "YOUR_API_KEY"
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Credits

- **Developer:** RAHUL PR ([@rahulpr2000](https://github.com/rahulpr2000))
- **Organization:** [Marrty LLC](https://github.com/marrty)
- **Institution:** Dept. of Computer Engineering, HGPC
