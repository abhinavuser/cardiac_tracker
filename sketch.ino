#include <Arduino.h>

const int ecgPin = 34;  
const int BUFFER_SIZE = 50;
int readings[BUFFER_SIZE];
int readIndex = 0;
unsigned long lastPeakTime = 0;
int threshold = 100;  // Adjust based on your sensor's output
float bpm = 0;

void setup() {
  Serial.begin(115200);
  pinMode(ecgPin, INPUT);
  
  // Initialize readings buffer
  for (int i = 0; i < BUFFER_SIZE; i++) {
    readings[i] = 0;
  }
}

void loop() {
  int rawValue = analogRead(ecgPin);
  
  // Store reading
  readings[readIndex] = rawValue;
  readIndex = (readIndex + 1) % BUFFER_SIZE;
  
  // Find local maximum
  if (readIndex == 0) {
    int max = 0;
    for (int i = 0; i < BUFFER_SIZE; i++) {
      if (readings[i] > max) {
        max = readings[i];
      }
    }
    
    // If max exceeds threshold, consider it a peak
    if (max > threshold) {
      unsigned long currentTime = millis();
      if (lastPeakTime != 0) {
        float timeDiff = (currentTime - lastPeakTime) / 1000.0;  // Convert to seconds
        float instantBPM = 60.0 / timeDiff;  // Convert to BPM
        
        // Apply reasonable bounds
        if (instantBPM >= 40 && instantBPM <= 200) {
          // Smooth BPM using moving average
          bpm = (bpm * 0.7) + (instantBPM * 0.3);
        }
      }
      lastPeakTime = currentTime;
    }
  }
  
  // Send both raw value and calculated BPM
  Serial.print(rawValue);
  Serial.print(",");
  Serial.println(bpm);
  
  delay(5);  // 200Hz sampling rate
}
