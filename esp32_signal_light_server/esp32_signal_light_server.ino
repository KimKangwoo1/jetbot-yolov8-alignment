#include <WiFi.h>
#include <WebServer.h>
#include <Adafruit_NeoPixel.h>

// Wi-Fi settings
const char* WIFI_SSID = "DigiDep 2F1";
const char* WIFI_PASSWORD = "";

// Laptop network:
// laptop IP      = 192.168.0.116
// gateway        = 192.168.0.253
// ESP32 fixed IP = 192.168.0.162
IPAddress local_IP(192, 168, 0, 162);
IPAddress gateway(192, 168, 0, 253);
IPAddress subnet(255, 255, 255, 0);

// These values match the Bluetooth code that already worked.
#define LED_PIN 12
#define LED_COUNT 72

Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);
WebServer server(80);

// LED number ranges
#define RED_START     0
#define RED_END       20

#define YELLOW_START  21
#define YELLOW_END    41

#define LEFT_START    42
#define LEFT_END      50

#define GREEN_START   51
#define GREEN_END     71

String currentSignal = "OFF";

void clearAll() {
  for (int i = 0; i < LED_COUNT; i++) {
    strip.setPixelColor(i, 0, 0, 0);
  }
}

void fillRange(int startLed, int endLed, int r, int g, int b) {
  for (int i = startLed; i <= endLed; i++) {
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
}

void showRed() {
  clearAll();
  fillRange(RED_START, RED_END, 255, 0, 0);
  strip.show();

  currentSignal = "RED";
  Serial.println("CURRENT:RED");
}

void showYellow() {
  clearAll();
  fillRange(YELLOW_START, YELLOW_END, 255, 150, 0);
  strip.show();

  currentSignal = "YELLOW";
  Serial.println("CURRENT:YELLOW");
}

void showGreen() {
  clearAll();
  fillRange(GREEN_START, GREEN_END, 0, 255, 0);
  strip.show();

  currentSignal = "GREEN";
  Serial.println("CURRENT:GREEN");
}

void showLeft() {
  clearAll();
  fillRange(LEFT_START, LEFT_END, 0, 255, 0);
  strip.show();

  currentSignal = "LEFT";
  Serial.println("CURRENT:LEFT");
}

void showRedAndLeft() {
  clearAll();
  fillRange(RED_START, RED_END, 255, 0, 0);
  fillRange(LEFT_START, LEFT_END, 0, 255, 0);
  strip.show();

  currentSignal = "RED_LEFT";
  Serial.println("CURRENT:RED_LEFT");
}

void showAllWhite() {
  clearAll();
  fillRange(0, LED_COUNT - 1, 255, 255, 255);
  strip.show();

  currentSignal = "ALL";
  Serial.println("CURRENT:ALL");
}

void showOff() {
  clearAll();
  strip.show();

  currentSignal = "OFF";
  Serial.println("CURRENT:OFF");
}

bool applySignal(String cmd) {
  cmd.trim();
  cmd.toUpperCase();

  Serial.print("HTTP Command: ");
  Serial.println(cmd);

  if (cmd == "GREEN") {
    showGreen();
  } else if (cmd == "YELLOW") {
    showYellow();
  } else if (cmd == "RED") {
    showRed();
  } else if (cmd == "LEFT") {
    showLeft();
  } else if (cmd == "RED_LEFT") {
    showRedAndLeft();
  } else if (cmd == "ALL") {
    showAllWhite();
  } else if (cmd == "OFF") {
    showOff();
  } else {
    return false;
  }

  return true;
}

void bootLightTest() {
  showRed();
  delay(700);
  showYellow();
  delay(700);
  showGreen();
  delay(700);
  showLeft();
  delay(700);
  showRedAndLeft();
  delay(700);
  showRed();
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  if (!WiFi.config(local_IP, gateway, subnet)) {
    Serial.println("Static IP configuration failed");
  }

  Serial.print("Connecting to Wi-Fi");

  if (strlen(WIFI_PASSWORD) == 0) {
    WiFi.begin(WIFI_SSID);
  } else {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Connected. IP address: ");
  Serial.println(WiFi.localIP());
}

void handleRoot() {
  server.send(
    200,
    "text/plain",
    "OK. Use /signal?state=RED, YELLOW, GREEN, LEFT, RED_LEFT, ALL, or OFF."
  );
}

void handleSignal() {
  if (!server.hasArg("state")) {
    server.send(400, "text/plain", "Missing state");
    return;
  }

  String cmd = server.arg("state");

  if (!applySignal(cmd)) {
    server.send(400, "text/plain", "Invalid state: " + cmd);
    return;
  }

  server.send(200, "text/plain", "OK " + currentSignal);
}

void handleTest() {
  Serial.println("HTTP Command: TEST");
  bootLightTest();
  server.send(200, "text/plain", "OK TEST");
}

void setup() {
  Serial.begin(115200);

  strip.begin();
  strip.setBrightness(40);
  strip.show();

  Serial.println("LED boot test start");
  bootLightTest();
  Serial.println("LED boot test done");

  connectWiFi();

  server.on("/", HTTP_GET, handleRoot);
  server.on("/signal", HTTP_GET, handleSignal);
  server.on("/test", HTTP_GET, handleTest);
  server.begin();

  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}
