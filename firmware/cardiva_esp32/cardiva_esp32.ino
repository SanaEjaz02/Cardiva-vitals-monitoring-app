/*
  ================================================================
  HEALTH BAND FIRMWARE — ESP32 + MAX30100 + MPU6050 + BLE
  ================================================================
  - HR, SpO2, HRV (RMSSD), Respiration estimate: unchanged, working well
  - BLE device name: "Cardiva"
  - X, Y, Z accelerometer values (calibrated, in g) are sent over BLE
    so the app-side ML model can perform its own fall detection.
    On-device fall detection is kept as a lightweight local backup only.
  ================================================================
*/

#include <Wire.h>
#include <U8g2lib.h>
#include <MAX30100_PulseOximeter.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------------- CONFIG ----------------
#define REPORTING_PERIOD_MS   1000
#define MPU_ADDR               0x69
#define ACCEL_SENSITIVITY   16384.0f   // LSB per g, for +-2g range

// BLE UUIDs — must match app's ble_service.dart
#define SERVICE_UUID           "12345678-1234-5678-1234-56789abcdef0"
#define VITALS_CHAR_UUID       "12345678-1234-5678-1234-56789abcdef1"
#define ALERT_CHAR_UUID        "12345678-1234-1234-1234-1234567890ad"
#define MOTION_CHAR_UUID       "12345678-1234-1234-1234-1234567890ae"

// ---------------- OLED ----------------
U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);

// ---------------- MAX30100 ----------------
PulseOximeter pox;
uint32_t tsLastReport = 0;
uint32_t lastBeatMillis = 0;

// ---------------- MPU6050 raw ----------------
int16_t AcX_raw, AcY_raw, AcZ_raw;
int16_t Tmp_raw;
int16_t GyX_raw, GyY_raw, GyZ_raw;

// ---------------- Calibrated accel (g units) — sent to app ----------------
float AcX_g = 0, AcY_g = 0, AcZ_g = 0;
float accelMagnitude = 0;

// ---------------- Health metrics ----------------
float bpm = 0;
float spo2 = 0;
float hrv_rmssd = 0;
float respirationEst = 0;

// ---------------- HRV: IBI buffer for RMSSD ----------------
#define IBI_BUFFER_SIZE 10
float ibiBuffer[IBI_BUFFER_SIZE];
int ibiIndex = 0;
int ibiCount = 0;

// ---------------- BPM history (for respiration proxy) ----------------
float bpmHistory[20];
int bpmIndex = 0;
bool bufferFilled = false;
float avgBPM = 0;
float previousAvg = 0;

// ---------------- Local backup fall detection (lightweight, app model is primary) ----------------
enum FallState { STATE_NORMAL, STATE_FREEFALL };
FallState fallState = STATE_NORMAL;
uint32_t freefallStartMillis = 0;
uint32_t fallLatchedMillis = 0;
bool fallDetected = false;
bool moving = false;

const float FREEFALL_THRESHOLD_G = 0.35;
const float IMPACT_THRESHOLD_G   = 2.5;
const uint32_t IMPACT_WINDOW_MS  = 500;
const uint32_t FALL_LATCH_MS     = 5000;

// ---------------- OLED paging ----------------
char txt[20];
int screen = 0;

// ---------------- BLE globals ----------------
BLEServer *pServer = nullptr;
BLECharacteristic *vitalsCharacteristic = nullptr;
BLECharacteristic *alertCharacteristic = nullptr;
BLECharacteristic *motionCharacteristic = nullptr;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *s) override {
    deviceConnected = true;
  }
  void onDisconnect(BLEServer *s) override {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

// ================================================================
// Beat detection callback -> updates HRV via RMSSD
// ================================================================
void onBeatDetected()
{
  uint32_t now = millis();

  if (lastBeatMillis != 0)
  {
    float interval = (float)(now - lastBeatMillis);

    if (interval > 300 && interval < 2000)
    {
      ibiBuffer[ibiIndex] = interval;
      ibiIndex = (ibiIndex + 1) % IBI_BUFFER_SIZE;
      if (ibiCount < IBI_BUFFER_SIZE) ibiCount++;

      if (ibiCount >= 2)
      {
        float sumSqDiff = 0;
        int pairs = 0;

        for (int i = 1; i < ibiCount; i++)
        {
          int idxCurrent = (ibiIndex - ibiCount + i + IBI_BUFFER_SIZE * 2) % IBI_BUFFER_SIZE;
          int idxPrev    = (ibiIndex - ibiCount + i - 1 + IBI_BUFFER_SIZE * 2) % IBI_BUFFER_SIZE;

          float diff = ibiBuffer[idxCurrent] - ibiBuffer[idxPrev];
          sumSqDiff += diff * diff;
          pairs++;
        }

        if (pairs > 0)
          hrv_rmssd = sqrt(sumSqDiff / pairs);
      }
    }
  }

  lastBeatMillis = now;
}

// ================================================================
// Setup
// ================================================================
void setup()
{
  Serial.begin(115200);

  Wire.begin(21, 22);
  Wire.setClock(400000);

  u8g2.begin();
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_ncenB08_tr);
  u8g2.drawStr(10, 25, "Initializing");
  u8g2.sendBuffer();

  // ---------------- MAX30100 ----------------
  if (!pox.begin())
  {
    u8g2.clearBuffer();
    u8g2.drawStr(0, 30, "MAX30100 ERROR");
    u8g2.sendBuffer();
    while (1);
  }
  pox.setIRLedCurrent(MAX30100_LED_CURR_50MA);
  pox.setOnBeatDetectedCallback(onBeatDetected);

  // ---------------- MPU6050 wake ----------------
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B);
  Wire.write(0);
  Wire.endTransmission(true);

  for (int i = 0; i < 20; i++) bpmHistory[i] = 0;
  for (int i = 0; i < IBI_BUFFER_SIZE; i++) ibiBuffer[i] = 0;

  // ---------------- BLE init ----------------
  BLEDevice::init("Cardiva");
  BLEDevice::setMTU(185);

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  vitalsCharacteristic = pService->createCharacteristic(
      VITALS_CHAR_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  vitalsCharacteristic->addDescriptor(new BLE2902());

  motionCharacteristic = pService->createCharacteristic(
      MOTION_CHAR_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  motionCharacteristic->addDescriptor(new BLE2902());

  alertCharacteristic = pService->createCharacteristic(
      ALERT_CHAR_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  alertCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("System Ready - BLE Advertising Started (Cardiva)");
}

// ================================================================
// Read MPU6050 and convert to calibrated g-units
// ================================================================
void readMPU()
{
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  Wire.endTransmission(false);

  uint8_t bytesReceived = Wire.requestFrom(MPU_ADDR, 14, true);

  if (bytesReceived == 14 && Wire.available() == 14)
  {
    AcX_raw = (Wire.read() << 8) | Wire.read();
    AcY_raw = (Wire.read() << 8) | Wire.read();
    AcZ_raw = (Wire.read() << 8) | Wire.read();
    Tmp_raw = (Wire.read() << 8) | Wire.read();
    GyX_raw = (Wire.read() << 8) | Wire.read();
    GyY_raw = (Wire.read() << 8) | Wire.read();
    GyZ_raw = (Wire.read() << 8) | Wire.read();

    AcX_g = AcX_raw / ACCEL_SENSITIVITY;
    AcY_g = AcY_raw / ACCEL_SENSITIVITY;
    AcZ_g = AcZ_raw / ACCEL_SENSITIVITY;

    accelMagnitude = sqrt(AcX_g * AcX_g + AcY_g * AcY_g + AcZ_g * AcZ_g);

    moving = (accelMagnitude > 1.3 || accelMagnitude < 0.7);
  }
  else
  {
    while (Wire.available()) Wire.read();
  }
}

// ================================================================
// Lightweight local backup fall check
// ================================================================
void updateFallDetection()
{
  uint32_t now = millis();

  switch (fallState)
  {
    case STATE_NORMAL:
      if (accelMagnitude < FREEFALL_THRESHOLD_G)
      {
        fallState = STATE_FREEFALL;
        freefallStartMillis = now;
      }
      break;

    case STATE_FREEFALL:
      if (accelMagnitude > IMPACT_THRESHOLD_G)
      {
        fallDetected = true;
        fallLatchedMillis = now;
        fallState = STATE_NORMAL;
      }
      else if (now - freefallStartMillis > IMPACT_WINDOW_MS)
      {
        fallState = STATE_NORMAL;
      }
      break;

    default:
      fallState = STATE_NORMAL;
      break;
  }

  if (fallDetected && (now - fallLatchedMillis > FALL_LATCH_MS))
  {
    fallDetected = false;
  }
}

// ================================================================
// Send data over BLE
//
// VITALS_CHAR_UUID -> "HR,SpO2,HRV,Resp,AcX,AcY,AcZ,Activity"
//   8-field combined packet — app _parse() reads all fields from here
//
// MOTION_CHAR_UUID -> "AcX,AcY,AcZ,Activity"
//   secondary stream, kept for future use
// ================================================================
void sendBLEData()
{
  if (!deviceConnected) return;

  const char* activityStatus = fallDetected ? "FALL" : (moving ? "MOVING" : "STILL");

  char vitalsPayload[80];
  snprintf(vitalsPayload, sizeof(vitalsPayload), "%.1f,%.1f,%.1f,%.1f,%.3f,%.3f,%.3f,%s",
           bpm, spo2, hrv_rmssd, respirationEst,
           AcX_g, AcY_g, AcZ_g, activityStatus);

  vitalsCharacteristic->setValue((uint8_t*)vitalsPayload, strlen(vitalsPayload));
  vitalsCharacteristic->notify();

  char motionPayload[40];
  snprintf(motionPayload, sizeof(motionPayload), "%.3f,%.3f,%.3f,%s",
           AcX_g, AcY_g, AcZ_g, activityStatus);
  motionCharacteristic->setValue((uint8_t*)motionPayload, strlen(motionPayload));
  motionCharacteristic->notify();

  if (fallDetected)
  {
    const char* alertMsg = "FALL_DETECTED";
    alertCharacteristic->setValue((uint8_t*)alertMsg, strlen(alertMsg));
    alertCharacteristic->notify();
  }
}

// ================================================================
// Loop
// ================================================================
void loop()
{
  pox.update();
  readMPU();
  updateFallDetection();

  if (millis() - tsLastReport >= REPORTING_PERIOD_MS)
  {
    tsLastReport = millis();

    bpm  = pox.getHeartRate();
    spo2 = pox.getSpO2();

    // ---------------- BPM rolling average ----------------
    bpmHistory[bpmIndex] = bpm;
    bpmIndex++;
    if (bpmIndex >= 20)
    {
      bpmIndex = 0;
      bufferFilled = true;
    }

    int count = bufferFilled ? 20 : bpmIndex;
    avgBPM = 0;
    for (int i = 0; i < count; i++) avgBPM += bpmHistory[i];
    if (count > 0) avgBPM /= count;

    // ---------------- Respiration ESTIMATE (RSA proxy) ----------------
    float diff = fabs(avgBPM - previousAvg);
    respirationEst = 14 + diff * 2.0f;
    if (respirationEst < 10) respirationEst = 10;
    if (respirationEst > 25) respirationEst = 25;
    previousAvg = avgBPM;

    // ---------------- Serial debug ----------------
    Serial.print("HR:");   Serial.print(bpm);
    Serial.print(" SpO2:"); Serial.print(spo2);
    Serial.print(" HRV(RMSSD):"); Serial.print(hrv_rmssd);
    Serial.print(" Resp(est):"); Serial.print(respirationEst);
    Serial.print(" X:"); Serial.print(AcX_g, 3);
    Serial.print(" Y:"); Serial.print(AcY_g, 3);
    Serial.print(" Z:"); Serial.print(AcZ_g, 3);
    Serial.print(" LocalFall:"); Serial.println(fallDetected ? "YES" : "no");

    // ---------------- BLE send ----------------
    sendBLEData();

    // ---------------- OLED ----------------
    screen++;
    if (screen > 1) screen = 0;

    u8g2.clearBuffer();
    u8g2.setFont(u8g2_font_6x10_tf);

    if (screen == 0)
    {
      u8g2.drawStr(0, 10, deviceConnected ? "HEALTH (BLE ON)" : "HEALTH (BLE --)");

      u8g2.drawStr(0, 23, "HR:");
      dtostrf(bpm, 4, 1, txt);
      u8g2.drawStr(35, 23, txt);

      u8g2.drawStr(0, 36, "SpO2:");
      dtostrf(spo2, 4, 1, txt);
      u8g2.drawStr(35, 36, txt);

      u8g2.drawStr(0, 49, "HRV:");
      dtostrf(hrv_rmssd, 4, 1, txt);
      u8g2.drawStr(35, 49, txt);

      u8g2.drawStr(0, 62, "Resp~:");
      dtostrf(respirationEst, 4, 1, txt);
      u8g2.drawStr(45, 62, txt);
    }
    else
    {
      u8g2.drawStr(0, 10, "MOTION (g) -> BLE");

      u8g2.drawStr(0, 24, "X:");
      dtostrf(AcX_g, 6, 2, txt);
      u8g2.drawStr(20, 24, txt);

      u8g2.drawStr(0, 36, "Y:");
      dtostrf(AcY_g, 6, 2, txt);
      u8g2.drawStr(20, 36, txt);

      u8g2.drawStr(0, 48, "Z:");
      dtostrf(AcZ_g, 6, 2, txt);
      u8g2.drawStr(20, 48, txt);

      if (fallDetected)
        u8g2.drawStr(0, 62, "!! FALL !!");
      else if (moving)
        u8g2.drawStr(0, 62, "MOVING");
      else
        u8g2.drawStr(0, 62, "STILL");
    }

    u8g2.sendBuffer();

    pox.update();
    pox.update();
    pox.update();
  }
}
