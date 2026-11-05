/*
  MyoMetrics | MyoWare 2.0 ENV capture | Arduino Nano ESP32
  --------------------------------------------------------
  MyoWare VIN -> Nano ESP32 3.3V
  MyoWare GND -> Nano ESP32 GND
  MyoWare ENV -> Nano ESP32 A0

  Serial output: device_time_ms,env_adc
  One CSV pair per sample, about 100 samples/second.
  ENV is the sensor's already-rectified/smoothed activation signal.
  Not raw EMG. No resistors required.

  Use Board: Arduino Nano ESP32, Serial: 115200 baud.
*/

const int EMG_PIN = A0;
const unsigned long SAMPLE_PERIOD_MS = 10; // approximately 100 Hz
unsigned long lastSampleMs = 0;

void setup() {
  Serial.begin(115200);
  analogReadResolution(12); // 12-bit values: nominally 0...4095
  pinMode(EMG_PIN, INPUT);
}

void loop() {
  unsigned long now = millis();
  if (now - lastSampleMs >= SAMPLE_PERIOD_MS) {
    lastSampleMs = now;
    int envelopeAdc = analogRead(EMG_PIN);
    Serial.print(now);
    Serial.print(',');
    Serial.println(envelopeAdc);
  }
}
