#include <Arduino.h>
#include <WiFiNINA.h>
#include <ArduinoHttpClient.h>

const char* ssid = "SKY2YBBC";
const char* pass = "Kvqtx2X6bixq";
const char* serverAddress = "http://europe-west2-discount-manager-f6248.cloudfunctions.net/update_people";
const int port = 443;

WiFiClient wifi;
HttpClient client = HttpClient(wifi, serverAddress, port);
int status = WL_IDLE_STATUS;

// 定义连接到第一个HC-SR04传感器的引脚
const int trigPin1 = 2;
const int echoPin1 = 3;

// 定义连接到第二个HC-SR04传感器的引脚
const int trigPin2 = 4;
const int echoPin2 = 5;

// 用于存储人数的变量
int peopleCount = 0;

// 存储传感器的状态
bool sensor1Active = false;
bool sensor2Active = false;
bool sensor1LastActive = false;
bool sensor2LastActive = false;

// 增加用于跟踪传感器激活顺序的变量
int lastSensorActivated = 0;

long measureDistance(int trigPin, int echoPin) {
  // 清空触发引脚
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  
  // 产生一个10微秒的高脉冲到触发引脚
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  
  // 读取回声引脚，返回的是声音的传播时间（单位：微秒）
  long duration = pulseIn(echoPin, HIGH);
  
  // 计算距离
  long distance = duration * 0.034 / 2; // 声速：340 m/s，除以2是因为声音是来回行程
  
  return distance;
}


void printWifiStatus() {
  // 打印设备IP地址
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);
  
  // 打印出与网络的连接质量
  long rssi = WiFi.RSSI();
  Serial.print("Signal strength (RSSI): ");
  Serial.print(rssi);
  Serial.println(" dBm");
  // ...其余的status打印代码...
}



void setup() {
  // 初始化串行通信
  Serial.begin(9600);
  
  // 设置触发引脚为输出模式，回声引脚为输入模式
  pinMode(trigPin1, OUTPUT);
  pinMode(echoPin1, INPUT);
  pinMode(trigPin2, OUTPUT);
  pinMode(echoPin2, INPUT);

  Serial.println("Attempting to connect to WPA SSID: ");
  while (status != WL_CONNECTED) {
    Serial.print("Attempting to connect to WPA SSID: ");
    status = WiFi.begin(ssid, pass);
    // 等待10秒连接尝试
    delay(10000);
    // 连接成功，打印IP地址
  Serial.print("You're connected to the network");
  printWifiStatus();

}
}

void loop() {
  // 获取从两个传感器读取的距离
  long distance1 = measureDistance(trigPin1, echoPin1);
  long distance2 = measureDistance(trigPin2, echoPin2);

  // 更新传感器活跃状态
  sensor1LastActive = sensor1Active;
  sensor2LastActive = sensor2Active;

  // 检查每个传感器是否检测到物体
  sensor1Active = (distance1 <= 100 && distance1 != 0);
  sensor2Active = (distance2 <= 100 && distance2 != 0);

  // 判断传感器是否激活并更新顺序
  if (sensor1Active && !sensor1LastActive) {
    if (lastSensorActivated == 2) {
      // 如果最后一个激活的是传感器2，然后是传感器1，人数减1
      peopleCount--;
      lastSensorActivated = 0; // 重置激活顺序
    } else {
      lastSensorActivated = 1;
    }
  }
  if (sensor2Active && !sensor2LastActive) {
    if (lastSensorActivated == 1) {
      // 如果最后一个激活的是传感器1，然后是传感器2，人数加1
      peopleCount++;
      lastSensorActivated = 0; // 重置激活顺序
    } else {
      lastSensorActivated = 2;
    }
  }

  // 当两个传感器都不活跃时，重置状态，防止重复计数
  if (!sensor1Active && !sensor2Active) {
    lastSensorActivated = 0;
  }

  // 保证人数不小于0
  if (peopleCount < 0) {
    peopleCount = 0;
  }

  // 打印当前人数
  Serial.print("Current people count: ");
  Serial.println(peopleCount);
  
  // 等待50毫秒
  delay(50);

  static int lastPeopleCount = -1; // 用来存储上一次的人数
  if (peopleCount != lastPeopleCount) {
    // 创建JSON对象
    String jsonObject = "{\"people_count\":" + String(peopleCount) + "}";
    
    // 发送HTTP POST请求到云函数
    client.beginRequest();
    client.post("http://europe-west2-discount-manager-f6248.cloudfunctions.net/update_people"); // 确保替换为你的云函数的实际路径
    client.sendHeader(HTTP_HEADER_CONTENT_TYPE, "application/json");
    client.sendHeader(HTTP_HEADER_CONTENT_LENGTH, jsonObject.length());
    client.beginBody();
    client.print(jsonObject);
    client.endRequest();
    
    // 读取响应
    int statusCode = client.responseStatusCode();
    String response = client.responseBody();
    
    Serial.print("Status code: ");
    Serial.println(statusCode);
    Serial.print("Response: ");
    Serial.println(response);
    
    lastPeopleCount = peopleCount; // 更新人数
  }
}



