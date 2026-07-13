# CARDIVA — Claude Code Context

> This file is auto-loaded by Claude Code at every session start.
> The **Recent Activity** section updates automatically after each git commit.

---

## What is Cardiva?

Flutter-based cardiac health monitoring app (FYP II). Reads vitals (HR, SpO2, HRV, RR) from a BLE wearable, classifies health status using a rule-based engine + on-device ML models, and triggers emergency SMS alerts to registered contacts when danger is detected.

**Target users:** Cardiac patients + their caregivers/attendants.

---

## Team

| Member | GitHub | Role |
|---|---|---|
| Hafiza Sana Awan | Hafiza Sana Awan | UI, AI/chatbot, routing |
| KhansaBatool | KhansaBatool-54 | Auth, profile, emergency, reports |
| Ayesha | Ayesha-nad | — |
| Qasim | Zuberipersonal@gmail.com | — |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod 2.x |
| Backend / Auth | Firebase (Auth, Firestore, Storage) |
| AI Chatbot | Groq LLM API (key in `.env`) |
| On-Device ML | TFLite — fall detection + emergency classification |
| BLE Wearable | `flutter_blue_plus` / `ble_service.dart` |
| Background Monitoring | `flutter_background_service` (5-min loop) |
| SMS Alerts | `url_launcher` (native SMS, no Twilio) |
| PDF Reports | `pdf` package |
| Charts | `fl_chart` |

---

## Architecture

```
Wearable (BLE)  ──or──  MockDataService (dev)
        ↓
   BleService  →  VitalReading (model)
        ↓
  VitalClassifier  →  HealthStatusEngine  →  EmergencyTrigger
        ↓                     ↓                     ↓
  Riverpod Providers    AlertClass (4-class)    SMS to contacts
        ↓
     Screens (UI)
        ↓
  Firebase Firestore  ←→  Cloud sync
```

**4-class health output:** `Normal` / `Vitals Alert` / `Fall Alert` / `Emergency`

---

## Key File Locations

| What | Where |
|---|---|
| App entry point | [lib/main.dart](lib/main.dart) |
| Root widget + lifecycle | [lib/app.dart](lib/app.dart) |
| All named routes | [lib/router/app_router.dart](lib/router/app_router.dart) |
| Bottom nav container | [lib/screens/main_nav_screen.dart](lib/screens/main_nav_screen.dart) |
| Vital classification logic | [lib/engine/vital_classifier.dart](lib/engine/vital_classifier.dart) |
| Health status (4-class) | [lib/engine/health_status_engine.dart](lib/engine/health_status_engine.dart) |
| Emergency SMS trigger | [lib/engine/emergency_trigger.dart](lib/engine/emergency_trigger.dart) |
| AI chatbot | [lib/engine/chatbot_engine.dart](lib/engine/chatbot_engine.dart) |
| Groq LLM integration | [lib/services/groq_service.dart](lib/services/groq_service.dart) |
| BLE wearable service | [lib/services/ble_service.dart](lib/services/ble_service.dart) |
| Mock data (dev) | [lib/services/mock_data_service.dart](lib/services/mock_data_service.dart) |
| Medical thresholds | [lib/core/constants/thresholds.dart](lib/core/constants/thresholds.dart) |
| All Riverpod providers | [lib/providers/](lib/providers/) |
| All screens | [lib/screens/](lib/screens/) |
| All data models | [lib/models/](lib/models/) |
| ML models (generated) | [lib/engine/generated/](lib/engine/generated/) |
| Environment vars | [.env](.env) — contains `GROQ_API_KEY` |

---

## Screens Overview (35+ total)

**Auth flow:** Splash → Onboarding (×3) → Auth (login/register)

**Setup flow:** ProfileSetup → DevicePair → EmergencyContactSetup

**Main app (bottom tabs):**
- Tab 1: Dashboard (vitals cards, confidence indicator, status badge)
- Tab 2: History (vitals chart, analysis records)
- Tab 3: AI Analysis (VitalsAiScreen, PredictionResultScreen)
- Tab 4: Settings (profile, attendants, contacts, notifications, help)

**Additional:** Chatbot, Notifications, HealthReport, EmergencyScreen, AlertSent

---

## Implemented Features

- [x] Firebase Auth — email/password, Google Sign-in, Apple Sign-in
- [x] User profile setup (age, height, weight, gender)
- [x] Emergency contacts setup + storage (per-user, Firestore)
- [x] BLE service scaffold + Mock data service (dev mode)
- [x] Rule-based vital classification engine
- [x] 4-class health status engine (Normal/Alert/Fall/Emergency)
- [x] On-device ML — fall detection + emergency classification (TFLite)
- [x] Emergency SMS trigger via url_launcher
- [x] AI Analysis screen with auto-analysis pipeline
- [x] Groq LLM chatbot with session history + markdown rendering
- [x] PDF report generation + WhatsApp sharing
- [x] WPS-style report manager with persistent history
- [x] Background monitoring (5-minute loop)
- [x] Real GPS location in emergency alerts
- [x] Attendant / caregiver management screen
- [x] Incident reporting module
- [x] Feedback module (star rating + category chips)
- [x] Notification preferences screen
- [x] Dark/light theme via settings provider

## Pending / In Progress

- [ ] Real BLE hardware connection (currently using mock data in dev)
- [ ] Attendant portal (caregiver's separate view)
- [ ] End-to-end testing
- [ ] App store build preparation

---

## Running the App

```bash
flutter pub get
flutter run                  # uses mock data by default
flutter run --release        # production build
flutter analyze              # lint check
```

**Note:** `.env` must be present in root with `GROQ_API_KEY` for chatbot to work.

**Firebase:** Project ID is `cardiva-30297`. Config files: `google-services.json` (android) and `GoogleService-Info.plist` (ios).

---

## Recent Activity
*(Auto-updated after every git commit — shows who did what and when)*

<!-- ACTIVITY:START -->
- `2026-07-09` **Hafiza Sana Awan**: Update CLAUDE.md, thesis, and generated plugin files
- `2026-06-30` **KhansaBatool-54**: Gradle issue resolve
- `2026-06-30` **KhansaBatool-54**: Final app Settings with bluetooth setup at initial setup screen
- `2026-06-29` **KhansaBatool-54**:  Last few changes
- `2026-06-29` **KhansaBatool-54**: SOS setup
- `2026-06-29` **KhansaBatool-54**: fix: emergency alerts, chat delete, and navigation bugs
- `2026-06-29` **KhansaBatool-54**: New App Settings
- `2026-06-29` **KhansaBatool-54**: new setup
- `2026-06-28` **KhansaBatool-54**: RTDB setup
- `2026-06-26` **KhansaBatool-54**: Chat Session
- `2026-06-26` **KhansaBatool-54**: Chat session added
- `2026-06-25` **Hafiza Sana Awan**: Merge branch 'main' of https://github.com/SanaEjaz02/Cardiva-vitals-monitoring-app :wq# the commit.
- `2026-06-25` **Hafiza Sana Awan**: icon setup
- `2026-06-25` **Hafiza Sana Awan**: Merge remote changes from origin/main
- `2026-06-25` **Hafiza Sana Awan**: feat: revamp splash screen with multi-stage ECG animation
<!-- ACTIVITY:END -->
