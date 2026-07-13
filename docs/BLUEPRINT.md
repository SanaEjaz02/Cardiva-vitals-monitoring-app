# 🏥 CARDIVA — Full App Development Blueprint

**Role:** Act as a Senior Flutter Developer with Firebase expertise. Build a complete cardiac monitoring mobile application called **CARDIVA** with the following exact flow, logic, and screens.

---

## PART 1: APP LAUNCH & ONBOARDING

On the very first launch after installation, show **3 onboarding screens** that introduce the app. The user can tap **"Skip"** at any point to bypass onboarding. Onboarding is shown only once — never again after the first launch.

---

## PART 2: AUTHENTICATION FLOW

After onboarding (or on subsequent launches), show the **Login / Register** screen.

### 2A. Login

- If the user is already registered, they enter credentials and log in.
- After successful login, redirect the user based on their **role** (Guardian Portal or Patient Portal).

### 2B. Register — New User

1. User taps **"Register"**.
2. A **Role Selection** screen appears with two options: `Patient` and `Guardian`.
3. User selects their role and proceeds.

**Email Check:** Before creating any account, the system must check if an account already exists with that email.
- If yes → show error: **"Already Registered"**
- If no → proceed with registration

---

## PART 3: GUARDIAN REGISTRATION & PORTAL

### 3A. Guardian Registration

1. User selects `Guardian` role.
2. Collects: `Username`, `Email`, `Password`, `Confirm Password`.
3. On **"Continue"**: validate that `Password == Confirm Password`. Show error if mismatch.
4. If valid: create account and save `Username`, `Email`, `Password` to **Firebase Realtime Database**.
5. Show **Initial Setup** screen: collect `Full Name` and `Phone Number`.
6. After setup → log user into the **Guardian Portal**.

---

### 3B. Guardian Portal — 4 Bottom Navigation Tabs

#### Behavior depends on linkage status:

**IF Guardian IS linked to a registered Patient:**

| Tab | Content |
|-----|---------|
| **Dashboard** | Latest health data of the linked Patient, shown after their analysis is complete |
| **Chats** | Auto-load chat with the linked Patient. Real-time 1-to-1 messaging |
| **Alerts** | All location-based and emergency alerts from the Patient, separate from chat |
| **Profile** | Guardian's full profile with `Edit Profile` and `Sign Out` options |

**IF Guardian is NOT linked to any Patient:**

| Tab | Content |
|-----|---------|
| **Dashboard** | Empty state — no data |
| **Chats** | Empty inbox — no Patient |
| **Alerts** | Empty state |
| **Profile** | Normal profile data (always visible) |

---

## PART 4: PATIENT REGISTRATION & PORTAL

### 4A. Patient Registration

1. User selects `Patient` role on role selection screen.
2. User enters initial credentials (`Username`, `Email`, `Password`, `Confirm Password`).
3. System checks if email already exists → show **"Already Registered"** if yes.
4. If new → register successfully.

### 4B. Patient Initial Setup (3 Screens)

After registration, confirm role again (`Patient` or `Guardian`). User selects `Patient`. Then:

- **Setup Screen 1:** Enter `Full Name` and `Vitals` (baseline health info).
- **Setup Screen 2:** `Brand/Device Connection` — connect their wearable band here, or **skip** to do it later.
- **Setup Screen 3:** `Guardian Data` — add `Guardian's Name`, `Email`, and `Phone Number`. Multiple guardians can be added.

After completing all 3 screens → user is logged into the **Patient Portal**.

---

### 4C. Patient Portal — 5 Bottom Navigation Tabs

---

#### TAB 1: Dashboard

On first login (no analysis run yet), all vital values show as **Null/Zero**.

Values only appear **after the latest analysis is complete**.

**Layout:**
- **Top:** Patient's `Name` + `Username` + Profile Icon
- **Below:** `Confidence Score` / `Health Score`
- **Vitals Section:** Latest values for `SPO2`, `RR`, `HRV`, `HR`, `Activity`, `Fall Detection`

**3 Main Cards on Dashboard:**
1. **Reports Card** — All saved health reports. Empty if new patient.
2. **Cardiva Card** — AI Chatbot. Shows full chat history with the Cardiva assistant.
3. **SOS Emergency Button** — Tapping this immediately triggers an **Emergency Alert** to all registered Guardians.

---

#### TAB 2: Vitals

Displays all vitals in **Card View** format:

- `SPO2`, `RR`, `HRV`, `HR`
- `Activity`
- `Fall Detection`

**Detail Logic:**
- Tapping any Card opens a **Vital Detail Screen**.
- At the bottom of every Detail Screen: **"Ask Cardiva"** chatbot — the user can ask questions about that specific vital and receive AI responses.

---

#### TAB 3: Analysis Screen (Active after Band Connect)

Once the band is connected, this screen shows **Real-time Vitals**, `Activity`, and `Fall Detection` values.

**Analysis runs continuously. It has 4 cases:**

| Case | Condition | Action |
|------|-----------|--------|
| **Normal** | Vitals normal + No fall | All good — no alert |
| **Vitals Alert** | No fall + Vitals in alert/emergency range | Emergency situation triggered |
| **Fall Alert** | Fall detected + Vitals normal | Fall alert triggered |
| **Emergency** | Vitals in alert range + Fall detected | Most critical — auto-send Emergency Alert to all registered Guardians |

---

#### TAB 4: Chats

- Real-time messaging between Patient and Guardian(s).
- **If Guardian is already registered** in the system → they appear directly in Chats.
- **If Guardian is NOT registered** → they show as **"Pending"** in the Chats tab.
- Emergency **Alerts** also appear in this screen, and Guardian's **response** to alerts is also recorded here.

---

#### TAB 5: Profile

Patient manages everything here:

1. **Edit Profile** — update personal info and settings
2. **Feedback** — submit app feedback
3. **Logout / Delete Account** — sign out or permanently delete account
4. **Account Switch** — switch between accounts
5. **Manage Guardians** — add new Guardians or remove existing ones
6. **Band Connect/Disconnect:**
   - Shows current band status: `Connected` or `Disconnected`
   - Tap Connect → Bluetooth scan starts
   - Device appears in list → tap to connect
   - Once connected → Live Vitals values appear on screen
   - `Note:` `RR` value shows **Zero initially** for the first 15–20 seconds (calculation delay)

---

## PART 5: DATA & PERSISTENCE

- Use **Firebase Realtime Database** for all data storage.
- As analysis runs continuously, all **Health Reports**, **Analysis Results**, **Alerts**, and **Chats** are saved to the database in real-time.
- On every **next login**, all previous data (reports, chats, vitals history) is retrieved and shown to the user automatically.

---

## PART 6: TECH REQUIREMENTS

| Requirement | Technology |
|-------------|-----------|
| Framework | Flutter |
| Backend | Firebase Realtime Database |
| Auth | Firebase Authentication |
| Real-time chat | Firebase Realtime Database streams |
| Bluetooth | Flutter Bluetooth plugin (`flutter_blue_plus`) |

- Handle **empty states** gracefully for: Dashboard, Chats, and Alerts tabs (for both Guardian and Patient portals)
- Profile tab always shows data — no empty state needed

---

## PART 7: CURRENT IMPLEMENTATION STATUS

### Implemented ✅
- Firebase Auth (email/password, Google Sign-in, Apple Sign-in)
- 3-screen onboarding (shown once)
- Role-based routing (Patient / Guardian)
- Patient profile setup (name, age, height, weight, gender)
- Emergency contacts setup + Firestore storage (per-user)
- BLE wearable service (`flutter_blue_plus`) + Mock data (dev mode)
- Rule-based vital classification engine
- 4-class health status engine: `Normal` / `Vitals Alert` / `Fall Alert` / `Emergency`
- On-device ML — fall detection + emergency classification (TFLite)
- Emergency alert trigger (in-app chat + RTDB push + local notification)
- AI Analysis screen with auto-analysis pipeline
- Groq LLM chatbot with session history + markdown rendering
- PDF report generation + WhatsApp sharing
- Report manager with persistent history
- Background monitoring (5-minute loop)
- Real GPS location in emergency alerts
- Attendant / caregiver management screen
- Incident reporting module
- Feedback module (star rating + category chips)
- Notification preferences screen
- Dark/light theme via settings provider
- BLE hardware connection (ESP32 + MAX30100 + MPU6050)
- Password reset screen

### Pending ⬜
- Guardian Portal (separate 4-tab view for caregivers)
- Attendant portal (caregiver's separate view)
- End-to-end testing
- App store build preparation

---

## PART 8: BLE HARDWARE (ESP32 BAND)

**Firmware:** `firmware/cardiva_esp32/cardiva_esp32.ino`

**BLE UUIDs:**
- Service: `12345678-1234-5678-1234-56789abcdef0`
- Vitals Characteristic: `12345678-1234-5678-1234-56789abcdef1`

**BLE Packet Format (8-field CSV):**
```
"HR,SpO2,HRV,Resp,AcX,AcY,AcZ,Activity"
```
Example: `"72.3,97.0,45.2,14.8,0.023,0.993,-0.105,STILL"`

| Field | Index | Description |
|-------|-------|-------------|
| HR | 0 | Heart Rate (bpm) |
| SpO2 | 1 | Blood Oxygen (%) |
| HRV | 2 | RMSSD (ms) |
| Resp | 3 | Respiration estimate (br/min) |
| AcX | 4 | Accelerometer X (g) |
| AcY | 5 | Accelerometer Y (g) |
| AcZ | 6 | Accelerometer Z (g) |
| Activity | 7 | `STILL` / `MOVING` / `FALL` |
