#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30100_PulseOximeter.h"
#include <MPU9250_asukiaaa.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// PINS & DISPLAY
#define SDA_PIN       21
#define SCL_PIN       22
#define OLED_RESET    -1
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64

// BLE UUIDs
#define SERVICE_UUID      "12345678-1234-5678-1234-56789abcdef0"
#define VITALS_CHAR_UUID  "12345678-1234-5678-1234-56789abcdef1"
#define DEVICE_NAME       "Cardiva-ESP32"

// TIMING
#define REPORT_INTERVAL_MS    1000
#define IBI_BUF_SIZE          20
#define ACCEL_BUF_SIZE        50
#define NO_FINGER_TIMEOUT_MS  8000

// OBJECTS
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
PulseOximeter    pox;
MPU9250_asukiaaa mpu;

BLEServer*         pServer     = nullptr;
BLECharacteristic* pVitalsChar = nullptr;
bool deviceConnected    = false;
bool oldDeviceConnected = false;

// VITALS
float   heartRate       = 0;
float   spo2            = 0;
float   hrvSDNN         = 0;
float   respirationRate = 0;
String  activityState   = "Resting";
bool    fallDetected    = false;
bool    fingerPresent   = false;

uint32_t tsLastReport  = 0;
uint32_t tsLastBeat    = 0;
uint32_t tsLastBeatAbs = 0;
uint8_t  animFrame     = 0;

// IBI buffer
uint32_t ibiBuffer[IBI_BUF_SIZE];
int      ibiIndex = 0;
int      ibiCount = 0;

// RSA respiration
#define RSA_SMOOTH_ALPHA  0.25f
#define RSA_TREND_ALPHA   0.08f
#define RSA_MIN_BREATH_MS 1500
float    rsaSmoothed  = 0;
float    rsaTrend     = 0;
bool     rsaInited    = false;
bool     rsaRising    = false;
uint32_t rsaLastBreath = 0;
uint32_t rsaIntervals[6];
int      rsaBufIdx   = 0;
int      rsaBufCount = 0;

// Accel buffer
float    accelBuf[ACCEL_BUF_SIZE];
int      accelIdx     = 0;
bool     accelBufFull = false;

// Fall detection
bool     inFreeFall    = false;
uint32_t freeFallStart = 0;

// sends 9 SCL pulses to unstick any slave holding SDA low
void i2cBusRecover() {
  pinMode(SDA_PIN, OUTPUT);
  pinMode(SCL_PIN, OUTPUT);
  digitalWrite(SDA_PIN, HIGH);
  for (int i = 0; i < 9; i++) {
    digitalWrite(SCL_PIN, LOW);  delayMicroseconds(5);
    digitalWrite(SCL_PIN, HIGH); delayMicroseconds(5);
  }
  // STOP condition
  digitalWrite(SDA_PIN, LOW);  delayMicroseconds(5);
  digitalWrite(SCL_PIN, HIGH); delayMicroseconds(5);
  digitalWrite(SDA_PIN, HIGH); delayMicroseconds(5);
  pinMode(SDA_PIN, INPUT);
  pinMode(SCL_PIN, INPUT);
  delay(50);
}

// ─── BLE CALLBACKS ───────────────────────────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) override    { deviceConnected = true;  }
  void onDisconnect(BLEServer* s) override { deviceConnected = false; }
};

// ─── RSA RESPIRATION ─────────────────────────────────────────────────────────
void feedRSA(uint32_t ibiMs) {
  float ibi = (float)ibiMs;
  if (!rsaInited) {
    rsaSmoothed = ibi;
    rsaTrend    = ibi;
    rsaInited   = true;
    return;
  }
  rsaSmoothed = RSA_SMOOTH_ALPHA * ibi + (1.0f - RSA_SMOOTH_ALPHA) * rsaSmoothed;
  rsaTrend    = RSA_TREND_ALPHA  * ibi + (1.0f - RSA_TREND_ALPHA)  * rsaTrend;
  bool above  = rsaSmoothed > rsaTrend;

  if (rsaRising && !above) {
    uint32_t now = millis();
    if (rsaLastBreath != 0) {
      uint32_t gap = now - rsaLastBreath;
      if (gap > RSA_MIN_BREATH_MS && gap < 15000) {
        rsaIntervals[rsaBufIdx] = gap;
        rsaBufIdx = (rsaBufIdx + 1) % 6;
        if (rsaBufCount < 6) rsaBufCount++;
      }
    }
    rsaLastBreath = now;
  }
  rsaRising = above;
}

// ─── BEAT CALLBACK ───────────────────────────────────────────────────────────
void onBeatDetected() {
  uint32_t now = millis();
  tsLastBeatAbs = now;
  fingerPresent = true;

  if (tsLastBeat != 0) {
    uint32_t ibi = now - tsLastBeat;
    if (ibi > 300 && ibi < 2000) {
      // FIX 4: print ibi before updating tsLastBeat
      Serial.print("Beat! IBI=");
      Serial.print(ibi);
      Serial.println("ms");

      ibiBuffer[ibiIndex] = ibi;
      ibiIndex = (ibiIndex + 1) % IBI_BUF_SIZE;
      if (ibiCount < IBI_BUF_SIZE) ibiCount++;
      feedRSA(ibi);
    }
  }
  tsLastBeat = now;
}

// ─── SETUP ───────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(400);
  Serial.println("\n====== Cardiva Booting ======");

  i2cBusRecover();
  Wire.begin(SDA_PIN, SCL_PIN);
  // enable internal pull-ups — multiple I2C devices cause high bus capacitance
  pinMode(SDA_PIN, INPUT_PULLUP);
  pinMode(SCL_PIN, INPUT_PULLUP);
  Wire.setClock(10000);

  // OLED — try 0x3C first, fallback to 0x3D
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] 0x3C failed, trying 0x3D...");
    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
      Serial.println("[ERR] OLED init failed on both addresses!");
    } else {
      Serial.println("[OLED] OK on 0x3D");
      showBootScreen();
    }
  } else {
    Serial.println("[OLED] OK on 0x3C");
    display.invertDisplay(false);
    showBootScreen();
  }

  // MAX30100
  Serial.print("[MAX30100] Initializing... ");
  if (!pox.begin()) {
    Serial.println("FAILED - check wiring!");
  } else {
    Serial.println("OK");
    pox.setIRLedCurrent(MAX30100_LED_CURR_50MA);
    pox.setOnBeatDetectedCallback(onBeatDetected);
  }

  // MPU9250
  mpu.setWire(&Wire);
  mpu.beginAccel();
  mpu.beginGyro();
  Serial.println("[MPU9250] OK");

  Wire.setClock(400000);  // sensors work fine at 400kHz

  // BLE
  setupBLE();

  Serial.println("====== Cardiva Ready ======");
  Serial.println("Place fingertip FLAT on sensor, hold still 15-20 sec...\n");
}

// ─── BLE SETUP ───────────────────────────────────────────────────────────────
void setupBLE() {
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* svc = pServer->createService(SERVICE_UUID);
  pVitalsChar = svc->createCharacteristic(
    VITALS_CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pVitalsChar->addDescriptor(new BLE2902());
  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising as: " + String(DEVICE_NAME));
}

// ─── MAIN LOOP ────────────────────────────────────────────────────────────────
void loop() {
  pox.update();
  updateMPU();
  handleBLEReconnect();

  // finger timeout
  if (tsLastBeatAbs != 0 && millis() - tsLastBeatAbs > NO_FINGER_TIMEOUT_MS) {
    fingerPresent = false;
    heartRate     = 0;
    spo2          = 0;
  }

  if (millis() - tsLastReport > REPORT_INTERVAL_MS) {
    tsLastReport = millis();

    heartRate = pox.getHeartRate();
    spo2      = pox.getSpO2();

    if (heartRate > 20 && spo2 > 50) {
      fingerPresent = true;
      tsLastBeatAbs = millis();
    }

    computeHRV();
    computeRespiration();
    classifyActivity();

    // FIX 2: OLED first, then BLE — so fallDetected is still true when OLED checks it
    updateOLED();
    sendBLE();

    animFrame = (animFrame + 1) % 4;

    Serial.printf("[VITALS] HR=%.0f  SpO2=%.0f  HRV=%.0f  RR=%.0f  Act=%s  Finger=%s  BLE=%s\n",
      heartRate, spo2, hrvSDNN, respirationRate,
      activityState.c_str(),
      fingerPresent ? "YES" : "NO",
      deviceConnected ? "CONN" : "ADV");
  }
}

// ─── MPU9250 ─────────────────────────────────────────────────────────────────
void updateMPU() {
  if (mpu.accelUpdate() != 0) return;

  float ax  = mpu.accelX();
  float ay  = mpu.accelY();
  float az  = mpu.accelZ();
  float mag = sqrt(ax*ax + ay*ay + az*az);

  accelBuf[accelIdx] = mag;
  accelIdx = (accelIdx + 1) % ACCEL_BUF_SIZE;
  if (accelIdx == 0) accelBufFull = true;

  if (!inFreeFall) {
    if (mag < 0.3f) { inFreeFall = true; freeFallStart = millis(); }
  } else {
    uint32_t elapsed = millis() - freeFallStart;
    if (elapsed < 1500) {
      // require free fall to last at least 80ms before impact counts
      if (elapsed > 80 && mag > 3.5f) { fallDetected = true; inFreeFall = false; }
    } else {
      inFreeFall = false;
    }
  }
}

// ─── HRV (SDNN) ──────────────────────────────────────────────────────────────
void computeHRV() {
  if (ibiCount < 5) { hrvSDNN = 0; return; }

  float mean = 0;
  for (int i = 0; i < ibiCount; i++) mean += ibiBuffer[i];
  mean /= ibiCount;

  float var = 0;
  for (int i = 0; i < ibiCount; i++) {
    float d = ibiBuffer[i] - mean;
    var += d * d;
  }
  hrvSDNN = sqrt(var / ibiCount);
}

// ─── RESPIRATION (RSA) ────────────────────────────────────────────────────────
void computeRespiration() {
  if (rsaLastBreath == 0 || millis() - rsaLastBreath > 12000) {
    respirationRate = 0;
    return;
  }
  if (rsaBufCount < 2) return;

  float mean = 0;
  for (int i = 0; i < rsaBufCount; i++) mean += rsaIntervals[i];
  mean /= rsaBufCount;

  float bpm = 60000.0f / mean;
  if (bpm < 6)  bpm = 6;
  if (bpm > 40) bpm = 40;
  respirationRate = bpm;
}

// ─── ACTIVITY CLASSIFICATION ─────────────────────────────────────────────────
void classifyActivity() {
  int n = accelBufFull ? ACCEL_BUF_SIZE : accelIdx;
  if (n < 5) { activityState = "Resting"; return; }

  float mean = 0;
  for (int i = 0; i < n; i++) mean += accelBuf[i];
  mean /= n;

  float var = 0;
  for (int i = 0; i < n; i++) {
    float d = accelBuf[i] - mean;
    var += d * d;
  }
  float sd = sqrt(var / n);

  if      (sd < 0.02f) activityState = "Resting";
  else if (sd < 0.15f) activityState = "Sedentary";
  else if (sd < 0.50f) activityState = "Walking";
  else                 activityState = "Active";
}

// ─── BLE RECONNECT ───────────────────────────────────────────────────────────
void handleBLEReconnect() {
  if (!deviceConnected && oldDeviceConnected) {
    delay(300);
    pServer->startAdvertising();
    oldDeviceConnected = false;
    Serial.println("[BLE] Restarting advertising...");
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = true;
    Serial.println("[BLE] Phone connected!");
  }
}

// ─── SEND BLE JSON ───────────────────────────────────────────────────────────
void sendBLE() {
  String json = "{";
  json += "\"hr\":"    + String(heartRate, 1)      + ",";
  json += "\"spo2\":"  + String(spo2, 1)            + ",";
  json += "\"hrv\":"   + String(hrvSDNN, 1)         + ",";
  json += "\"rr\":"    + String(respirationRate, 1) + ",";
  json += "\"act\":\"" + activityState              + "\",";
  json += "\"fall\":"  + String(fallDetected ? "true" : "false");
  json += "}";

  if (deviceConnected) {
    pVitalsChar->setValue(json.c_str());
    pVitalsChar->notify();
  }

  if (fallDetected) fallDetected = false;
}

// ─── OLED BOOT SCREEN ────────────────────────────────────────────────────────
void showBootScreen() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(16, 14);
  display.println("CARDIVA");
  display.drawFastHLine(10, 36, 108, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 44);
  display.println("Initializing...");
  oledShow();
  delay(1200);
}

// ─── OLED HEART ICON ─────────────────────────────────────────────────────────
void drawHeart(int x, int y, bool big) {
  int s = big ? 1 : 0;
  display.fillCircle(x+3, y+3, 3+s, SSD1306_WHITE);
  display.fillCircle(x+9, y+3, 3+s, SSD1306_WHITE);
  display.fillTriangle(x-1, y+4, x+13, y+4, x+6, y+13+s, SSD1306_WHITE);
}

// reset I2C speed before every OLED write — MPU9250 library changes it at runtime
void oledShow() {
  Wire.setClock(10000);   // ultra slow for OLED — fix I2C data corruption
  display.display();
  Wire.setClock(400000);  // restore fast speed for sensors
}

// ─── OLED MAIN SCREEN ────────────────────────────────────────────────────────
void updateOLED() {
  display.invertDisplay(false);
  display.clearDisplay();

  // Status bar
  display.fillCircle(4, 4, 3, deviceConnected ? SSD1306_WHITE : SSD1306_BLACK);
  display.drawCircle(4, 4, 3, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 0);
  display.print(deviceConnected ? "Connected" : "No BLE");

  uint32_t s = millis() / 1000;
  display.setCursor(93, 0);
  display.printf("%02lu:%02lu", (s / 60) % 60, s % 60);

  display.drawFastHLine(0, 10, 128, SSD1306_WHITE);

  // No finger message
  if (!fingerPresent) {
    display.setTextSize(1);
    display.setCursor(10, 20);
    display.println("Place finger on");
    display.setCursor(10, 32);
    display.println("MAX30100 sensor");
    display.setCursor(10, 46);
    display.println("Hold still 15-20s");
    oledShow();
    return;
  }

  // FIX 3: Fall overlay — draw to buffer AND call display.display() so it actually shows
  if (fallDetected) {
    display.clearDisplay();
    display.invertDisplay(true);
    display.setTextSize(2);
    display.setCursor(18, 18);
    display.println("FALL!");
    display.setTextSize(1);
    display.setCursor(14, 44);
    display.println("Check on wearer");
    oledShow();
    delay(2000);
    display.invertDisplay(false);
    display.clearDisplay();
    oledShow();
    return;              // ← skip normal vitals draw this cycle
  }

  // HR (left) | SpO2 (right)
  drawHeart(2, 14, animFrame % 2 == 0);

  display.setTextSize(2);
  display.setCursor(18, 13);
  display.printf("%.0f", heartRate);
  display.setTextSize(1);
  display.setCursor(18, 30);
  display.print("bpm");

  display.drawFastVLine(64, 11, 28, SSD1306_WHITE);

  display.setTextSize(2);
  display.setCursor(70, 13);
  display.printf("%.0f%%", spo2);
  display.setTextSize(1);
  display.setCursor(70, 30);
  display.print("SpO2");

  display.drawFastHLine(0, 40, 128, SSD1306_WHITE);

  // Bottom row: HRV / RR / Activity
  display.setTextSize(1);
  display.setCursor(0, 43);
  if (hrvSDNN > 0) display.printf("HRV:%.0fms", hrvSDNN);
  else             display.print("HRV: --");

  display.setCursor(0, 54);
  if (respirationRate > 0) display.printf("RR:%.0f/min", respirationRate);
  else                     display.print("RR: --");

  // Activity badge
  int bw = activityState.length() * 6 + 6;
  int bx = 126 - bw;
  display.drawRoundRect(bx, 47, bw, 14, 2, SSD1306_WHITE);
  display.setCursor(bx + 3, 51);
  display.print(activityState);

  oledShow();
}
