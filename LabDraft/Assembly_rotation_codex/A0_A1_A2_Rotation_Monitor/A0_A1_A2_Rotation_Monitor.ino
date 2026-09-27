// Three-cylinder + rotation-sensor monitor for the excavator model.
//
// Wiring:
//   A0, A1, A2 : existing cylinder position sensors
//   A3         : 0..360 degree rotation potentiometer
//
// CSV output (115200 baud, 50 Hz):
// time_ms,A0_q_m,A1_q_m,A2_q_m,A0_length_mm,A1_length_mm,A2_length_mm,
// A0_raw,A1_raw,A2_raw,rotation_angle_deg,rotation_raw

const uint8_t CYLINDER_PINS[] = {A0, A1, A2};
const uint8_t CYLINDER_COUNT = sizeof(CYLINDER_PINS) / sizeof(CYLINDER_PINS[0]);
const uint8_t ROTATION_PIN = A3;
const unsigned long BAUD_RATE = 115200;
const unsigned long SAMPLE_INTERVAL_MS = 20; // 50 Hz

// Existing cylinder calibration, ordered as {A0, A1, A2}.
const int adcAtWorkMin[CYLINDER_COUNT] = {1022, 984, 960};
const int adcAtWorkMax[CYLINDER_COUNT] = {607, 1, 0};
const float workMinDistanceMm[CYLINDER_COUNT] = {155.0f, 170.0f, 170.0f};
const float workMaxDistanceMm[CYLINDER_COUNT] = {170.0f, 220.0f, 220.0f};

// Simscape Prismatic Joint q calibration in metres.
const float modelQAtWorkMinM[CYLINDER_COUNT] = { 0.0075f,  0.0250f,  0.0250f};
const float modelQAtWorkMaxM[CYLINDER_COUNT] = {-0.0075f, -0.0250f, -0.0250f};
const bool modelQCalibrated[CYLINDER_COUNT] = {true, true, true};

const bool CLAMP_TO_MEASURED_WORK_RANGE = true;
const uint8_t FILTER_SAMPLES = 4;

int cylinderHistory[CYLINDER_COUNT][FILTER_SAMPLES] = {};
int rotationHistory[FILTER_SAMPLES] = {};
uint8_t historyIndex = 0;
unsigned long lastSampleTime = 0;

static int filteredCylinderRead(uint8_t channel) {
  cylinderHistory[channel][historyIndex] = analogRead(CYLINDER_PINS[channel]);
  long total = 0;
  for (uint8_t i = 0; i < FILTER_SAMPLES; ++i) {
    total += cylinderHistory[channel][i];
  }
  return (int)(total / FILTER_SAMPLES);
}

static int filteredRotationRead() {
  rotationHistory[historyIndex] = analogRead(ROTATION_PIN);
  long total = 0;
  for (uint8_t i = 0; i < FILTER_SAMPLES; ++i) {
    total += rotationHistory[i];
  }
  return (int)(total / FILTER_SAMPLES);
}

static float rawToMeasuredDistanceMm(uint8_t channel, int rawValue) {
  const float rawSpan = (float)(adcAtWorkMax[channel] - adcAtWorkMin[channel]);
  if (rawSpan == 0.0f) return workMinDistanceMm[channel];

  float fraction = (rawValue - adcAtWorkMin[channel]) / rawSpan;
  if (CLAMP_TO_MEASURED_WORK_RANGE) fraction = constrain(fraction, 0.0f, 1.0f);
  return workMinDistanceMm[channel] +
         fraction * (workMaxDistanceMm[channel] - workMinDistanceMm[channel]);
}

static float rawToModelJointDisplacementMetres(uint8_t channel, int rawValue) {
  if (!modelQCalibrated[channel]) return 0.0f;
  const float rawSpan = (float)(adcAtWorkMax[channel] - adcAtWorkMin[channel]);
  if (rawSpan == 0.0f) return modelQAtWorkMinM[channel];

  float fraction = (rawValue - adcAtWorkMin[channel]) / rawSpan;
  if (CLAMP_TO_MEASURED_WORK_RANGE) fraction = constrain(fraction, 0.0f, 1.0f);
  return modelQAtWorkMinM[channel] +
         fraction * (modelQAtWorkMaxM[channel] - modelQAtWorkMinM[channel]);
}

static float rawToRotationDegrees(int rawValue) {
  const int limitedRaw = constrain(rawValue, 0, 1023);
  return limitedRaw * (360.0f / 1023.0f);
}

void setup() {
  Serial.begin(BAUD_RATE);
  while (!Serial) { ; }

  for (uint8_t channel = 0; channel < CYLINDER_COUNT; ++channel) {
    const int initial = analogRead(CYLINDER_PINS[channel]);
    for (uint8_t i = 0; i < FILTER_SAMPLES; ++i) {
      cylinderHistory[channel][i] = initial;
    }
  }

  const int initialRotation = analogRead(ROTATION_PIN);
  for (uint8_t i = 0; i < FILTER_SAMPLES; ++i) {
    rotationHistory[i] = initialRotation;
  }

  Serial.println(F("time_ms,A0_q_m,A1_q_m,A2_q_m,A0_length_mm,A1_length_mm,A2_length_mm,A0_raw,A1_raw,A2_raw,rotation_angle_deg,rotation_raw"));
}

void loop() {
  const unsigned long now = millis();
  if (now - lastSampleTime < SAMPLE_INTERVAL_MS) return;
  lastSampleTime = now;

  int rawValues[CYLINDER_COUNT];
  float distancesMm[CYLINDER_COUNT];
  for (uint8_t channel = 0; channel < CYLINDER_COUNT; ++channel) {
    rawValues[channel] = filteredCylinderRead(channel);
    distancesMm[channel] = rawToMeasuredDistanceMm(channel, rawValues[channel]);
  }
  const int rotationRaw = filteredRotationRead();
  const float rotationAngleDeg = rawToRotationDegrees(rotationRaw);

  Serial.print(now);
  for (uint8_t channel = 0; channel < CYLINDER_COUNT; ++channel) {
    Serial.print(',');
    Serial.print(rawToModelJointDisplacementMetres(channel, rawValues[channel]), 6);
  }
  for (uint8_t channel = 0; channel < CYLINDER_COUNT; ++channel) {
    Serial.print(',');
    Serial.print(distancesMm[channel], 3);
  }
  for (uint8_t channel = 0; channel < CYLINDER_COUNT; ++channel) {
    Serial.print(',');
    Serial.print(rawValues[channel]);
  }
  Serial.print(',');
  Serial.print(rotationAngleDeg, 3);
  Serial.print(',');
  Serial.println(rotationRaw);

  historyIndex = (historyIndex + 1) % FILTER_SAMPLES;
}
