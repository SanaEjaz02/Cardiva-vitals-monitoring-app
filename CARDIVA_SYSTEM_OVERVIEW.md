# CARDIVA — Complete System Overview

> **AI-Based Wearable Health Monitoring and Emergency Response System**
> Final Year Project (FYP II) — Documentation for Viva, Maintenance, and Onboarding

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Purpose of the App](#2-purpose-of-the-app)
3. [Core Features](#3-core-features)
4. [Frontend Technology](#4-frontend-technology)
5. [Backend Technology](#5-backend-technology)
6. [Database Used](#6-database-used)
7. [State Management](#7-state-management)
8. [Authentication System](#8-authentication-system)
9. [APIs and Services](#9-apis-and-services)
10. [Firebase Services Used](#10-firebase-services-used)
11. [Folder Structure Explanation](#11-folder-structure-explanation)
12. [Main Screens and Their Purpose](#12-main-screens-and-their-purpose)
13. [Important Packages and Why They Are Used](#13-important-packages-and-why-they-are-used)
14. [Data Flow Architecture](#14-data-flow-architecture)
15. [Notification System](#15-notification-system)
16. [Local Storage Usage](#16-local-storage-usage)
17. [AI / ML Integration](#17-ai--ml-integration)
18. [Environment / Config Files](#18-environment--config-files)
19. [Build & Run Instructions](#19-build--run-instructions)
20. [Future Scope](#20-future-scope)

---

## 1. Project Overview

| Field | Value |
|---|---|
| **Project Name** | CARDIVA |
| **Full Name** | Cardiac Disease Intelligence and Vital Alert System |
| **Type** | Final Year Project (FYP II) |
| **Platform** | Flutter (Android + iOS) |
| **Language** | Dart (≥ 3.2.0) |
| **Flutter Version** | ≥ 3.38.4 |
| **Architecture** | Feature-first folder structure, clean separation of concerns |
| **Package Name** | `com.cardiva.cardiva` |
| **Firebase Project ID** | `cardiva-30297` |

CARDIVA is a cross-platform mobile application that monitors a patient's vital signs in real time, classifies their health status using a rule-based engine backed by on-device ML models, and automatically sends emergency alerts (SMS/WhatsApp + GPS location) to registered contacts when critical conditions are detected.

---

## 2. Purpose of the App

Modern wearable devices collect health data continuously, but most apps only *display* numbers — they do not *act* on them. CARDIVA bridges this gap.

**CARDIVA is designed to:**

- Continuously receive vital signs data from a wearable (heart rate, SpO2, HRV, respiration rate)
- Intelligently classify the patient's health status using medical thresholds and ML models
- Automatically send emergency SMS/WhatsApp alerts with GPS location to emergency contacts the moment a critical condition is detected
- Give patients and caregivers a clear, real-time picture of health trends through charts, reports, and an AI health assistant

**Target Users:**
- Elderly patients with cardiac conditions
- Patients recovering from surgery or illness at home
- Athletes requiring vitals monitoring during exercise
- Patients whose caregivers need remote monitoring

---

## 3. Core Features

### Real-Time Vital Monitoring
Streams heart rate, SpO2 (blood oxygen), HRV (heart rate variability), and respiration rate every 2 seconds.

### 4-Class Health Classification
Each vital reading is classified into one of four alert levels using a 2×2 decision matrix:

```
                    Vitals High-Risk?
                  YES              NO
Fall Detected?
    YES     → Emergency       → Fall Alert
    NO      → Vitals Alert    → Normal
```

### Automatic Emergency Response
When an emergency is detected, the app automatically:
1. Gets the patient's GPS location
2. Sends SMS/WhatsApp alert to all registered emergency contacts
3. Shows a high-priority in-app notification
4. Logs the event to the cloud

### Background Health Monitoring
The app continues monitoring health every 5 minutes even when closed or in the background.

### AI Health Assistant
A keyword-driven chatbot that educates users about their vitals and heart health.

### Health Reports
Generates daily and weekly PDF health reports with vital trends and analysis summaries.

### Emergency Contact Management
Users can add multiple emergency contacts and configure SMS attendants.

### Vital History & Charts
Interactive line charts showing vital trends over time, powered by `fl_chart`.

---

## 4. Frontend Technology

CARDIVA is built entirely with **Flutter**, Google's open-source UI toolkit.

**Why Flutter?**
- One codebase runs on both Android and iOS
- Highly customizable UI with smooth 60fps animations
- Strong community and plugin ecosystem
- Dart language is beginner-friendly and type-safe

**UI Design Principles Used:**
- Material Design 3 (Material You)
- Card-based layout with gradient header blobs
- Custom animated components (pulsing rings, sparklines)
- Skeleton loaders during data fetch
- Dark mode support

**Key UI Libraries:**
| Library | Purpose |
|---|---|
| `google_fonts` | Inter typeface throughout the app |
| `fl_chart` | Line charts for vital history |
| `lottie` | Smooth animations (splash screen, loading) |
| `flutter_markdown` | Render markdown in chatbot responses |

**Theming:**
- Primary color: `#0077B6` (deep medical blue)
- Status colors: Green → Cyan → Orange → Red (Normal → Stable → Warning → Emergency)
- Defined in `lib/theme/app_theme.dart`, `app_colors.dart`, `app_text_styles.dart`

---

## 5. Backend Technology

CARDIVA currently uses **Firebase** for authentication and is designed to connect to **Supabase** (PostgreSQL) for storing vitals, health events, and alerts.

### Current State
| Component | Status |
|---|---|
| Firebase Authentication | ✅ Active |
| Supabase (cloud database) | 🔧 Stub — ready, not yet connected |
| BLE Wearable (hardware) | 🔧 Stub — MockDataService used instead |

### Why Supabase (planned)?
- Open-source and PostgreSQL-based (industry standard)
- Row-level security (each user sees only their own data)
- Real-time subscriptions for live data updates
- Free tier suitable for a FYP
- REST API auto-generated from schema — no custom backend code needed

### Backend abstraction (CloudService)
All Supabase calls are isolated in `lib/services/cloud_service.dart`. To activate the real backend, replace the stub method bodies with Supabase REST calls. No other files need to change.

---

## 6. Database Used

### Local (on-device): SharedPreferences
Used for fast, lightweight key-value storage. Stores user profile, emergency contacts, and background analysis records.

### Cloud (planned): Supabase / PostgreSQL

The database schema is fully designed. Below are the main tables:

```
┌──────────────────┐         ┌──────────────────────┐
│     users        │────────▶│  emergency_contacts  │
│ id (UUID, PK)    │         │ id, user_id, name    │
│ name, email      │         │ phone, relation      │
│ phone, dob       │         │ is_primary           │
│ gender, blood_gr │         └──────────────────────┘
│ height, weight   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐         ┌──────────────────────┐
│  vital_readings  │────────▶│   health_events      │
│ id, user_id      │         │ id, user_id          │
│ heart_rate, spo2 │         │ reading_id (FK)      │
│ hrv, resp_rate   │         │ hr_status, spo2_stat │
│ activity         │         │ alert_class          │
│ fall_detected    │         │ confidence_score     │
│ recorded_at      │         │ is_emergency         │
└──────────────────┘         └──────────┬───────────┘
                                        │
                                        ▼
                              ┌──────────────────────┐
                              │       alerts         │
                              │ id, user_id          │
                              │ event_id (FK)        │
                              │ alert_type           │
                              │ location_lat/lng     │
                              │ sms_status           │
                              │ triggered_at         │
                              └──────────────────────┘
```

**Performance indexes:**
- `vital_readings (user_id, recorded_at DESC)` — for fast history queries
- `health_events (user_id, is_emergency)` — for emergency filtering
- `alerts (user_id)` — for contact history

---

## 7. State Management

CARDIVA uses **Flutter Riverpod 2.x** for all state management.

### What is Riverpod?
Riverpod is a reactive state management library for Flutter. Think of it as a "smart box" that holds data — any screen that reads from that box automatically updates when the data changes.

### Providers in CARDIVA

```
MockDataService
    │
    │ Stream (every 2 sec)
    ▼
latestReadingProvider (StreamProvider)
    │
    │ Maps through HealthStatusEngine
    ▼
healthEventProvider (Provider<AsyncValue<HealthEvent>>)
    │
    ├──▶ Emergency? → EmergencyTrigger.handle()
    ├──▶ Save to CloudService
    └──▶ UI screens rebuild automatically
```

| Provider | Type | Purpose |
|---|---|---|
| `latestReadingProvider` | `StreamProvider<VitalReading>` | Live vital data stream |
| `healthEventProvider` | `Provider<AsyncValue<HealthEvent>>` | Analyzed health status |
| `userProvider` | `StateNotifierProvider<UserProfile?>` | Logged-in user info |
| `emergencyContactsProvider` | `StateNotifierProvider<List<EmergencyContact>>` | Emergency contacts list |
| `analysisHistoryProvider` | `StateNotifierProvider<List<AnalysisRecord>>` | Historical records |
| `settingsProvider` | `StateNotifierProvider<AppSettings>` | App-wide settings |
| `todayAnalysisProvider` | `Provider` | Today's analysis (filtered) |
| `dailySummaryProvider` | `Provider` | Daily health score summary |

### Why Riverpod (not GetX or Bloc)?
- No `BuildContext` required — providers can be accessed anywhere
- Compile-time safety — no magic strings
- Easy to test — pure functions
- Official Flutter team recommendation for complex apps

---

## 8. Authentication System

Authentication is handled by **Firebase Auth** (`lib/services/auth_service.dart`).

### Supported Sign-In Methods

| Method | Status | Library |
|---|---|---|
| Email + Password | ✅ Active | `firebase_auth` |
| Google Sign-In | ✅ Active | `google_sign_in` |
| Apple Sign-In | ✅ Active (iOS only) | `sign_in_with_apple` |
| Password Reset | ✅ Active | `firebase_auth` |

### Auth Flow

```
App Launch
    │
    ├──▶ Splash Screen (2 sec)
    │
    ├── Is user logged in? ──YES──▶ Dashboard
    │
    └──NO──▶ Onboarding ──▶ Auth Screen
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
                Email/PW    Google      Apple
                    │           │           │
                    └───────────┴───────────┘
                                │
                        Firebase Auth
                                │
                        Profile Setup ──▶ Dashboard
```

### Security Notes
- Passwords never stored locally — Firebase handles token management
- Google/Apple tokens are cached by their respective SDKs
- `signOut()` clears both Firebase token and Google account cache
- User-friendly error messages mapped from Firebase error codes

---

## 9. APIs and Services

### Services Layer (`lib/services/`)

| Service | File | Status | Purpose |
|---|---|---|---|
| `AuthService` | `auth_service.dart` | ✅ Active | Firebase Auth operations |
| `MockDataService` | `mock_data_service.dart` | ✅ Active | Simulates wearable BLE stream |
| `BleService` | `ble_service.dart` | 🔧 Stub | Real Bluetooth wearable connection |
| `CloudService` | `cloud_service.dart` | 🔧 Stub | Supabase API calls |
| `LocationService` | `location_service.dart` | ✅ Active | GPS coordinates via Geolocator |
| `SmsService` | `sms_service.dart` | ✅ Active | WhatsApp/SMS emergency alerts |
| `NotificationService` | `notification_service.dart` | ✅ Active | Local in-app notifications |
| `BackgroundService` | `background_service.dart` | ✅ Active | 5-min background health checks |
| `MlService` | `ml_service.dart` | ✅ Active | Hybrid ML inference |
| `PdfReportService` | `pdf_report_service.dart` | ✅ Active | Health report PDF generation |

### External API: Groq AI
- **Purpose:** Future chatbot enhancement using a large language model
- **Key stored in:** `.env` as `GROQ_API_KEY`
- **Current status:** Key configured, chatbot is still rule-based (Groq integration planned)

---

## 10. Firebase Services Used

### Project Details
- **Firebase Project:** `cardiva-30297`
- **Bundle/Package:** `com.cardiva.cardiva`
- **Storage Bucket:** `cardiva-30297.firebasestorage.app`

### Services Configured

| Service | In Use | Purpose |
|---|---|---|
| **Firebase Core** | ✅ | Required to initialize all Firebase services |
| **Firebase Authentication** | ✅ | Email/password, Google, Apple sign-in |
| **Firebase Storage** | 🔧 Planned | Store PDF reports in the cloud |
| **Firestore / Realtime DB** | 🔧 Planned | Optional — Supabase is the primary DB plan |

### Firebase Initialization (main.dart)
```dart
await Firebase.initializeApp();
```
Firebase auto-reads `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) for configuration.

---

## 11. Folder Structure Explanation

```
cardiva/
├── lib/                          ← All Dart source code
│   ├── main.dart                 ← App entry point (init Firebase, .env, notifications)
│   ├── app.dart                  ← Root MaterialApp, theme, routing
│   │
│   ├── core/                     ← Shared constants and utilities
│   │   ├── constants/
│   │   │   ├── thresholds.dart   ← Medical thresholds for all vitals
│   │   │   ├── app_colors.dart   ← Color definitions
│   │   │   └── api_endpoints.dart← API route strings
│   │   ├── utils/
│   │   │   ├── date_formatter.dart
│   │   │   └── validators.dart
│   │   └── errors/
│   │       └── app_exceptions.dart ← Custom exception hierarchy
│   │
│   ├── models/                   ← Data classes (plain Dart objects)
│   │   ├── vital_reading.dart    ← Raw wearable data
│   │   ├── vital_status.dart     ← Enum: normal/stable/warning/emergency
│   │   ├── health_event.dart     ← Result of analyzing a reading
│   │   ├── user_profile.dart     ← User info + computed BMI, age
│   │   ├── emergency_contact.dart← SMS contact data
│   │   ├── alert_class.dart      ← 4-class alert enum
│   │   ├── ml_prediction.dart    ← ML model output wrapper
│   │   ├── analysis_record.dart  ← Historical record
│   │   ├── health_report.dart    ← Daily/weekly report
│   │   └── notification_model.dart
│   │
│   ├── engine/                   ← Core health logic (pure Dart, no Flutter)
│   │   ├── vital_classifier.dart ← Maps vitals to status levels
│   │   ├── confidence_engine.dart← Calculates confidence score (0–100)
│   │   ├── health_status_engine.dart ← Orchestrates 4-class classification
│   │   ├── emergency_trigger.dart← Sends GPS+SMS+notification on emergency
│   │   ├── chatbot_engine.dart   ← Keyword-based health assistant logic
│   │   ├── activity_classifier.dart ← Placeholder for accelerometer data
│   │   └── generated/
│   │       ├── emergency_model_generated.dart ← Auto-generated ML model
│   │       └── fall_model_generated.dart      ← Auto-generated fall detector
│   │
│   ├── services/                 ← External integrations (Firebase, GPS, SMS…)
│   │   ├── auth_service.dart
│   │   ├── mock_data_service.dart
│   │   ├── ble_service.dart
│   │   ├── cloud_service.dart
│   │   ├── location_service.dart
│   │   ├── sms_service.dart
│   │   ├── notification_service.dart
│   │   ├── background_service.dart
│   │   ├── ml_service.dart
│   │   └── pdf_report_service.dart
│   │
│   ├── providers/                ← Riverpod state management
│   │   ├── vital_provider.dart
│   │   ├── user_provider.dart
│   │   ├── analysis_provider.dart
│   │   ├── history_provider.dart
│   │   ├── report_provider.dart
│   │   ├── settings_provider.dart
│   │   └── notifications_provider.dart
│   │
│   ├── screens/                  ← All UI screens
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── auth/
│   │   ├── setup/
│   │   ├── dashboard/
│   │   ├── vitals/
│   │   ├── history/
│   │   ├── emergency/
│   │   ├── chatbot/
│   │   ├── profile/
│   │   ├── notifications/
│   │   ├── settings/
│   │   ├── report/
│   │   └── main_nav_screen.dart  ← Bottom nav container
│   │
│   ├── router/
│   │   └── app_router.dart       ← Named routes + slide transitions
│   │
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   │
│   ├── widgets/
│   │   └── atoms/                ← Reusable building-block widgets
│   │       ├── vital_card_atom.dart
│   │       ├── status_badge.dart
│   │       ├── skeleton_loader.dart
│   │       ├── ring_widget.dart
│   │       ├── spark_widget.dart
│   │       └── bottom_nav_bar.dart
│   │
│   └── data/
│       └── vitals_repository.dart← Repository pattern for mock data
│
├── android/                      ← Android-specific config
│   └── app/
│       └── google-services.json  ← Firebase Android config
│
├── ios/                          ← iOS-specific config
│   └── Runner/
│       └── GoogleService-Info.plist ← Firebase iOS config
│
├── assets/
│   └── animations/               ← Lottie JSON animation files
│
├── .env                          ← Secret API keys (never commit to git!)
├── pubspec.yaml                  ← Package dependencies
└── CARDIVA_BLUEPRINT.md          ← Full system design and implementation plan
```

---

## 12. Main Screens and Their Purpose

### App Navigation Flow

```
App Start
    │
    ▼
[Splash Screen]  ── 2 second wait ──▶  Is logged in?
                                            │
                            ┌───────────────┴───────────┐
                           YES                          NO
                            │                           │
                            ▼                           ▼
                     [Dashboard]               [Onboarding (3 slides)]
                                                        │
                                                        ▼
                                               [Auth: Login / Register]
                                                        │
                                                        ▼
                                               [Profile Setup]
                                                        │
                                                        ▼
                                               [Device Pair]
                                                        │
                                                        ▼
                                               [Emergency Contact Setup]
                                                        │
                                                        ▼
                                                [Dashboard]
```

### Screen Details

| Screen | File | Purpose |
|---|---|---|
| **Splash** | `splash/splash_screen.dart` | App loading with Lottie animation |
| **Onboarding** | `onboarding/onboarding_screen.dart` | 3-slide intro to the app |
| **Auth** | `auth/auth_screen.dart` | Login/Register hub |
| **Login** | `auth/login_screen.dart` | Email + Google + Apple sign-in |
| **Register** | `auth/register_screen.dart` | New account creation |
| **Profile Setup** | `setup/profile_setup_screen.dart` | Name, DOB, blood group, height, weight |
| **Device Pair** | `setup/device_pair_screen.dart` | BLE wearable pairing UI |
| **Emergency Contact Setup** | `setup/emergency_contact_setup_screen.dart` | First emergency contact |
| **Dashboard** | `dashboard/dashboard_screen.dart` | Live vitals view, status banner, quick actions |
| **Vitals** | `vitals/vitals_screen.dart` | Full vitals list with status indicators |
| **Vital Detail** | `vitals/vital_detail_screen.dart` | Single vital + recent history chart |
| **AI Vitals** | `vitals/vitals_ai_screen.dart` | AI analysis and prediction insights |
| **History** | `history/history_screen.dart` | Vital trends over time (line charts) |
| **Emergency** | `emergency/emergency_screen.dart` | Emergency alert detail with vitals |
| **Alert Sent** | `emergency/alert_sent_screen.dart` | Confirmation after SMS dispatched |
| **Chatbot** | `chatbot/chatbot_screen.dart` | Health assistant conversation UI |
| **Profile** | `profile/profile_screen.dart` | Edit profile + manage contacts |
| **Notifications** | `notifications/notifications_screen.dart` | Alert history |
| **Settings** | `settings/settings_screen.dart` | App-wide settings hub |
| **Health Report** | `report/health_report_screen.dart` | Daily/weekly report with PDF export |

### Bottom Navigation
The main shell (`main_nav_screen.dart`) provides 5 tabs:
1. Dashboard
2. Vitals
3. History
4. Chatbot
5. Profile

---

## 13. Important Packages and Why They Are Used

### State Management & UI
| Package | Version | Why It's Used |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | Reactive state management — the "brain" of the app |
| `google_fonts` | ^6.1.0 | Inter font for clean, medical-grade typography |
| `fl_chart` | ^0.68.0 | Interactive line charts for vital history |
| `lottie` | ^3.1.0 | Smooth JSON animations (splash, loading states) |
| `flutter_markdown` | ^0.6.21 | Render formatted chatbot responses |

### Firebase & Authentication
| Package | Version | Why It's Used |
|---|---|---|
| `firebase_core` | ^3.6.0 | Required to initialize any Firebase service |
| `firebase_auth` | ^5.3.1 | Secure user login (email, Google, Apple) |
| `google_sign_in` | ^6.2.2 | Google OAuth flow |
| `sign_in_with_apple` | ^6.1.3 | Apple Sign-In (required for iOS App Store) |

### Hardware & Sensors
| Package | Version | Why It's Used |
|---|---|---|
| `geolocator` | ^13.0.2 | Get GPS location for emergency SMS |
| `flutter_background_service` | ^5.0.9 | Keep monitoring running after app is closed |

### Communication
| Package | Version | Why It's Used |
|---|---|---|
| `url_launcher` | ^6.3.0 | Open WhatsApp or SMS app for emergency alerts |
| `flutter_local_notifications` | ^17.0.0 | Show high-priority alerts on device |

### Storage & Config
| Package | Version | Why It's Used |
|---|---|---|
| `shared_preferences` | ^2.3.2 | Save user profile and background records locally |
| `flutter_dotenv` | ^5.2.1 | Load `.env` file with secret API keys |
| `path_provider` | ^2.1.4 | Find device directories for saving files |
| `image_picker` | ^1.1.2 | Let users pick profile photos |

### Reports & Export
| Package | Version | Why It's Used |
|---|---|---|
| `pdf` | ^3.11.0 | Generate PDF health reports |
| `share_plus` | ^10.0.0 | Share reports via any device app |

### Utilities
| Package | Version | Why It's Used |
|---|---|---|
| `uuid` | ^4.4.2 | Generate unique IDs for readings and contacts |
| `intl` | ^0.19.0 | Format dates and times in locale-aware way |
| `http` | ^1.2.1 | Make HTTP requests to external APIs |

---

## 14. Data Flow Architecture

### Full Data Pipeline (Reading → Emergency Response)

```
┌─────────────────────────────────────────────────────────────┐
│                    WEARABLE / MOCK                          │
│  MockDataService emits VitalReading every 2 seconds        │
│  (HR, SpO2, HRV, RR, Activity, FallDetected)               │
└────────────────────────┬────────────────────────────────────┘
                         │ StreamProvider
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  VITAL CLASSIFIER                           │
│  Each vital → status:                                       │
│  Normal  (green)  ← within safe range                      │
│  Stable  (cyan)   ← slightly outside range                 │
│  Warning (orange) ← moderately outside range               │
│  Emergency (red)  ← critically outside range               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 CONFIDENCE ENGINE                           │
│  Emergency vital → 30 pts each                             │
│  Warning vital   → 15 pts each                             │
│  Stable vital    → 5 pts each                              │
│  Normal vital    → 0 pts each                              │
│  Score normalized → 0–100                                  │
│  Activity modifier applied (running lowers score by 15%)   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               HEALTH STATUS ENGINE                          │
│  Applies 2×2 matrix:                                        │
│  (FallDetected, VitalsHighRisk) → AlertClass               │
│  Produces: HealthEvent with all statuses                   │
└────────────────────────┬────────────────────────────────────┘
                         │
           ┌─────────────┼──────────────────┐
           ▼             ▼                  ▼
     UI Rebuild    Cloud Save          Emergency?
  (Dashboard,    (CloudService        YES → EmergencyTrigger
   Vitals,        stub → Supabase)          │
   History)                                 ▼
                                   ┌────────────────┐
                                   │ 1. Get GPS loc │
                                   │ 2. Build SMS   │
                                   │ 3. Send to all │
                                   │    contacts    │
                                   │ 4. Log to cloud│
                                   │ 5. Show notif  │
                                   └────────────────┘
```

### Vital Thresholds Reference

#### Heart Rate (Activity-Adjusted)
| Zone | Resting | Walking | Running | Lying Down |
|---|---|---|---|---|
| Emergency Low | < 40 | < 45 | < 50 | < 35 |
| Warning Low | < 50 | < 55 | < 60 | < 45 |
| Normal Range | 60–100 | 65–130 | 80–180 | 55–90 |
| Warning High | > 120 | > 155 | > 200 | > 110 |
| Emergency High | > 150 | > 175 | > 220 | > 140 |

#### SpO2 (Blood Oxygen %) — Same for all activities
| Status | Range |
|---|---|
| Normal | ≥ 95% |
| Stable | 93–94% |
| Warning | 90–92% |
| Emergency | < 90% |

#### HRV / SDNN (ms)
| Status | Range |
|---|---|
| Normal | > 50 ms |
| Stable | 35–50 ms |
| Warning | 20–34 ms |
| Emergency | < 20 ms |

#### Respiration Rate (breaths/min)
| Status | Range |
|---|---|
| Emergency Low | < 5 |
| Warning Low | < 8 |
| Normal | 12–20 |
| Warning High | > 25 |
| Emergency High | > 30 |

### Confidence Score Interpretation
| Score | Level | Action Taken |
|---|---|---|
| 80–100 | Very High | Full emergency response triggered |
| 60–79 | High | In-app warning alert |
| 40–59 | Moderate | Warning logged to history |
| 20–39 | Low | Logged silently |
| 0–19 | Very Low | Ignored (likely sensor noise) |

---

## 15. Notification System

CARDIVA uses **flutter_local_notifications** for all in-app alerts. These are device-local notifications — not push notifications from a server.

### Notification Channels (Android)

| Channel | Priority | Style | Used For |
|---|---|---|---|
| `cardiva_emergency` | MAX | Full-screen + vibrate + red LED | Emergency alerts |
| `cardiva_warning` | HIGH | Banner | Warning vitals |
| Background status | LOW | Persistent foreground notification | Background monitor running |

### Notification Types
1. **Emergency Notification** — Full-screen alert when AlertClass = emergency
2. **Warning Notification** — Banner when vitals are in warning zone
3. **Background Status** — Always-on low-priority notification while background service runs (required by Android for foreground services)
4. **"URGENT" prefix** — Background service adds "URGENT" to the notification title for high-risk background detections

### How Notifications Work
```
HealthEvent.isEmergency == true
    │
    ▼
NotificationService.showEmergencyNotification(title, body)
    │
    ├── Android: Shows on channel cardiva_emergency (MAX priority)
    │          Full-screen intent, pulsing LED, vibration
    └── iOS: Shows as alert + badge
```

---

## 16. Local Storage Usage

CARDIVA uses **SharedPreferences** for lightweight, persistent key-value storage on the device.

### What Is Stored and Why

| Key Pattern | Data Type | Purpose |
|---|---|---|
| `bg_user_height` | `double` | Background service reads height for BMI |
| `bg_user_weight` | `double` | Background service reads weight for BMI |
| `bg_user_age` | `int` | Age modifier for ML risk scoring |
| `bg_user_gender` | `String` | Gender for ML features |
| `emergency_contacts_{uid}_v1` | JSON String | List of emergency contacts for SMS |
| `attendants_{uid}_v1` | JSON String | SMS attendant config (name, phone, SMS toggle) |
| `bg_pending_records` | JSON String | Background analysis records awaiting sync (max 50) |

### Why SharedPreferences?
- Background service runs in a **separate Dart isolate** — it cannot access Riverpod state
- SharedPreferences is the only inter-isolate data bridge available without additional setup
- Lightweight: no database engine needed for key-value pairs

### Background Sync Flow
```
Background Isolate (every 5 min)
    │
    ├── Read user profile from SharedPreferences
    ├── Generate vitals (MockDataService logic)
    ├── Run MlService.analyze()
    ├── Write AnalysisRecord to `bg_pending_records`
    │
App Resumes (foreground)
    │
    ├── CardivApp reads `bg_pending_records` from SharedPreferences
    ├── Passes records to analysisHistoryProvider
    └── Clears `bg_pending_records`
```

---

## 17. AI / ML Integration

CARDIVA implements a **hybrid inference pipeline** combining on-device ML models with a rule-based fallback.

### On-Device ML Models

Two Dart-native models auto-generated from trained Python `.pkl` models:

| Model | File | Purpose |
|---|---|---|
| Emergency Classifier | `engine/generated/emergency_model_generated.dart` | Predicts if vitals are high-risk |
| Fall Detector | `engine/generated/fall_model_generated.dart` | Predicts if patient has fallen |

**Model Input Features (7-dimensional):**
1. Heart Rate (BPM)
2. SpO2 (%)
3. HRV (ms)
4. Respiration Rate (breaths/min)
5. Weight (kg)
6. Height (m)
7. BMI (auto-computed)

**How models were created:**
- Trained in Python (scikit-learn)
- Exported as `.pkl` files
- Converted to Dart via `convert_to_dart.py` script
- Output: Pure Dart math functions (no TensorFlow Lite dependency needed)

### Rule-Based Fallback (MlService)
If the ML model throws an exception, the app falls back to:
1. VitalClassifier thresholds (same as the engine)
2. **BMI Modifier:** BMI > 35 or < 16 → escalate stable readings to high-risk
3. **Age Modifier:** Age > 65 or < 18 → escalate stable readings to high-risk

### Chatbot (ChatbotEngine)
- Currently **keyword-driven** (pure Dart, no API calls)
- Responds to: `heart rate`, `spo2`, `hrv`, `respiration`, `fall`, `emergency`, `confidence`, `activity`
- Planned upgrade: Integrate Groq API for LLM-based responses

### Groq AI API
- API key configured: `GROQ_API_KEY` in `.env`
- Provider: Groq Cloud (ultra-fast LLM inference)
- Planned use: Replace keyword chatbot with AI-powered health assistant

---

## 18. Environment / Config Files

### `.env` (Secret Keys — Never Commit to Git)
```
GROQ_API_KEY=gsk_...
```
- Loaded at app start via `flutter_dotenv`
- Contains API keys that must not be exposed in source code
- Listed in `.gitignore` to prevent accidental commits

### `google-services.json` (Android)
- Location: `android/app/google-services.json`
- Contains Firebase project ID, OAuth client IDs, API keys
- Auto-generated from Firebase Console — do not edit manually

### `GoogleService-Info.plist` (iOS)
- Location: `ios/Runner/GoogleService-Info.plist`
- iOS equivalent of `google-services.json`

### `pubspec.yaml`
- Declares all dependencies and their version constraints
- Also declares asset paths (`.env`, `assets/animations/`)

### `lib/core/constants/thresholds.dart`
- All medical vital thresholds in one place
- Change thresholds here — no other files need updating

### `lib/core/constants/api_endpoints.dart`
- All API route strings centralized
- Change backend URLs here when activating Supabase

---

## 19. Build & Run Instructions

### Prerequisites
- Flutter SDK ≥ 3.38.4 installed
- Dart SDK ≥ 3.2.0
- Android Studio or VS Code with Flutter extension
- For iOS: Xcode on macOS
- Firebase project `cardiva-30297` access

### Step 1: Clone and Setup
```bash
git clone <repository-url>
cd cardiva
```

### Step 2: Create `.env` File
Create a `.env` file in the project root:
```
GROQ_API_KEY=your_groq_api_key_here
```

### Step 3: Install Dependencies
```bash
flutter pub get
```

### Step 4: Run the App
```bash
# Android
flutter run

# iOS (macOS only)
flutter run --release

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Step 5: Build for Release

**Android APK:**
```bash
flutter build apk --release
```
Output: `build/app/outputs/apk/release/app-release.apk`

**Android App Bundle (Play Store):**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
# Then archive via Xcode
```

### Common Issues

| Issue | Solution |
|---|---|
| Firebase not initialized | Ensure `google-services.json` is in `android/app/` |
| `.env` not found | Create `.env` in project root (same level as `pubspec.yaml`) |
| Background service crash | Check Android permissions in `AndroidManifest.xml` |
| Google Sign-In fails | Verify SHA-1 fingerprint in Firebase Console |
| GPS not working | Accept location permission in the app prompt |

### Running Tests
```bash
# All tests
flutter test

# Single test file
flutter test test/vital_classifier_test.dart
```

---

## 20. Future Scope

### Phase: Activate Real Wearable (BLE)
- Enable `ble_service.dart` with `flutter_blue_plus`
- Replace `MockDataService` with `BleService` in `vital_provider.dart`
- Pair with CARDIVA hardware (custom wearable with HR, SpO2, HRV sensors)

### Phase: Connect Supabase Database
- Replace no-op methods in `cloud_service.dart` with real Supabase REST calls
- Enable PostgreSQL row-level security so users only see their own data
- Add real-time subscriptions for live data sync across devices

### Phase: Upgrade Chatbot to AI
- Use configured `GROQ_API_KEY` to make API calls
- Replace `chatbot_engine.dart` keyword logic with LLM prompt engineering
- Add context: include patient's latest vitals in the system prompt

### Phase: Push Notifications
- Add Firebase Cloud Messaging (FCM) for push alerts even when app is uninstalled
- Notify emergency contacts via push if they also have the app

### Phase: Caregiver Dashboard
- Web dashboard for doctors/caregivers to monitor patients remotely
- Built with Flutter Web or Next.js connecting to same Supabase backend

### Phase: Fall Detection Hardware
- Integrate accelerometer data from wearable into `activity_classifier.dart`
- Real fall detection replaces the heuristic magnitude threshold

### Phase: Apple Watch / WearOS
- Extend `ble_service.dart` to support Bluetooth LE from smart watches
- Companion watchOS/WearOS apps for vitals display on watch face

### Phase: Clinical Validation
- Clinical trial with real patients to validate threshold accuracy
- Compare ML model predictions against doctor diagnoses
- Tune confidence thresholds and alert sensitivity

### Phase: Offline Mode
- Add `hive` package for offline SQLite-like storage
- Sync records to Supabase when connection is restored
- Show "Offline Mode" banner in UI

---

## Appendix: Key Architecture Decisions

| Decision | Rationale |
|---|---|
| Riverpod (not Bloc/GetX) | Compile-time safety, no BuildContext dependency, easier testing |
| Engine in pure Dart | Can run in background isolate without Flutter imports |
| SharedPreferences (not Hive) | Sufficient for key-value inter-isolate data; Hive planned for phase 2 |
| Firebase Auth + Supabase DB | Firebase handles complex OAuth; Supabase handles scalable PostgreSQL |
| MockDataService (not real BLE) | Enables full app development before hardware is ready |
| Rule-based fallback | Ensures app works even if ML model fails — patient safety first |
| WhatsApp before SMS | Higher delivery rate; WhatsApp is more widely used in target regions |
| No TensorFlow Lite | Generated Dart models avoid TFLite dependency and binary size |

---

*Last updated: May 2026*
*Maintained by: CARDIVA FYP Team*
*For questions or contributions, see `CARDIVA_BLUEPRINT.md`*
