# CARDIVA Thesis — Source Brief for Chapters 5 (Implementation) & 6 (Testing)

> This is a **fact-base** for the writing agent. Compose academic prose from these facts.
> **Do NOT invent specifications, numbers, UUIDs, pin assignments, or results beyond what
> appears here.** Every concrete value below is verified from the firmware, hardware
> documentation, or the Flutter source tree.

---

## 0. WHERE THIS FITS

Existing thesis (`Project_Report/Thesis.docx`, ~107 pp.) already contains:
- Chapter 1 — Introduction
- Chapter 2 — Foundations of Wearable and Mobile Health Systems
- Chapter 3 — Review of Related Work
- Chapter 4 — System Design (architecture, use cases, ERD, activity/sequence/class diagrams)

You are writing the **next two chapters**, appended after Chapter 4:
- **Chapter 5 — Implementation**
- **Chapter 6 — Testing**

Chapter titles are AUTO-NUMBERED by Word's multilevel list (Heading1 = "Chapter %1").
**Never type the words "Chapter 5"/"Chapter 6" into a heading** — type only the title text
("Implementation", "Testing") with style Heading1; numbering is automatic.

## REQUIRED SECTION OUTLINE (from supervisor's spec `5Implementation8.docx`)

```
Chapter 5  Implementation
  5.1  Software Components/Modules        (spec-mandated)
  (add hardware + integration subsections — see structure below)

Chapter 6  Testing
  6.1  Introduction
  6.2  Verification and Validation
  6.3  Test Cases, Suites, Scripts, and Scenarios
  6.4  A Sample Testing Cycle
  6.5  Test Cases
  6.5.1  Sample Test Case
```

You MAY add sub-sections beyond the spec where the project requires it (it is a
hardware+software project), but you MUST include every spec heading above verbatim.

---

## 1. SYSTEM OVERVIEW (for chapter intros)

Cardiva is a wearable cardiac-vitals monitoring system: an **ESP32** microcontroller paired
with three I2C sensors reads physiological + motion data, computes **six vitals on-board**,
shows them on an OLED, and streams them once per second over **Bluetooth Low Energy (BLE)**
to a companion **Flutter (Android)** application. The app classifies health status with a
rule-based engine + on-device TFLite ML models and triggers emergency SMS alerts to
registered contacts when danger is detected.

Vitals & sources:
| Vital | Sensor | Notes |
|---|---|---|
| Heart Rate (BPM) | MAX30100 | PPG pulse detection |
| SpO2 (%) | MAX30100 | Blood-oxygen saturation |
| HRV — SDNN (ms) | MAX30100 (derived) | SD of beat-to-beat intervals |
| Respiration Rate (br/min) | MAX30100 (derived) | low-freq modulation proxy |
| Activity (Resting/Sedentary/Walking/Active) | MPU9250/9265 | accelerometer variance |
| Fall detection (event) | MPU9250/9265 | free-fall + impact spike |

Three cooperating parts: (1) ESP32 firmware (sensor read + vitals compute + OLED + BLE GATT
server), (2) Flutter app (BLE client + classification + alerts + UI), (3) communication layer
(single custom BLE service, one read/notify characteristic carrying a compact JSON string).

Data flow: `MAX30100 + MPU9250 + OLED ─(I2C)─> ESP32 Vitals Engine ─┬─> OLED (local)
                                                                     └─> BLE Notify ─> Flutter app ─> Dashboard`

---

## 2. HARDWARE IMPLEMENTATION FACTS

### 2.1 Bill of Materials
| Component | Notes |
|---|---|
| ESP32 DevKit (any variant) | 2 free GPIOs for I2C (GPIO21 SDA, GPIO22 SCL) |
| MAX30100 pulse-oximeter breakout | I2C addr 0x57 |
| MPU9250 / MPU9265 IMU breakout | I2C addr 0x68 (0x69 if AD0 high) |
| SSD1306 OLED 128×64 I2C | I2C addr 0x3C (0x3D on some boards) |
| Jumper wires + breadboard/PCB | all 3 sensors share one I2C bus |

### 2.2 Wiring (all I2C devices in parallel on one bus)
| ESP32 Pin | Connects To | Purpose |
|---|---|---|
| 3V3 | VCC on all 3 modules | Power (3.3V) |
| GND | GND on all 3 modules | Common ground |
| GPIO 21 | SDA on all 3 modules | I2C data |
| GPIO 22 | SCL on all 3 modules | I2C clock |
If no onboard pull-ups: add 4.7kΩ from SDA and SCL to 3.3V.
Verification: I2C-scanner sketch should report devices at 0x3C (OLED), 0x57 (MAX30100),
0x68 (MPU9250/9265).

### 2.3 Firmware constants (verified from `Cardiva_Firmware_Fixed.ino`, 474 lines)
- Libraries: Wire.h, Adafruit_GFX, Adafruit_SSD1306, MAX30100_PulseOximeter, MPU9250_asukiaaa,
  BLEDevice/BLEServer/BLEUtils/BLE2902 (ESP32 BLE Arduino).
- `SDA_PIN 21`, `SCL_PIN 22`, `OLED_RESET -1`, `SCREEN_WIDTH 128`, `SCREEN_HEIGHT 64`.
- `SERVICE_UUID  = "12345678-1234-5678-1234-56789abcdef0"`
- `VITALS_CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"`
- `DEVICE_NAME = "Cardiva-ESP32"`
- `REPORT_INTERVAL_MS 1000` (1 Hz reporting), `IBI_BUF_SIZE 20`, `ACCEL_BUF_SIZE 50`,
  `NO_FINGER_TIMEOUT_MS 8000`.
- RSA/respiration constants: `RSA_SMOOTH_ALPHA 0.25`, `RSA_TREND_ALPHA 0.08`,
  `RSA_MIN_BREATH_MS 1500`.
- `Serial.begin(115200)`; OLED init `display.begin(SSD1306_SWITCHCAPVCC, 0x3C)`.
- BLE advertising `setMinPreferred(0x06)`.

### 2.4 Vitals computation logic
- **HR & SpO2**: directly from MAX30100lib (`pox.getHeartRate()`, `pox.getSpO2()`) once per cycle.
- **HRV (SDNN)**: each beat callback records inter-beat interval (IBI) in ms; every second
  computes SD of last 20 IBIs. IBIs outside 300–2000 ms (30–200 BPM) discarded as noise.
- **Respiration**: true extraction needs a 0.1–0.5 Hz bandpass on raw IR PPG. Because the
  library's public API exposes computed HR (not raw IR), respiration is a **best-effort proxy**:
  sample instantaneous HR at 5 Hz, count directional reversals (peaks/troughs) over a rolling
  window, convert reversal rate to breaths/min. Documented as demo-grade, not clinical-grade;
  upgrade path = access raw IR buffer + digital bandpass.
- **Activity classification** (rolling SD of accel magnitude over last 50 samples):
  | State | SD range (g) |
  |---|---|
  | Resting | < 0.02 |
  | Sedentary | 0.02–0.15 |
  | Walking | 0.15–0.5 |
  | Active | > 0.5 |
- **Fall detection** (2-phase state machine on accel magnitude):
  free-fall when magnitude < 0.4 g; if within 1 s an impact spike > 2.5 g follows, flag a fall;
  no impact within window → reset (false-alarm filter). Fall sent once as one-shot `fall:true`,
  auto-cleared firmware-side.

### 2.5 OLED display
Boot screen on power-up, then live dashboard: animated pulsing heart icon synced to report
interval; large HR + SpO2 readouts; HRV + RR secondary row; current activity; BLE-connection
icon + uptime clock; full-screen inverted "FALL!" overlay on fall.

### 2.6 BLE GATT service (device-side contract — AUTHORITATIVE)
| Item | Value |
|---|---|
| Device name | Cardiva-ESP32 |
| Service UUID | 12345678-1234-5678-1234-56789abcdef0 |
| Vitals characteristic UUID | 12345678-1234-5678-1234-56789abcdef1 |
| Properties | READ, NOTIFY |
| Payload | UTF-8 JSON string, notified once per second |
Example payload: `{"hr":78.0,"spo2":97.5,"hrv":42.3,"rr":16.0,"act":"Walking","fall":false}`

---

## 3. SOFTWARE IMPLEMENTATION FACTS (Flutter app — the FYP application)

### 3.1 Stack / dependencies (verified from pubspec.yaml)
- Framework: Flutter (Dart). State mgmt: **flutter_riverpod ^2.5.1**.
- Firebase: firebase_core ^3.6, firebase_auth ^5.3, cloud_firestore ^5.4, firebase_storage ^12.3,
  firebase_app_check ^0.3, google_sign_in ^6.2, sign_in_with_apple ^6.1. (Firebase project id
  `cardiva-30297`.)
- BLE: **flutter_blue_plus ^1.35.5**. Charts: fl_chart ^0.68. PDF: pdf ^3.11 + share_plus ^10.
  Local notifications: flutter_local_notifications ^17. Background: flutter_background_service ^5.0.9.
  GPS: geolocator ^13. SMS: **url_launcher ^6.3** (native SMS — replaces Twilio, no API key/cost).
  HTTP: http ^1.2. Chatbot markdown: flutter_markdown ^0.6. Env: flutter_dotenv ^5.2.
  Also: shared_preferences, image_picker, path_provider, lottie, google_fonts, intl, uuid.
- NOTE: `api_endpoints.dart` still contains vestigial Supabase/Twilio `String.fromEnvironment`
  constants. These are NOT the live backend — describe the ACTUAL stack: Firebase (Auth/
  Firestore/Storage) for backend, url_launcher for SMS. Do not present Supabase/Twilio as active.

### 3.2 Layered architecture / module map (verified from lib/ tree)
- **Presentation (lib/screens/, lib/widgets/, lib/theme/)** — 35+ screens grouped by feature:
  auth (auth/login/register/forgot_password), onboarding, splash, setup (profile_setup,
  device_pair, emergency_contact_setup), main_nav_screen (bottom tabs), dashboard (+ widgets:
  confidence_indicator, status_badge, vital_card), history (+ vital_chart), vitals (vitals_screen,
  vitals_ai_screen, prediction_result_screen, vital_detail_screen), device (device_connection,
  live_monitor), emergency (emergency_screen, emergency_popup, alert_sent, widgets/alert_banner),
  chatbot, notifications, report (health_report, report_detail), profile (+ feedback_sheet,
  debug_panel, emergency_contact_tile), settings (settings, attendant, emergency_contacts,
  notification_preferences, help_support). Reusable atoms: bottom_nav_bar, cardiva_fab,
  pill/ring/spark widgets, skeleton_loader, status_badge, step_indicator, vital_animations,
  vital_card_atom.
- **State management (lib/providers/)** — Riverpod providers: vital_provider,
  health_status_provider, analysis_provider, history_provider, report_provider,
  notifications_provider, settings_provider, user_provider.
- **Domain engine (lib/engine/)** — vital_classifier, health_status_engine, activity_classifier,
  confidence_engine, emergency_trigger, chatbot_engine, generated/ (TFLite-derived
  fall_model_generated, emergency_model_generated).
- **Services (lib/services/)** — ble_service, mock_data_service (dev), ml_service,
  groq_service, auth_service, firestore_service, cloud_service, location_service, sms_service,
  notification_service, background_service, pdf_report_service, session_service, storage_service.
- **Data/models (lib/data/, lib/models/)** — vitals_repository; models: vital_reading, vital,
  vital_status, alert_class, alert_event, analysis_record, attendant, emergency_contact,
  health_event, health_report, ml_prediction, notification_model, user_profile.
- **Core (lib/core/)** — constants (api_endpoints, app_colors, thresholds), errors
  (app_exceptions), utils (date_formatter, validators), app_navigator.
- **Routing** — lib/router/app_router.dart (all named routes); lib/main.dart entry; lib/app.dart
  root widget + lifecycle.

### 3.3 BLE app-side integration (verified from ble_service.dart)
- Uses flutter_blue_plus; discovers services, subscribes to the vitals characteristic's notify,
  decodes the UTF-8 JSON payload into a typed `VitalReading` (heartRate, spO2, hrv,
  respirationRate, activity enum, fallDetected). Drops a reading when heart==0 && spo2==0
  (no-finger / invalid). Broadcasts readings on a stream consumed by Riverpod's vital_provider.
- A `MockDataService` provides synthetic readings in dev so the full pipeline runs without
  hardware.
- IMPORTANT — keep the BLE contract coherent: present the GATT UUIDs + JSON schema from §2.6
  (the device firmware contract) as canonical. Describe the app as decoding that same JSON
  vitals payload. Do NOT print a second, conflicting UUID set.

### 3.4 Classification / decision pipeline (verified from thresholds.dart + engine/)
- Rule-based `VitalClassifier` uses thresholds in `thresholds.dart`, **activity-adjusted** for
  heart rate. HR bands keyed by activity (resting/walking/running/lyingDown), each with
  emergencyLow/warningLow/(stableLow)/normalLow/normalHigh/(stableHigh)/warningHigh/emergencyHigh.
  Example (resting): normal 60–100 BPM; warning 50/120; emergency 40/150.
- SpO2 (not activity-adjusted): normal ≥95%, stableLow 93, warningLow 90, <90 = emergency.
- HRV/SDNN: normal ≥50 ms, stableLow 35, warningLow 20, <20 = emergency.
- Respiration: normal 12–20 br/min; warning 8/25; emergency 5/30.
- `confidence_engine` produces a confidence score; `emergencyConfidenceGate = 70.0` gates the
  emergency decision. `health_status_engine` emits the **4-class output**: Normal / Vitals Alert /
  Fall Alert / Emergency. `emergency_trigger` fires the SMS alert flow.
- On-device ML: TFLite-derived models (fall detection + emergency classification) under
  engine/generated/, surfaced via ml_service and the AI Analysis screens.

### 3.5 Key external APIs / integrations
- **Groq LLM** (verified groq_service.dart): endpoint `https://api.groq.com/openai/v1/chat/
  completions`, model `llama-3.3-70b-versatile`, Bearer auth via `GROQ_API_KEY` in `.env`,
  temperature 0.5, configurable max_tokens, 30 s timeout. Powers the in-app chatbot
  (chatbot_engine) with session history + markdown rendering.
- **Firebase**: Auth (email/password, Google, Apple), Cloud Firestore (per-user vitals/events/
  contacts/reports/feedback sync), Storage (profile pictures). Project id `cardiva-30297`.
- **Native SMS** via url_launcher `sms:` URIs (sms_service) — emergency alerts to registered
  contacts; no Twilio.
- **GPS** via geolocator (location_service) — real coordinates embedded in emergency alerts.
- **Background monitoring**: flutter_background_service runs a ~5-minute monitoring loop
  (background_service) so vitals classification continues when app is backgrounded.
- **PDF reports**: pdf package (pdf_report_service) generates health reports; share_plus /
  WhatsApp sharing; persistent WPS-style report history.

### 3.6 Implemented feature set (for narrative completeness)
Firebase auth (email/Google/Apple); profile setup; emergency-contact setup+storage; BLE
scaffold + mock data; rule-based classification; 4-class status engine; on-device TFLite ML
(fall + emergency); emergency SMS via url_launcher; AI Analysis screen w/ auto-analysis
pipeline; Groq chatbot; PDF report generation + sharing; report manager w/ history; 5-min
background monitoring; real GPS in alerts; attendant/caregiver management; incident reporting;
feedback module (star + category chips); notification preferences; dark/light theme.

---

## 4. TESTING FACTS (for Chapter 6)

### 4.1 End-to-end hardware test checklist (verified, from hardware docs)
1. Flash firmware, open Serial Monitor @115200; confirm "=== Cardiva Ready ===" prints.
2. OLED shows boot screen then live dashboard with pulsing heart icon.
3. Finger held firmly+still on MAX30100 → after 10–15 s HR & SpO2 stabilize (OLED + Serial).
4. Install/open app; grant Bluetooth/Location permissions.
5. Scan screen lists "Cardiva-ESP32".
6. Tap device → status pill = Connected; vitals begin updating.
7. ECG/animation reflects live HR value.
8. Sharp movement (simulated drop) → fall banner in app + inverted FALL! on OLED.
9. Walking → activity changes Resting → Walking/Active.

### 4.2 Troubleshooting matrix (verified)
| Symptom | Likely cause / fix |
|---|---|
| Sensor missing from I2C scan | wiring/power; confirm same SDA/SCL bus |
| pox.begin() FAILED | MAX30100 wiring or library not installed |
| HR stays 0 with finger on | press firmer, hold still, wait 10–15 s |
| App can't find ESP32 | Bluetooth on, permissions granted, device powered + in range |
| Connects but no vitals | check "BLE TX:" serial logs; verify UUIDs match firmware↔app |
| Gradle sync fails (MPAndroidChart) | JitPack repo missing in settings.gradle |

### 4.3 Software test surfaces (derive test cases — describe as engineering judgement, do not
fabricate pass/fail metrics you cannot support)
- Unit: VitalClassifier band edges (e.g. resting HR 100 vs 101 → Normal vs Stable/Warning),
  SpO2/HRV/RR thresholds, activity-adjusted HR, confidence gate at 70.
- Unit: BleService._parse — valid JSON → VitalReading; heart==0&&spo2==0 → null (dropped);
  malformed JSON → null (no crash).
- Integration: BLE notify → vital_provider → health_status_engine → 4-class output →
  emergency_trigger → SMS intent; mock_data_service path for hardware-free runs.
- System/E2E: §4.1 hardware checklist; emergency flow with GPS + SMS to a test contact;
  background 5-min loop continues when app backgrounded; report generation + share.
- UI/acceptance: auth, profile/contact setup, dashboard live update, history charts, chatbot
  response, notifications, theme switch.

### 4.4 Verification vs validation framing (for 6.2)
- **Verification** ("building it right"): static analysis (`flutter analyze`), unit tests on the
  engine/parser, firmware serial-log checks, BLE UUID/payload contract conformance.
- **Validation** ("building the right thing"): does the system meet user needs — accurate vitals
  on a real finger, timely fall/emergency detection, alert actually reaches the contact, usable
  by a cardiac patient + caregiver. Tie back to Chapter 1 objectives.

---

## 5. STRUCTURE & WRITING RULES

1. Use Word paragraph styles: section titles = **Heading1** (chapter), **Heading2**, **Heading3**;
   body = **Normal**; captions = **Caption** style ("Table X.Y: …" above tables, "Figure X.Y: …"
   below figures). Do NOT type chapter numbers in headings (auto-numbered).
2. Academic, formal, third-person, present tense for the system ("The firmware computes…").
   No marketing tone, no "we will". Coherent flow; each section opens with a short framing
   sentence and ends with a bridge.
3. Realize tabular data as **real Word tables** (BOM, pin map, GATT contract, activity SD bands,
   vital thresholds, dependency list, test cases). Header row gets the project's subtle
   light-blue fill + dark bold text (the formatter will normalize, but build them as tables).
4. **No fabrication.** Use only values in this brief / the source tree. Where a metric is
   genuinely unmeasured (e.g. clinical accuracy %), say it is qualitative / demo-grade and
   state the upgrade path — do not invent numbers or pass-rates.
5. Cross-reference earlier chapters by name where natural ("the architecture defined in
   Chapter 4", "the objectives in Chapter 1") — but no fake figure/equation numbers.
6. In-text citations: these two chapters describe original project work, so external citations
   are minimal. If you state an external fact (e.g. a clinical normal-range claim already
   established in Ch.2), reference it generically rather than inventing a new numbered source.
   Do not create a References section here unless one already exists — citation/References
   consolidation (#14) is a separate pass.
7. Keep Chapter 5 substantial (software modules + hardware + integration + dev environment).
   Keep Chapter 6 organized exactly to the spec headings (6.1–6.5.1) with a concrete Sample
   Test Case in 6.5.1 (use the table format: ID, Title, Precondition, Steps, Expected, Actual,
   Status — fill with a real, defensible scenario such as fall-detection end-to-end).
