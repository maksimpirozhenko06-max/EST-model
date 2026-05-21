#include "DHT.h"
#include "HX711.h"

// --- DHT SENSORS SETUP ---
#define DHTPIN_TOP    4
#define DHTPIN_MIDDLE 5
#define DHTPIN_BOTTOM 6

#define DHTTYPE DHT22

// Initialize three separate DHT sensors
DHT dhtTop(DHTPIN_TOP, DHTTYPE);
DHT dhtMiddle(DHTPIN_MIDDLE, DHTTYPE);
DHT dhtBottom(DHTPIN_BOTTOM, DHTTYPE);

// --- HX711 LOAD CELL SETUP ---
const int LOADCELL_DOUT_PIN = 2;
const int LOADCELL_SCK_PIN = 3;
HX711 scale;

// --- CALIBRATION VALUES ---
// REPLACE THESE WITH YOUR ACTUAL CALCULATED NUMBERS!
float k = 0.001453;
float b = -861.83;  

void setup() {
  Serial.begin(9600); 
  
  // Initialize sensors
  dhtTop.begin();
  dhtMiddle.begin();
  dhtBottom.begin();

  // Initialize scale
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  
  Serial.println("Starting live readings...");
}

void loop() {
  // DHT sensors need 2 seconds between readings
  delay(2000);

  // --- 1. READ WEIGHT ---
  float weight = 0;
  if (scale.is_ready()) {
    long raw_val = scale.read_average(5);
    weight = (k * raw_val) + b;
  }

  // --- 2. READ DHT SENSORS (Celsius Only) ---
  float t_top = dhtTop.readTemperature();
  float t_mid = dhtMiddle.readTemperature();
  float t_bot = dhtBottom.readTemperature();

  // --- 3. OUTPUT RESULTS ON ONE LINE ---
  
  // Weight
  Serial.print("Weight: "); 
  Serial.print(weight);
  Serial.print(" g  |  ");

  // Bottom Sensor
  Serial.print("Bottom: ");
  if (isnan(t_bot)) {
    Serial.print("Error");
  } else {
    Serial.print(t_bot);
    Serial.print(" *C");
  }
  Serial.print("  |  ");

  // Middle Sensor
  Serial.print("Middle: ");
  if (isnan(t_mid)) {
    Serial.print("Error");
  } else {
    Serial.print(t_mid);
    Serial.print(" *C");
  }
  Serial.print("  |  ");

  // Top Sensor
  Serial.print("Top: ");
  if (isnan(t_top)) {
    Serial.print("Error");
  } else {
    Serial.print(t_top);
    Serial.print(" *C");
  }

  // Finally, print a newline character so the NEXT reading goes on a new line
  Serial.println(); 
}