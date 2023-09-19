/*
 * BLEProofPeripheral.cpp
 *
 * Created by Alexander Lavrushko on 22/03/2021.
 *
 * @brief BLEProof Peripheral ESP32
 * Bluetooth Low Energy Peripheral (also called Slave, Server) demo application for ESP32
 * 1. Advertises one service with 3 characteristics:
 *    - characteristic which supports read (BLE Central can only read)
 *    - characteristic which supports write (BLE Central can only write, with response)
 *    - characteristic which supports indication (BLE Central can only subscribe and listen for indications)
 * 2. Provides command line interface for changing values of characteristics:
 *    - use Arduino Serial Monitor with 115200 baud, and option 'Newline' or 'Carriage return' or 'Both'
 */

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// --------
// Constants
// --------
#define SERVICE_UUID        "25AE1441-05D3-4C5B-8281-93D4E07420CF"
#define CHAR_READ_UUID      "25AE1442-05D3-4C5B-8281-93D4E07420CF"
#define CHAR_WRITE_UUID     "25AE1443-05D3-4C5B-8281-93D4E07420CF"
#define CHAR_INDICATE_UUID  "25AE1444-05D3-4C5B-8281-93D4E07420CF"

#define CMD_HELP "help"
#define CMD_INFO "info"
#define CMD_SET_READ "setr="
#define CMD_SET_INDICATE "seti="

// --------
// Global variables
// --------
static BLEServer* g_pServer = nullptr;
static BLECharacteristic* g_pCharRead = nullptr;
static BLECharacteristic* g_pCharWrite = nullptr;
static BLECharacteristic* g_pCharIndicate = nullptr;
static bool g_centralConnected = false;
static std::string g_cmdLine;


// --------
// Temperature variables
// --------
#include <OneWire.h>
#include <DallasTemperature.h>

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 2

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

// arrays to hold device address
DeviceAddress insideThermometer;



// --------
// Bluetooth event callbacks
// --------
class MyServerCallbacks: public BLEServerCallbacks
{
    void onConnect(BLEServer* pServer) override
    {
        Serial.println("onConnect");
        g_centralConnected = true;
    }

    void onDisconnect(BLEServer* pServer) override
    {
        Serial.println("onDisconnect, will start advertising");
        g_centralConnected = false;
        BLEDevice::startAdvertising();
    }
};

class MyCharPrintingCallbacks: public BLECharacteristicCallbacks
{
public:
    explicit MyCharPrintingCallbacks(const char* name) : m_name(name) {}

private:
    void PrintEvent(const char* event, const char* value)
    {
        Serial.print(event);
        Serial.print("(");
        Serial.print(m_name.c_str());
        Serial.print(")");
        if (value)
        {
            Serial.print(" value='");
            Serial.print(value);
            Serial.print("'");
        }
        Serial.println();
    }

private:
    void onRead(BLECharacteristic* pCharacteristic) override
    {
        PrintEvent("onRead", pCharacteristic->getValue().c_str());
    }

    void onWrite(BLECharacteristic* pCharacteristic) override
    {
        PrintEvent("onWrite", pCharacteristic->getValue().c_str());
    }

    void onNotify(BLECharacteristic* pCharacteristic) override
    {
        PrintEvent("onNotify", pCharacteristic->getValue().c_str());
    }

    void onStatus(BLECharacteristic* pCharacteristic, Status status, uint32_t code) override
    {
        std::string event("onStatus:");
        switch (status)
        {
        case SUCCESS_INDICATE: event += "SUCCESS_INDICATE"; break;
        case SUCCESS_NOTIFY: event += "SUCCESS_NOTIFY"; break;
        case ERROR_INDICATE_DISABLED: event += "ERROR_INDICATE_DISABLED"; break;
        case ERROR_NOTIFY_DISABLED: event += "ERROR_NOTIFY_DISABLED"; break;
        case ERROR_GATT: event += "ERROR_GATT"; break;
        case ERROR_NO_CLIENT: event += "ERROR_NO_CLIENT"; break;
        case ERROR_INDICATE_TIMEOUT: event += "ERROR_INDICATE_TIMEOUT"; break;
        case ERROR_INDICATE_FAILURE: event += "ERROR_INDICATE_FAILURE"; break;
        }
        event += ":";
        event += String(code).c_str();
        PrintEvent(event.c_str(), nullptr);
    }

private:
    std::string m_name;
};




// function to print the temperature for a device
void printTemperature(DeviceAddress deviceAddress)
{
  // method 1 - slower
  //Serial.print("Temp C: ");
  //Serial.print(sensors.getTempC(deviceAddress));
  //Serial.print(" Temp F: ");
  //Serial.print(sensors.getTempF(deviceAddress)); // Makes a second call to getTempC and then converts to Fahrenheit

  // method 2 - faster
  float tempC = sensors.getTempC(deviceAddress);
  Serial.print("Temp C: ");
  Serial.print(tempC);
  Serial.print(" Temp F: ");
  Serial.println(DallasTemperature::toFahrenheit(tempC)); // Converts tempC to Fahrenheit
}

// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}
// --------
// Application lifecycle: setup & loop
// --------
void setup()
{
    Serial.begin(115200);
    Serial.println("BLE Peripheral setup started");

    BLEDevice::init("ESP32");
    g_pServer = BLEDevice::createServer();
    g_pServer->setCallbacks(new MyServerCallbacks());
    BLEService* pService = g_pServer->createService(SERVICE_UUID);

    // characteristic for read
    {
        uint32_t propertyFlags = BLECharacteristic::PROPERTY_READ;
        BLECharacteristic* pCharRead = pService->createCharacteristic(CHAR_READ_UUID, propertyFlags);
        pCharRead->setCallbacks(new MyCharPrintingCallbacks("CharRead"));
        pCharRead->setValue("ESP32 for read");
        g_pCharRead = pCharRead;
    }

    // characteristic for write
    {
        uint32_t propertyFlags = BLECharacteristic::PROPERTY_WRITE;
        BLECharacteristic* pCharWrite = pService->createCharacteristic(CHAR_WRITE_UUID, propertyFlags);
        pCharWrite->setCallbacks(new MyCharPrintingCallbacks("CharWrite"));
        pCharWrite->setValue("");
        g_pCharWrite = pCharWrite;
    }

    // characteristic for indicate
    {
        uint32_t propertyFlags = BLECharacteristic::PROPERTY_NOTIFY;
        BLECharacteristic* pCharIndicate = pService->createCharacteristic(CHAR_INDICATE_UUID, propertyFlags);
        pCharIndicate->setCallbacks(new MyCharPrintingCallbacks("CharIndicate"));
        pCharIndicate->addDescriptor(new BLE2902());
        pCharIndicate->setValue("");
        g_pCharIndicate = pCharIndicate;
    }

    pService->start();
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    // this fixes iPhone connection issue (don't know how it works)
    {
        pAdvertising->setMinPreferred(0x06);
        pAdvertising->setMinPreferred(0x12);
    }
    BLEDevice::startAdvertising();

    Serial.println("BLE Peripheral setup done, advertising");
    Serial.println("");
    PrintInfo();
    PrintHelp();

    // Temperature intitialization
    Serial.println("Dallas Temperature IC Control Library Demo");

    // locate devices on the bus
    Serial.print("Locating devices...");
    sensors.begin();
    Serial.print("Found ");
    Serial.print(sensors.getDeviceCount(), DEC);
    Serial.println(" devices.");
  
    // report parasite power requirements
    Serial.print("Parasite power is: "); 
    if (sensors.isParasitePowerMode()) Serial.println("ON");
    else Serial.println("OFF");

    if (!sensors.getAddress(insideThermometer, 0)) Serial.println("Unable to find address for Device 0"); 
    // show the addresses we found on the bus
    Serial.print("Device 0 Address: ");
    printAddress(insideThermometer);
    Serial.println();
  
    // set the resolution to 9 bit (Each Dallas/Maxim device is capable of several different resolutions)
    sensors.setResolution(insideThermometer, 9);
   
    Serial.print("Device 0 Resolution: ");
    Serial.print(sensors.getResolution(insideThermometer), DEC); 
    Serial.println();
}

void loop()
{
//    if (!Serial.available())
//    {
//        return;
//    }
//
//    char c = Serial.read();
//    if (c != '\r' && c != '\n')
//    {
//        g_cmdLine += c;
//        return;
//    }
//
//    std::string cmdLine;
//    std::swap(g_cmdLine, cmdLine);
//    if (cmdLine.empty())
//    {
//        return; 
//    }
//
//    std::string commandData;
//    if (ParseCommand(cmdLine, CMD_HELP, commandData))
//    {
//        PrintHelp();
//        return;
//    }
//
//    if (ParseCommand(cmdLine, CMD_INFO, commandData))
//    {
//        PrintInfo();
//        return;
//    }
//
//    if (ParseCommand(cmdLine, CMD_SET_READ, commandData))
//    {
//        Serial.print("Setting read characteristic: '");
//        Serial.print(commandData.c_str());
//        Serial.println("'");
//        g_pCharRead->setValue(commandData);
//        return;
//    }
//
//    if (ParseCommand(cmdLine, CMD_SET_INDICATE, commandData))
//    {
//        Serial.print("Setting indicate characteristic: '");
//        Serial.print(commandData.c_str());
//        Serial.println("'");
//        g_pCharIndicate->setValue(commandData);
//        g_pCharIndicate->indicate();
//        return;
//    }
//    else
//    {
//      // call sensors.requestTemperatures() to issue a global temperature 
//      // request to all devices on the bus
//      Serial.print("Requesting temperatures...");
//      sensors.requestTemperatures(); // Send the command to get temperatures
//      Serial.println("DONE");
//      
//      // It responds almost immediately. Let's print out the data
//      printTemperature(insideThermometer); // Use a simple function to print out the data
//      float tempC = sensors.getTempC(insideThermometer);
//      char result[8]; // Buffer big enough for 7-character float
//      dtostrf(tempC, 6, 2, result); // Leave room for too large numbers!
//      g_pCharIndicate->setValue(result);
//      g_pCharIndicate->indicate();
//    }
//
//    Serial.print("ERROR: command not recognized: '");
//    Serial.print(cmdLine.c_str());
//    Serial.println("'");

      Serial.print("Requesting temperatures...");
      sensors.requestTemperatures(); // Send the command to get temperatures
      Serial.println("DONE");
      
      // It responds almost immediately. Let's print out the data
      printTemperature(insideThermometer); // Use a simple function to print out the data
      float tempC = sensors.getTempC(insideThermometer);
      char result[8]; // Buffer big enough for 7-character float
      dtostrf(tempC, 6, 2, result); // Leave room for too large numbers!
      g_pCharIndicate->setValue(result);
      g_pCharIndicate->notify();
      delay(10000);

}

// --------
// Helper functions
// --------
bool ParseCommand(const std::string& cmdLine, const std::string& commandKeyword, std::string& outputCommandData)
{
    size_t commandPosition = cmdLine.find(commandKeyword);
    if (commandPosition == std::string::npos)
    {
        return false;
    }
    outputCommandData = cmdLine.substr(commandPosition + commandKeyword.length());
    return true;
}

void PrintInfo()
{
    Serial.println("-------------------------------");
    Serial.println("  Service UUID: "SERVICE_UUID);
    Serial.println(g_centralConnected ? "  Central connected" : "  Central not connected");
    Serial.println("  Characteristics:");

    Serial.print("  Readable: value='");
    Serial.print(g_pCharRead->getValue().c_str());
    Serial.println("' UUID="CHAR_READ_UUID);

    Serial.print("  Writeable: value='");
    Serial.print(g_pCharWrite->getValue().c_str());
    Serial.println("' UUID="CHAR_WRITE_UUID);

    Serial.print("  Indication: value='");
    Serial.print(g_pCharIndicate->getValue().c_str());
    Serial.println("' UUID="CHAR_INDICATE_UUID);
    Serial.println("-------------------------------");
}

void PrintHelp()
{
    Serial.println("-------------------------------");
    Serial.println("  Command line interface:");
    Serial.println("  1. "CMD_HELP" - print this description of command line interface");
    Serial.println("  2. "CMD_INFO" - print current state of BLE Peripheral");
    Serial.println("  3. "CMD_SET_READ"<value> - set value to readable characteristic");
    Serial.println("       Set 'abc def': "CMD_SET_READ"abc def");
    Serial.println("       Set empty value: "CMD_SET_READ);
    Serial.println("  4. "CMD_SET_INDICATE"<value> - set value to indication characteristic, and send indication to Central");
    Serial.println("       Set 'abc def': "CMD_SET_INDICATE"abc def");
    Serial.println("       Set empty value: "CMD_SET_INDICATE);
    Serial.println("-------------------------------");
    Serial.println("Waiting for command line input...");
}
