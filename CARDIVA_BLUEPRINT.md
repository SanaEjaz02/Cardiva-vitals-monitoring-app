# CARDIVA — AI-Based Wearable Health Monitoring and Emergency Response System
# Platform: Flutter (Dart) — Final Year Project Blueprint

---

## SECTION 1: PROJECT IDENTITY

| Property | Value |
|---|---|
| App Name | CARDIVA |
| Platform | Flutter (Android + iOS) |
| Language | Dart |
| Architecture | Feature-first folder structure + Riverpod |
| Backend | Supabase (PostgreSQL + Realtime + Auth) |
| AI Engine | Rule-based logic in pure Dart |
| Hardware | BLE wearable (dev: MockDataService) |

---

## SECTION 2: SYSTEM LAYERS

### Layer 1 — Hardware
Wearable collects 6 vital parameters and transmits BLE packets every 1–5 seconds.
During development: replaced by `MockDataService` generating realistic randomized readings.

### Layer 2 — Flutter App (Core)
- Receives raw data
- Runs rule-based analysis engine
- Calculates confidence score
- Determines overall health status
- Updates UI
- Triggers emergency responses
- Saves data to cloud

### Layer 3 — Cloud
- Supabase (PostgreSQL + Auth + REST + Realtime)
- Twilio SMS called from app for emergency alerts

---

## SECTION 3: SIX VITAL PARAMETERS

| # | Name | Field | Type | Unit | Notes |
|---|---|---|---|---|---|
| V1 | Heart Rate | `heartRate` | `double` | BPM | Context-adjusted thresholds |
| V2 | Blood Oxygen Saturation | `spO2` | `double` | % | Never activity-adjusted; <90% = emergency |
| V3 | Heart Rate Variability | `hrv` | `double` | ms (SDNN) | Low = stress/fatigue |
| V4 | Respiration Rate | `respirationRate` | `double` | breaths/min | Normal: 12–20 |
| V5 | Activity Classification | `activity` | `ActivityType` | enum | Adjusts HR thresholds |
| V6 | Fall Detection | `fallDetected` | `bool` | — | Always triggers emergency when true |

---

## SECTION 4: FOLDER STRUCTURE

```
lib/
  main.dart
  app.dart
  core/
    constants/
      thresholds.dart
      app_colors.dart
      api_endpoints.dart
    utils/
      date_formatter.dart
      validators.dart
    errors/
      app_exceptions.dart
  models/
    vital_reading.dart
    vital_status.dart
    health_event.dart
    user_profile.dart
    emergency_contact.dart
  services/
    ble_service.dart
    mock_data_service.dart
    cloud_service.dart
    location_service.dart
    sms_service.dart
    notification_service.dart
  engine/
    vital_classifier.dart
    activity_classifier.dart
    confidence_engine.dart
    health_status_engine.dart
    emergency_trigger.dart
  providers/
    vital_provider.dart
    health_status_provider.dart
    history_provider.dart
    user_provider.dart
  screens/
    dashboard/
      dashboard_screen.dart
      widgets/
        vital_card.dart
        status_badge.dart
        confidence_indicator.dart
    history/
      history_screen.dart
      widgets/
        vital_chart.dart
    emergency/
      emergency_screen.dart
      widgets/
        alert_banner.dart
    chatbot/
      chatbot_screen.dart
    profile/
      profile_screen.dart
    auth/
      login_screen.dart
      register_screen.dart
  router/
    app_router.dart
```

---

## SECTION 5: PUBSPEC DEPENDENCIES

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  flutter_blue_plus: ^1.20.0
  supabase_flutter: ^2.0.0
  fl_chart: ^0.65.0
  geolocator: ^11.0.0
  flutter_local_notifications: ^17.0.0
  dio: ^5.4.0
  hive_flutter: ^1.1.0
  intl: ^0.19.0
  uuid: ^4.0.0
```

---

## SECTION 6: DATA MODELS

### 6.1 Enums

```dart
enum ActivityType { resting, walking, running, lyingDown }
enum VitalStatus { normal, stable, warning, emergency }
// Severity order: normal < stable < warning < emergency
```

### 6.2 VitalReading

Raw data object from wearable / mock service.

| Field | Type | JSON Key | Notes |
|---|---|---|---|
| `id` | `String` | `id` | UUID |
| `timestamp` | `DateTime` | `timestamp` | |
| `heartRate` | `double` | `heart_rate` | BPM |
| `spO2` | `double` | `spo2` | % |
| `hrv` | `double` | `hrv` | ms SDNN |
| `respirationRate` | `double` | `respiration_rate` | breaths/min |
| `activity` | `ActivityType` | `activity` | enum |
| `fallDetected` | `bool` | `fall_detected` | |

Implement `fromJson` / `toJson` with snake_case keys matching Supabase columns.

### 6.3 HealthEvent

Result object produced by engine after analyzing a `VitalReading`.

| Field | Type | Notes |
|---|---|---|
| `reading` | `VitalReading` | Source data |
| `hrStatus` | `VitalStatus` | |
| `spo2Status` | `VitalStatus` | |
| `hrvStatus` | `VitalStatus` | |
| `respirationStatus` | `VitalStatus` | |
| `overallStatus` | `VitalStatus` | Highest severity |
| `confidenceScore` | `double` | 0–100 |
| `isEmergency` | `bool` | |
| `statusMessage` | `String` | Human-readable |

### 6.4 UserProfile

| Field | Type |
|---|---|
| `id` | `String` (UUID from Supabase Auth) |
| `name` | `String` |
| `email` | `String` |
| `phone` | `String` |
| `dateOfBirth` | `DateTime` |
| `gender` | `String` |
| `bloodGroup` | `String` |

### 6.5 EmergencyContact

| Field | Type |
|---|---|
| `id` | `String` |
| `userId` | `String` (FK) |
| `name` | `String` |
| `phone` | `String` |
| `relation` | `String` |
| `isPrimary` | `bool` |

---

## SECTION 7: VITAL THRESHOLDS

All values defined in `core/constants/thresholds.dart` — never hardcoded elsewhere.

### 7.1 Heart Rate (Context-Adjusted by Activity)

| Activity | Emergency Low | Warning Low | Stable Low | Normal Low | Normal High | Stable High | Warning High | Emergency High |
|---|---|---|---|---|---|---|---|---|
| resting | 40 | 50 | 55 | 60 | 100 | 105 | 120 | 150 |
| walking | 45 | 55 | — | 65 | 130 | — | 155 | 175 |
| running | 50 | 60 | — | 80 | 180 | — | 200 | 220 |
| lyingDown | 35 | 45 | — | 55 | 90 | — | 110 | 140 |

### 7.2 SpO2 (Not Activity-Adjusted)

| Status | Range |
|---|---|
| Normal | ≥ 95% |
| Stable | 93–94% |
| Warning | 90–92% |
| **Emergency** | **< 90%** |

### 7.3 HRV — SDNN (Not Activity-Adjusted)

| Status | Range |
|---|---|
| Normal | > 50 ms |
| Stable | 35–50 ms |
| Warning | 20–34 ms |
| Emergency | < 20 ms |

### 7.4 Respiration Rate

| Status | Range |
|---|---|
| Emergency Low | < 5 breaths/min |
| Warning Low | < 8 |
| Normal | 12–20 |
| Warning High | > 25 |
| Emergency High | > 30 |

---

## SECTION 8: RULE-BASED ENGINE

Engine lives in `engine/`. **Zero Flutter imports** — fully unit-testable in pure Dart.

### 8.1 VitalClassifier (`engine/vital_classifier.dart`)

```dart
static VitalStatus classifyHeartRate(double hr, ActivityType activity)
static VitalStatus classifySpO2(double spo2)
static VitalStatus classifyHRV(double hrv)
static VitalStatus classifyRespirationRate(double rr)
```

Each reads from `VitalThresholds` constants and returns `VitalStatus`.

### 8.2 HealthStatusEngine (`engine/health_status_engine.dart`)

```dart
static HealthEvent analyze(VitalReading reading)
```

Steps:
1. Call `VitalClassifier` for HR, SpO2, HRV, Respiration
2. Collect statuses into a list
3. Call `ConfidenceEngine.calculate(statuses, activity)`
4. Apply emergency decision tree (Section 8.3)
5. Build and return `HealthEvent`

### 8.3 Emergency Decision Tree (Priority Order)

| Priority | Condition | overallStatus | isEmergency | Message |
|---|---|---|---|---|
| 1 | `fallDetected == true` | emergency | true | "Fall detected. Emergency alert triggered." |
| 2 | Any vital = emergency **AND** confidence ≥ 70 | emergency | true | "Critical vitals detected. Emergency alert triggered." |
| 3 | Any vital = emergency **AND** confidence < 70 | warning | false | "Abnormal readings detected. Monitoring closely." |
| 4 | Any vital = warning | warning | false | "Some vitals require attention." |
| 5 | Any vital = stable | stable | false | "Vitals are slightly outside normal range." |
| Default | All normal | normal | false | "All vitals are normal." |

---

## SECTION 9: CONFIDENCE SCORE ENGINE (`engine/confidence_engine.dart`)

```dart
static double calculate(List<VitalStatus> statuses, ActivityType activity)
```

### Scoring Steps

**Step 1 — Assign points per status:**

| VitalStatus | Points |
|---|---|
| emergency | 30 |
| warning | 15 |
| stable | 5 |
| normal | 0 |

Sum all 4 vitals → max raw score = 120.

**Step 2 — Normalize:**
```
score = (rawScore / 120) * 100
```

**Step 3 — Activity context multiplier:**

| Activity | Multiplier |
|---|---|
| running | × 0.85 |
| walking | × 0.92 |
| resting / lyingDown | × 1.00 (no change) |

**Step 4 — Clamp to 0–100.**

### Score Interpretation

| Range | Confidence Level | Action |
|---|---|---|
| 80–100 | Very High | Trigger emergency response |
| 60–79 | High | Trigger alert and log |
| 40–59 | Moderate | In-app warning only |
| 20–39 | Low | Log to history, no alert |
| 0–19 | Very Low | Ignore (likely sensor noise) |

---

## SECTION 10: STATE MANAGEMENT (RIVERPOD)

File: `providers/vital_provider.dart`

| Provider | Type | Description |
|---|---|---|
| `mockDataServiceProvider` | `Provider` | MockDataService singleton |
| `cloudServiceProvider` | `Provider` | CloudService singleton |
| `latestReadingProvider` | `StreamProvider<VitalReading>` | Watches MockDataService stream; replace with BleService for hardware |
| `healthEventProvider` | `Provider<HealthEvent>` | Maps readings through `HealthStatusEngine.analyze()`; side-effects: cloud save + emergency trigger |
| `historyProvider` | `FutureProvider` / `StateNotifierProvider` | Fetches recent readings from CloudService |
| `userProvider` | `StateNotifierProvider` | Holds UserProfile; exposes load/update methods |

---

## SECTION 11: SERVICES

### 11.1 MockDataService (`services/mock_data_service.dart`)

- Timer fires every **2 seconds**
- Generates realistic `VitalReading` via `StreamController` broadcast
- Expose: `stream` getter, `start()`, `stop()`
- Default ranges: HR 60–100, SpO2 94–100, HRV 30–80, RR 12–20, activity = resting, fall = false

### 11.2 BleService (`services/ble_service.dart`)

- Wraps `flutter_blue_plus`
- Scans for device named `'HealthBand'`
- Constants: `SERVICE_UUID`, `CHARACTERISTIC_UUID`
- `scanAndConnect()` → connects and subscribes to characteristic notifications
- `vitalStream` getter decodes UTF-8 JSON bytes → `Map` → caller converts to `VitalReading`

### 11.3 CloudService (`services/cloud_service.dart`)

```dart
Future saveVitalReading(VitalReading reading, String userId)
Future saveHealthEvent(HealthEvent event, String userId)
Future saveAlert(String userId, String alertMessage, String alertType, double lat, double lng)
Future<List<VitalReading>> fetchRecentReadings(String userId, {int limit = 50})
Future<List<HealthEvent>> fetchHealthHistory(String userId, {int limit = 50})
Future<List<EmergencyContact>> fetchEmergencyContacts(String userId)
Future saveEmergencyContact(EmergencyContact contact)
```

All methods: try/catch → throw typed `AppException` on failure.

### 11.4 LocationService (`services/location_service.dart`)

```dart
static Future<Position> getCurrentPosition()
```

- Check service enabled → throw if not
- Check/request permissions → throw if denied
- Return high-accuracy `Position`

### 11.5 SmsService (`services/sms_service.dart`)

```dart
static Future sendSms({required String to, required String message})
```

- Twilio endpoint: `POST https://api.twilio.com/2010-04-01/Accounts/{accountSid}/Messages.json`
- Basic Auth with `accountSid` + `authToken`
- FormData fields: `From`, `To`, `Body`
- Store credentials as constants or via secure storage — **never hardcode in source**

### 11.6 NotificationService (`services/notification_service.dart`)

- Initialize on app startup
- `showEmergencyNotification(String title, String body)` — high priority
- `showWarningNotification(String title, String body)` — normal priority

---

## SECTION 12: EMERGENCY TRIGGER (`engine/emergency_trigger.dart`)

```dart
static Future handle({
  required HealthEvent event,
  required String userName,
  required String userPhone,
  required String contactPhone,
})
```

Steps:
1. Return immediately if `event.isEmergency == false`
2. `LocationService.getCurrentPosition()` → get GPS coords
3. Build Google Maps link from lat/lng
4. Build SMS message: patient name, overall status, fall flag, all vital readings + statuses, maps link
5. `SmsService.sendSms()` → user phone
6. `SmsService.sendSms()` → emergency contact phone
7. `CloudService.saveAlert()` → log event
8. `NotificationService.showEmergencyNotification()` → in-app alert

---

## SECTION 13: DATABASE SCHEMA (SUPABASE / POSTGRESQL)

### Table: `users`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK, default `gen_random_uuid()` |
| `name` | VARCHAR(100) | NOT NULL |
| `email` | VARCHAR(150) | UNIQUE, NOT NULL |
| `phone` | VARCHAR(20) | |
| `date_of_birth` | DATE | |
| `gender` | VARCHAR(10) | |
| `blood_group` | VARCHAR(5) | |
| `created_at` | TIMESTAMP | default NOW() |
| `updated_at` | TIMESTAMP | default NOW() |

### Table: `emergency_contacts`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users(id) ON DELETE CASCADE |
| `name` | VARCHAR(100) | NOT NULL |
| `phone` | VARCHAR(20) | NOT NULL |
| `relation` | VARCHAR(50) | |
| `is_primary` | BOOLEAN | default false |

### Table: `vital_readings`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users(id) ON DELETE CASCADE |
| `heart_rate` | DECIMAL(6,2) | |
| `spo2` | DECIMAL(5,2) | |
| `hrv` | DECIMAL(7,2) | |
| `respiration_rate` | DECIMAL(5,2) | |
| `activity` | VARCHAR(20) | |
| `fall_detected` | BOOLEAN | default false |
| `recorded_at` | TIMESTAMP | NOT NULL, default NOW() |

### Table: `health_events`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users(id) ON DELETE CASCADE |
| `reading_id` | UUID | FK → vital_readings(id) |
| `hr_status` | VARCHAR(20) | |
| `spo2_status` | VARCHAR(20) | |
| `hrv_status` | VARCHAR(20) | |
| `respiration_status` | VARCHAR(20) | |
| `overall_status` | VARCHAR(20) | NOT NULL |
| `confidence_score` | DECIMAL(5,2) | |
| `is_emergency` | BOOLEAN | default false |
| `status_message` | TEXT | |
| `analyzed_at` | TIMESTAMP | default NOW() |

### Table: `alerts`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users(id) ON DELETE CASCADE |
| `event_id` | UUID | FK → health_events(id) |
| `alert_type` | VARCHAR(30) | `'fall_detection'` or `'critical_vitals'` |
| `location_lat` | DECIMAL(10,7) | |
| `location_lng` | DECIMAL(10,7) | |
| `sms_status` | VARCHAR(20) | `'sent'`, `'failed'`, or `'pending'` |
| `alert_message` | TEXT | |
| `triggered_at` | TIMESTAMP | default NOW() |

### Table: `feedback`

| Column | Type | Constraints |
|---|---|---|
| `id` | UUID | PK |
| `user_id` | UUID | FK → users(id) ON DELETE CASCADE |
| `alert_id` | UUID | FK → alerts(id) |
| `accuracy_rating` | INTEGER | CHECK 1–5 |
| `comment` | TEXT | |
| `submitted_at` | TIMESTAMP | default NOW() |

### Indexes

```sql
CREATE INDEX idx_vital_readings_user_id ON vital_readings(user_id);
CREATE INDEX idx_vital_readings_recorded ON vital_readings(recorded_at DESC);
CREATE INDEX idx_health_events_user_id ON health_events(user_id);
CREATE INDEX idx_health_events_emergency ON health_events(is_emergency);
CREATE INDEX idx_alerts_user_id ON alerts(user_id);
```

---

## SECTION 14: SUPABASE REST API REFERENCE

Base URL: `https://YOUR_PROJECT.supabase.co/rest/v1/`

Required headers on all requests:
```
apikey: YOUR_ANON_KEY
Authorization: Bearer USER_JWT_TOKEN
Content-Type: application/json
```

| Operation | Method | Endpoint |
|---|---|---|
| Save vital reading | POST | `/vital_readings` |
| Fetch recent readings | GET | `/vital_readings?user_id=eq.{id}&order=recorded_at.desc&limit=50` |
| Save health event | POST | `/health_events` |
| Fetch emergency contacts | GET | `/emergency_contacts?user_id=eq.{id}` |
| Create alert | POST | `/alerts` |
| Fetch alert history | GET | `/alerts?user_id=eq.{id}&order=triggered_at.desc` |

---

## SECTION 15: UI SCREENS

### Dashboard (`screens/dashboard/dashboard_screen.dart`)

- `ConsumerWidget` watching `healthEventProvider`
- 6 VitalCards (grid/list)
- Overall status badge with VitalStatus color
- Confidence score percentage indicator
- Real-time clock + last-updated timestamp
- Auto-navigate to `/emergency` if `isEmergency == true`
- Warning banner if `overallStatus == warning`

**VitalCard widget:**
- Vital name, current value with unit, status label
- Border/background color based on VitalStatus:
  - normal → green
  - stable → blue
  - warning → orange
  - emergency → red

### History (`screens/history/history_screen.dart`)

- Loads from `historyProvider`
- Line chart per vital using `fl_chart`
- Tab/dropdown to switch vitals
- Timestamps on x-axis

### Emergency (`screens/emergency/emergency_screen.dart`)

- Prominent emergency alert banner
- Which vitals triggered it
- Confidence score
- SMS sent confirmation / countdown
- Cancel / False Alarm button (logs feedback)

### Chatbot (`screens/chatbot/chatbot_screen.dart`)

- Scrollable message list
- Text input field
- Calls `ChatbotEngine.getResponse()` for each message
- Greeting message on first load

### Profile (`screens/profile/profile_screen.dart`)

- Display + edit user profile fields
- Display + add/edit emergency contacts
- Saves via `CloudService`

---

## SECTION 16: CHATBOT ENGINE (`engine/chatbot_engine.dart`)

```dart
static String getResponse(String userInput)
```

Normalizes input to lowercase, then keyword-matches:

| Keyword(s) | Topic |
|---|---|
| `heart rate`, `hr` | HR normal ranges, tachycardia, bradycardia |
| `spo2`, `oxygen`, `blood oxygen` | SpO2 explanation, normal ≥95%, emergency <90% |
| `hrv`, `variability` | HRV/SDNN, what low HRV means |
| `respiration`, `breathing`, `breath` | RR, normal 12–20 |
| `fall` | Fall detection and emergency trigger |
| `emergency` | GPS, SMS, alert logging process |
| `confidence`, `score` | Confidence scoring and range interpretation |
| `activity` | Activity classification and threshold adjustment |

No match → default message listing available topics.

---

## SECTION 17: ROUTING (`router/app_router.dart`)

Named routes:

| Route | Screen |
|---|---|
| `/login` | LoginScreen |
| `/register` | RegisterScreen |
| `/dashboard` | DashboardScreen |
| `/history` | HistoryScreen |
| `/emergency` | EmergencyScreen |
| `/chatbot` | ChatbotScreen |
| `/profile` | ProfileScreen |

- After login → redirect to `/dashboard`
- Emergency event → push `/emergency` on top of current stack
- Unauthenticated → redirect to `/login`

---

## SECTION 18: INITIALIZATION

### `main.dart`

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Initialize Supabase (URL + anon key)
3. Initialize Hive
4. Initialize `NotificationService`
5. `runApp(ProviderScope(child: CardivApp()))`

### `app.dart`

- `MaterialApp` with theme, routes, initial route
- Color scheme from `AppColors` constants
- Light + dark theme support

---

## SECTION 19: IMPLEMENTATION PHASES (ORDER)

| Phase | Focus | Key Deliverables |
|---|---|---|
| 1 | Models & Constants | Enums, VitalReading, HealthEvent, UserProfile, EmergencyContact, thresholds.dart |
| 2 | Engine Logic | VitalClassifier, ConfidenceEngine, HealthStatusEngine, unit tests |
| 3 | Services | MockDataService, CloudService, LocationService, SmsService, NotificationService |
| 4 | State Management | ProviderScope, latestReadingProvider, healthEventProvider, historyProvider, userProvider |
| 5 | Dashboard UI | VitalCard, StatusBadge, ConfidenceIndicator, DashboardScreen |
| 6 | History UI | VitalChart, HistoryScreen |
| 7 | Emergency System | EmergencyTrigger, healthEventProvider wiring, EmergencyScreen, AlertBanner |
| 8 | Chatbot | ChatbotEngine, ChatbotScreen |
| 9 | Profile | ProfileScreen, emergency contact management |
| 10 | Auth | Supabase auth, LoginScreen, RegisterScreen, route guards |
| 11 | Polish & Testing | Error handling, offline Hive cache, loading states, Android + iOS testing |

---

## SECTION 20: IMPLEMENTATION RULES

1. `engine/` — **zero Flutter imports**; all classes must be unit-testable without Flutter test environment
2. **Never hardcode thresholds** outside `thresholds.dart`
3. **Never hardcode API keys** — use `dart-define` or `flutter_secure_storage`
4. Supabase columns = `snake_case`; Dart fields = `camelCase`; `fromJson`/`toJson` handle mapping
5. `MockDataService` and `BleService` are interchangeable — switching requires **one line change** in `vital_provider.dart`
6. Emergency handling must be **non-blocking** — fire-and-forget for cloud saves
7. **Confidence score calculated before overall status** — overall status depends on it for emergency→warning downgrade
8. **Fall detection overrides confidence threshold** — low confidence + fall = still emergency
9. **SpO2 < 90% always emergency** regardless of activity context
10. Every widget showing health status **must use VitalStatus enum color**, not hardcoded color values

---

## SECTION 21: ENGINE TEST CASES

| # | Input Summary | Expected Output |
|---|---|---|
| TC1 | HR 72, SpO2 98, HRV 55, RR 15, resting, no fall | All normal, confidence ≈ 0, overall normal, isEmergency false |
| TC2 | HR 75, SpO2 **87**, HRV 55, RR 15, resting, no fall | spo2Status = emergency, confidence high, overall emergency, isEmergency **true** |
| TC3 | HR **170**, SpO2 97, HRV 45, RR 22, **running**, no fall | hrStatus = normal (threshold 80–180 for running), overall stable/normal |
| TC4 | HR **130**, SpO2 96, HRV 40, RR 18, **resting**, no fall | hrStatus = warning/emergency, confidence moderate–high |
| TC5 | HR 80, SpO2 96, HRV 55, RR 16, resting, **fall = true** | overall = emergency, isEmergency = **true** (ignores confidence) |
| TC6 | HR 145, SpO2 91, HRV 55, RR 15, **running**, no fall | Running context lowers confidence; if confidence < 70 → overall = **warning**, not emergency |
