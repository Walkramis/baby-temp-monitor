import SwiftUI
struct Line: Shape {
    var start, end: CGPoint

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
    }
}
extension Line {
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set { (start.animatableData, end.animatableData) = (newValue.first, newValue.second) }
    }
}
let p1 = CGPoint(x: 50, y: 50)
let p2 = CGPoint(x: 100, y: 25)
let p3 = CGPoint(x: 100, y: 100)


struct ContentView: View {
    
    @State var signInSuccess = false
    @ObservedObject var bleManager = BLEManager()

    var body: some View {
        return Group {
            if signInSuccess {
                AppHome(bleManager: bleManager)
            }
            else {
                ContentView_asd(bleManager: bleManager, signInSuccess: $signInSuccess)
            }
        }
    }
}
struct ContentView_asd: View {
    //@Binding var bleManager: BLEManager
    @ObservedObject var bleManager: BLEManager
    //@ObservedObject var bleManager = BLEManager()

    @State private var percentage: CGFloat = .zero
    @State var toggle = true
    @State private var opacity = 1.0
    @State var line = Line(start: p1,end: p2)
    @Binding var signInSuccess: Bool

    var body: some View {
        VStack (spacing: 10) {

            Path() { p in
                for i in 0..<bleManager.entries.count {
                    if (i == 0){
                        p.move(to: CGPoint(x: bleManager.entries[i].x, y: bleManager.entries[i].y))
                    }
                    else{
                        p.addLine(to: CGPoint(x: bleManager.entries[i].x, y:bleManager.entries[i].y))
                    }
                }
            }.trim(from: 0, to: percentage) // << breaks path by parts, animatable
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {self.percentage = 1.0} // <<
            }
            .onReceive(bleManager.$entries, perform: { _ in
                self.percentage = .zero                // >> stops current
                withAnimation(.easeOut(duration: 1.0)) {self.percentage = 1.0} // <<
            })

            Text("Bluetooth Devices")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)
            List() {
                List(bleManager.peripherals) { peripheral in
                    HStack {
                        Button(action:{
                                bleManager.myCentral.connect(peripheral.peripheral)
                                print("Connecting")}){
                        Text(peripheral.name)
                        Spacer()
                        Text(String(peripheral.rssi))
                        }
                    }
                }.frame(height: 300)
            }.frame(height: 300)

            Spacer()

            Text("STATUS")
                .font(.headline)

            // Status goes here
            if bleManager.isSwitchedOn {
                Text("Bluetooth is switched on")
                    .foregroundColor(.green)
            }
            else {
                Text("Bluetooth is NOT switched on")
                    .foregroundColor(.red)
            }
            Spacer()

            HStack {
                VStack (spacing: 10) {
                    Button(action: {
                        bleManager.startScanning()                    }) {
                        Text("Start Scanning")
                    }
                    Button(action: {
                        bleManager.stopScanning()                    }) {
                        Text("Stop Scanning")
                    }
                }.padding()

                Spacer()

                VStack (spacing: 10) {
                    Button(action: {
                        print("Start Advertising")
                        self.signInSuccess = true

                    }) {
                        Text("Start Advertising")
                    }
                    Button(action: {
                        print("Stop Advertising")
                        bleManager.temperatures.insert(CGFloat(Int.random(in: 15...25)), at: 0)
                        if (bleManager.temperatures.count >= 10){
                            bleManager.temperatures.removeLast()
                        }
//                        bleManager.temperatures.append(CGFloat(Int.random(in: 15...25)))
                        bleManager.doCalculatePositions()
                    }) {
                        Text("Stop Advertising")
                    }
                }.padding()
            }
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct AppHome: View {
    @ObservedObject var bleManager: BLEManager
    @State private var percentage: CGFloat = .zero

    var body: some View {
        VStack {
            Path() { p in
                for i in 0..<bleManager.entries.count {
                    if (i == 0){
                        p.move(to: CGPoint(x: bleManager.entries[i].x, y: bleManager.entries[i].y))
                    }
                    else{
                        p.addLine(to: CGPoint(x: bleManager.entries[i].x, y:bleManager.entries[i].y))
                    }
                }
            }.trim(from: 0, to: percentage) // << breaks path by parts, animatable
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {self.percentage = 1.0} // <<
            }
            .onReceive(bleManager.$entries, perform: { _ in
                self.percentage = .zero                // >> stops current
                withAnimation(.easeOut(duration: 1.0)) {self.percentage = 1.0} // <<
            })
        Text("Hello freaky world!")
        Text("You are signed in.")
        Button(action: {
                print("Stop Advertising")
                bleManager.temperatures.insert(CGFloat(Int.random(in: 15...25)), at: 0)
                if (bleManager.temperatures.count >= 10){
                    bleManager.temperatures.removeLast()
                }
                bleManager.doCalculatePositions()
            }) {
                Text("Stop Advertising")
            }
        }
    }
}
