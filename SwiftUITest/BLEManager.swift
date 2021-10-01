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

    var myCentral: CBCentralManager!
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
       
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
        }
        else {
            return
            //peripheralName = "Unknown"
        }
        
        let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, peripheral: peripheral)
        print(newPeripheral)
        newPeripheral.peripheral.delegate = self
        peripherals.append(newPeripheral)
    
    }
    @Published var peripherals = [Peripheral]()
    @Published var isSwitchedOn = false
    @Published var entries: [CGPoint] = [CGPoint(x: 10, y: 50)]
    var temperatures:[CGFloat] = [15,18,16]
    var min:CGFloat = 12
    var max:CGFloat = 20
    var yRange:CGFloat = 200
    let screenSize: CGRect = UIScreen.main.bounds
    
    override init() {
        super.init()

        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
        entries.append(CGPoint(x: 20, y: 60))
        entries.append(CGPoint(x: 30, y: 80))
    }
    func doCalculatePositions(){
        max = temperatures.max()! + 2
        min = temperatures.min()! - 2
        calculatePositions(temperatures: temperatures, max: max, min: min)
    }
    func calculatePositions(temperatures:[CGFloat], max:CGFloat, min:CGFloat) -> [CGPoint]{
        var positions:[CGPoint] = []
        let xIncrement:CGFloat = screenSize.width/10

        for (index, temp) in temperatures.enumerated(){
            let normTemp = (1-(temp - min)/(max-min))*yRange
            positions.append(CGPoint(x: (screenSize.width - CGFloat(index)*xIncrement),y: normTemp))
        }
        entries = positions
        return positions
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        }
        else {
            isSwitchedOn = false
        }
    }
    func startScanning() {
         print("startScanning")
         myCentral.scanForPeripherals(withServices: nil, options: nil)
     }
    func stopScanning() {
        print("stopScanning")
        myCentral.stopScan()
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to ")
        print(peripheral.name)
        peripheral.discoverServices(nil)
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
    
    
    
}
