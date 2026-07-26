/*  CARDIVA wearable firmware — Arduino IDE sketch
 *
 *  Hardware on this board (auto-detected via I2C):
 *    - MAX30100 pulse oximeter  @ 0x57   (HR / SpO2)   -> MAX30100lib
 *    - MPU6050-class accel/gyro @ 0x69   (AD0 high, motion/fall) -> direct register access
 *    - SH1106 OLED 128x64       @ 0x3C   (display)     -> Adafruit_SH110X
 *    - BLE (Cardiva)                     (phone app)
 *
 *  ── Arduino IDE setup (one-time) ──────────────────────────────────────────
 *  1. File > Preferences > "Additional boards manager URLs":
 *       https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
 *  2. Tools > Board > Boards Manager: install "esp32 by Espressif Systems"
 *  3. Tools > Board: select "ESP32 Dev Module"
 *  4. Sketch > Include Library > Manage Libraries: install
 *       - "Adafruit GFX Library"       (adafruit)
 *       - "Adafruit SH110X"            (adafruit)
 *       - "MAX30100lib"                (oxullo)
 *  5. This file must live in a folder with the SAME name as the file, e.g.
 *       hardware/cardiva_esp32/cardiva_esp32.ino
 *     (Arduino IDE will offer to do this for you automatically on first open.)
 *  6. Tools > Port: select the CH340 USB-serial port the board enumerates as.
 *  7. Tools > Upload Speed: 921600 (or 115200 if uploads fail/timeout).
 *  8. Click Upload. Tools > Serial Monitor at 115200 baud to see live output.
 *
 *  No platformio.ini / PlatformIO install needed for this workflow — this is
 *  the exact same firmware, just built with Arduino IDE's own toolchain.
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>          // this board's OLED is an SH1106, NOT SSD1306
#include "MAX30100_PulseOximeter.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define ENABLE_BLE  1           // BLE for phone app
#define ENABLE_MPU  1           // motion / fall
#define ENABLE_OLED 1           // OLED display

// ---- Pins / I2C addresses ----
#define SDA_PIN   21
#define SCL_PIN   22
#define OLED_ADDR 0x3C
#define MPU_ADDR  0x69          // NOTE: this board's motion sensor is at 0x69 (AD0 high)
#define MPU_PWR_MGMT_1   0x6B
#define MPU_ACCEL_CONFIG 0x1C
#define MPU_ACCEL_XOUT_H 0x3B
#define SCREEN_W  128
#define SCREEN_H  64

// ---- BLE UUIDs (these are what the Cardiva phone app scans for — verified from the APK) ----
#define SERVICE_UUID  "12345678-1234-5678-1234-56789abcdef0"
#define VITALS_UUID   "12345678-1234-5678-1234-56789abcdef1"   // single vitals characteristic
#define DEVICE_NAME   "Cardiva"

Adafruit_SH1106G display = Adafruit_SH1106G(SCREEN_W, SCREEN_H, &Wire, -1);
PulseOximeter    pox;

BLEServer*         pServer  = nullptr;
BLECharacteristic* chVitals = nullptr;
bool bleConnected = false;
bool oledOK = false, poxOK = false, mpuOK = false;

// ---- Vitals ----
float heartRate = 0, spo2 = 0, hrvRMSSD = 0, respRate = 14.0;
float ax = 0, ay = 0, az = 0;
String activity = "STILL";
bool  fallDetected = false;

// ---- Heartbeat / HRV ----
uint32_t lastBeat = 0;
#define IBI_N 20
float ibis[IBI_N];
int   ibiIdx = 0, ibiCount = 0;
#define STALE_BEAT_MS 3000     // no beat this long = finger off -> reset HRV/resp instead of freezing

// ---- Respiration (estimated from RSA: breathing rhythmically speeds/slows
// the heartbeat, so counting that rhythm in the beat-to-beat intervals gives
// a real breaths/min estimate -- there's no dedicated respiration sensor) ----
float    rrPrevIbi     = -1;
int      rrDir         = 0;      // 1 = IBI rising, -1 = falling
int      rrPeaks       = 0;      // one peak (rising->falling) = one breath cycle
uint32_t rrWindowStart = 0;
#define  RR_WINDOW_MS  20000     // recompute breaths/min over a 20s sliding window
#define  RR_NOISE_MS   8         // ignore sub-8ms IBI wiggle as sensor noise, not breathing

// ---- Fall detection ----
int      ffCount    = 0;        // consecutive weightless samples
uint32_t fallTime   = 0;        // when the current fall was flagged
#define  FALL_HOLD_MS 5000      // keep the FALL alert on screen this long

uint32_t tsReport = 0, tsScreen = 0, tsMPU = 0;
bool showHealth = true;

class SrvCB : public BLEServerCallbacks {
  void onConnect(BLEServer* s) override    { bleConnected = true;  Serial.println(">>> BLE: phone CONNECTED"); }
  void onDisconnect(BLEServer* s) override { bleConnected = false; Serial.println(">>> BLE: phone DISCONNECTED"); BLEDevice::startAdvertising(); }
};

void updateRespiration(float ibi) {
  if (rrWindowStart == 0) rrWindowStart = millis();
  if (rrPrevIbi >= 0) {
    int newDir;
    if      (ibi > rrPrevIbi + RR_NOISE_MS) newDir = 1;
    else if (ibi < rrPrevIbi - RR_NOISE_MS) newDir = -1;
    else                                    newDir = rrDir;   // tiny wiggle: keep direction
    if (rrDir == 1 && newDir == -1) rrPeaks++;                // local max = one breath
    rrDir = newDir;
  }
  rrPrevIbi = ibi;
}

void onBeat() {
  uint32_t now = millis();
  if (lastBeat) {
    float ibi = now - lastBeat;
    if (ibi > 300 && ibi < 2000) {          // plausible 30-200 bpm
      ibis[ibiIdx] = ibi;
      ibiIdx = (ibiIdx + 1) % IBI_N;
      if (ibiCount < IBI_N) ibiCount++;
      updateRespiration(ibi);
    }
  }
  lastBeat = now;
}

// Chronological read of the circular IBI buffer: k=0 is the oldest sample,
// k=ibiCount-1 is the newest. (ibis[] wraps once full, so raw indices alone
// are NOT in time order -- reading them directly silently corrupts RMSSD.)
float ibiAt(int k) {
  int start = (ibiCount < IBI_N) ? 0 : ibiIdx;
  return ibis[(start + k) % IBI_N];
}

void computeHRV() {                          // RMSSD of successive IBIs
  if (ibiCount < 3) { hrvRMSSD = 0; return; }
  float sum = 0; int n = 0;
  for (int i = 1; i < ibiCount; i++) { float d = ibiAt(i) - ibiAt(i - 1); sum += d * d; n++; }
  hrvRMSSD = (n > 0) ? sqrt(sum / n) : 0;
}

// Finalizes the respiration estimate once the sliding window elapses, and
// clears HRV/respiration state once beats stop arriving (finger off) so
// these values reset instead of staying frozen at their last reading.
void updateVitalsWindow() {
  if (lastBeat != 0 && millis() - lastBeat > STALE_BEAT_MS) {
    ibiCount = 0; ibiIdx = 0; hrvRMSSD = 0;
    rrPrevIbi = -1; rrDir = 0; rrPeaks = 0; rrWindowStart = 0; respRate = 0;
    lastBeat = 0;
    return;
  }
  if (rrWindowStart != 0 && millis() - rrWindowStart > RR_WINDOW_MS) {
    float elapsedSec = (millis() - rrWindowStart) / 1000.0f;
    float estimate = (rrPeaks / elapsedSec) * 60.0f;
    if (estimate >= 6 && estimate <= 35) respRate = estimate;  // physiological sanity clamp
    rrPeaks = 0;
    rrWindowStart = millis();
  }
}

void setupBLE() {
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(247);                     // allow the full vitals JSON (avoid truncation)
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new SrvCB());
  BLEService* svc = pServer->createService(SERVICE_UUID);

  chVitals = svc->createCharacteristic(VITALS_UUID,
             BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  chVitals->addDescriptor(new BLE2902());

  svc->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n\n===== CARDIVA FIRMWARE (fixed HR) =====");

  Wire.begin(SDA_PIN, SCL_PIN);

  // OLED
#if ENABLE_OLED
  oledOK = display.begin(OLED_ADDR, true);
  Serial.println(oledOK ? "OLED  : OK" : "OLED  : FAIL");
  if (oledOK) {
    display.clearDisplay();
    display.setTextColor(SH110X_WHITE);
    display.setTextSize(2); display.setCursor(18, 18); display.print("CARDIVA");
    display.setTextSize(1); display.setCursor(28, 46); display.print("starting...");
    display.display();
    Wire.setClock(100000);   // keep the OLED at 100 kHz to avoid display glitching
  }
#else
  Serial.println("OLED  : DISABLED (HR isolation test)");
#endif

  // MPU6050/6500/9250 — talk to it directly (works for any variant at 0x69)
#if ENABLE_MPU
  Wire.beginTransmission(MPU_ADDR);
  mpuOK = (Wire.endTransmission() == 0);
  if (mpuOK) {
    Wire.beginTransmission(MPU_ADDR);           // wake from sleep
    Wire.write(MPU_PWR_MGMT_1); Wire.write(0x00);
    Wire.endTransmission(true);
    Wire.beginTransmission(MPU_ADDR);           // accel range = +/-8g (0x10)
    Wire.write(MPU_ACCEL_CONFIG); Wire.write(0x10);   // wide range so impacts register
    Wire.endTransmission(true);
  }
  Serial.println(mpuOK ? "MPU6050 : OK" : "MPU6050 : FAIL");
#else
  Serial.println("MPU6050 : DISABLED (HR isolation test)");
#endif

#if ENABLE_BLE
  setupBLE();
  Serial.println("BLE   : advertising as 'Cardiva'");
#else
  Serial.println("BLE   : DISABLED (HR isolation test)");
#endif

  // MAX30100 pulse oximeter — initialise LAST, right before loop(), so the
  // ~1-2 s BLE setup can't stall the sensor FIFO and break beat detection.
  // Retry begin() a few times since the sensor can be slow to answer.
  delay(200);
  for (int i = 0; i < 8 && !poxOK; i++) {
    poxOK = pox.begin();
    if (!poxOK) { Serial.print("  MAX30100 retry "); Serial.println(i + 1); delay(200); }
  }
  Serial.println(poxOK ? "MAX30100: OK" : "MAX30100: FAIL");
  if (poxOK) {
    pox.setIRLedCurrent(MAX30100_LED_CURR_50MA);
    pox.setOnBeatDetectedCallback(onBeat);
  }
  // loop() begins immediately now, so pox.update() runs without delay.
}

void readMPU() {
  if (!mpuOK) return;
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(MPU_ACCEL_XOUT_H);
  if (Wire.endTransmission(false) != 0) return;
  if (Wire.requestFrom(MPU_ADDR, 6, (int)true) < 6) return;
  int16_t rx = (Wire.read() << 8) | Wire.read();
  int16_t ry = (Wire.read() << 8) | Wire.read();
  int16_t rz = (Wire.read() << 8) | Wire.read();
  ax = rx / 4096.0f;                         // +/-8g -> 4096 LSB/g
  ay = ry / 4096.0f;
  az = rz / 4096.0f;
  float mag = sqrt(ax * ax + ay * ay + az * az);

  // ---- FALL DETECTION ----
  // Trigger on EITHER: sustained free-fall (the device is dropping -> mag ~0),
  // OR a hard impact spike (a heavy knock/landing -> mag high, now readable at +/-8g).
  if (mag < 0.45f) ffCount++;                 // counting weightless samples
  else             ffCount = 0;

  bool freeFalling = (ffCount >= 3);          // ~60 ms of weightlessness = a real drop
  bool impact      = (mag > 2.5f);            // a strong jolt

  if ((freeFalling || impact) && !fallDetected) {
    fallDetected = true;
    fallTime = millis();
    Serial.println(">>> FALL DETECTED!");
  }

  float dev = fabs(mag - 1.0f);
  if      (dev < 0.06f) activity = "STILL";
  else if (dev < 0.25f) activity = "MOVING";
  else                  activity = "ACTIVE";
}

void drawHealth() {
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print(bleConnected ? "HEALTH (BLE ON)" : "HEALTH (BLE --)");
  display.drawLine(0, 10, 127, 10, SH110X_WHITE);
  display.setCursor(0, 16); display.print("HR:   "); display.print(heartRate, 1);
  display.setCursor(0, 28); display.print("SpO2: "); display.print(spo2, 0); display.print(" %");
  display.setCursor(0, 40); display.print("HRV:  "); display.print(hrvRMSSD, 1);
  display.setCursor(0, 52); display.print("RESP: "); display.print(respRate, 1);
  display.display();
}

void drawMotion() {
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("MOTION (g) -> BLE");
  display.drawLine(0, 10, 127, 10, SH110X_WHITE);
  display.setCursor(0, 16); display.print("X: "); display.print(ax, 2);
  display.setCursor(0, 28); display.print("Y: "); display.print(ay, 2);
  display.setCursor(0, 40); display.print("Z: "); display.print(az, 2);
  display.setCursor(0, 52); display.print(activity);
  display.display();
}

// Full-screen fall alert that takes over both pages, blinking for visibility.
void drawFallAlert() {
  static bool inv = false;
  inv = !inv;
  display.clearDisplay();
  if (inv) display.fillRect(0, 0, 128, 64, SH110X_WHITE);
  uint16_t fg = inv ? SH110X_BLACK : SH110X_WHITE;
  display.setTextColor(fg);
  display.setTextSize(3);
  display.setCursor(14, 8);  display.print("FALL!");
  display.setTextSize(1);
  display.setCursor(8, 44);  display.print("Check on wearer");
  display.display();
}

void loop() {
  if (poxOK) pox.update();                   // must run as often as possible

#if ENABLE_MPU
  if (millis() - tsMPU > 20) { tsMPU = millis(); readMPU(); }  // 50 Hz to catch fast drops
#endif

  if (millis() - tsReport > 1000) {
    tsReport = millis();
    if (poxOK) { heartRate = pox.getHeartRate(); spo2 = pox.getSpO2(); }
    updateVitalsWindow();
    computeHRV();

    if (ENABLE_BLE && bleConnected) {
      // The app parses a CSV string (NOT JSON):
      //   "HR,SpO2,HRV,Resp,AcX,AcY,AcZ,Activity"
      // AcX/Y/Z are in g-units (the app multiplies them by 9.81).
      // Activity is STILL | MOVING | FALL  (FALL is how a fall is signalled).
      const char* actField = fallDetected ? "FALL"
                           : (activity == "MOVING" || activity == "ACTIVE") ? "MOVING"
                           : "STILL";
      char v[80];
      snprintf(v, sizeof(v), "%.1f,%.1f,%.1f,%.1f,%.2f,%.2f,%.2f,%s",
               heartRate, spo2, hrvRMSSD, respRate, ax, ay, az, actField);
      chVitals->setValue(v); chVitals->notify();
      Serial.print(">>> BLE notify (CSV) -> "); Serial.println(v);
    }

    // Serial line in the same style as your original firmware
    Serial.printf("HR:%.2f SpO2:%.2f HRV(RMSSD):%.2f Resp(est):%.2f X:%.3f Y:%.3f Z:%.3f LocalFall:%s\n",
                  heartRate, spo2, hrvRMSSD, respRate, ax, ay, az, fallDetected ? "yes" : "no");

  }
  // Auto-clear the fall flag after the hold time so the alert doesn't stay forever
  if (fallDetected && millis() - fallTime > FALL_HOLD_MS) fallDetected = false;

  // Refresh screen. Normally once a second (so the OLED's ~100 ms blocking write
  // doesn't starve the MAX30100). During a fall, refresh faster so it blinks.
  uint32_t screenInterval = fallDetected ? 350 : 1000;
  if (oledOK && millis() - tsScreen > screenInterval) {
    tsScreen = millis();
    Wire.setClock(100000);                          // OLED needs 100 kHz; the MAX30100
                                                    // lib leaves the bus at 400 kHz -> ghosting
    if (fallDetected) {
      drawFallAlert();                              // full-screen alert overrides both pages
    } else {
      static int cnt = 0;
      if (++cnt % 4 == 0) showHealth = !showHealth; // swap page ~every 4 s
      if (showHealth) drawHealth(); else drawMotion();
    }
    pox.update();                                   // drain FIFO right after the blocking write
  }
}
