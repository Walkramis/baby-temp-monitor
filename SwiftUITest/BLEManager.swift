import Foundation
import CoreBluetooth
import SwiftUI

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    let uuidCharForIndicate = CBUUID(string: "25AE1444-05D3-4C5B-8281-93D4E07420CF")
    let uuidService = CBUUID(string: "25AE1441-05D3-4C5B-8281-93D4E07420CF")
    var selectedPeripheral: CBPeripheral!

    var myCentral: CBCentralManager!
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        selectedPeripheral = peripheral
        selectedPeripheral.delegate = self
        myCentral.stopScan()
        myCentral.connect(selectedPeripheral)
//        var peripheralName: String!
//
//        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
//            peripheralName = name
//        }
//        else {
//            return
//            //peripheralName = "Unknown"
//        }
//
//        let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, peripheral: peripheral)
//        print(newPeripheral)
//        newPeripheral.peripheral.delegate = self
//        peripherals.append(newPeripheral)
    
    }
    @Published var peripherals = [Peripheral]()
    @Published var isSwitchedOn = false
    @Published var entries: [CGPoint] = []// = [CGPoint(x: 10, y: 50)]
    @Published var currentTemperature: String = "No temp yet"
    var temperatures:[CGFloat] = []// = [15,18,16]
    @Published var min:CGFloat = 12
    @Published var max:CGFloat = 20
    @Published var range:CGFloat = 8
    @Published var isConnected:Bool = false
    var yRange:CGFloat = 200
    let screenSize: CGRect = UIScreen.main.bounds
    
    override init() {
        super.init()

        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
//        entries.append(CGPoint(x: 20, y: 60))
//        entries.append(CGPoint(x: 30, y: 80))
        range = max - min
    }
    func doCalculatePositions(){
        max = temperatures.max()! + 1
        min = temperatures.min()! - 1
        range = max - min
        calculatePositions(temperatures: temperatures, max: max, min: min)
    }
    func calculatePositions(temperatures:[CGFloat], max:CGFloat, min:CGFloat) -> [CGPoint]{
        var positions:[CGPoint] = []
        let xIncrement:CGFloat = (screenSize.width-45-10)/9

        for (index, temp) in temperatures.enumerated(){
            let normTemp = (1-(temp - min)/(max-min))*yRange
            positions.append(CGPoint(x: (screenSize.width - CGFloat(index)*xIncrement-10),y: normTemp))
        }
        entries = positions
        return positions
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
            startScanning()
        }
        else {
            isSwitchedOn = false
        }
    }
    func startScanning() {
         print("startScanning")
         myCentral.scanForPeripherals(withServices: [uuidService], options: nil)
     }
    func stopScanning() {
        print("stopScanning")
        myCentral.stopScan()
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to ")
        print(peripheral.name)
        selectedPeripheral.discoverServices(nil)
        myCentral.stopScan()
        isConnected = true
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected!")
        isConnected = false
        myCentral.scanForPeripherals(withServices: [uuidService])

    }
}
extension BLEManager: CBPeripheralDelegate{
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {return}
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print(characteristic)
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
                print("\(characteristic.uuid): properties contains .notify")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case uuidCharForIndicate:
            let data = characteristic.value ?? Data()
            let stringValue = String(data: data, encoding: .utf8) ?? ""
            print(stringValue)
            currentTemperature = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let n = CGFloat((stringValue as NSString).floatValue)
            temperatures.insert(n, at:0)
            if (temperatures.count > 10){
                temperatures.removeLast()
            }
            doCalculatePositions()
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
}
