/*******************************************************************************
 * Copyright (c) 2021  Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Collections
import CoreData
import SwiftUI
import Foundation
import CoreBluetooth
import CoreLocation
import UserNotifications
import Combine
import os.log
import HLPDialog

enum GrantState {
    case Init
    case Granted
    case Denied
    case Off
}

enum DisplayedScene {
    case Onboard
    case ResourceSelect
    case App

    var text: Text {
        get {
            switch self {
            case .Onboard:
                return Text("")
            case .ResourceSelect:
                return Text("Select Resource")
            case .App:
                return Text("Main Menu")
            }
        }
    }
}

class wrapper_transportservice: CaBotTransportProtocol{
    
    var services:[CaBotTransportProtocol] = []
    
    func add_service(service:CaBotTransportProtocol){
        self.services.append(service)
    }
    func set_service(service:CaBotTransportProtocol){
        self.services.removeAll()
        self.add_service(service:service)
    }
    
    func activityLog(category: String, text: String, memo: String) -> Bool {
        for service in self.services{
            if(!service.activityLog(category: category, text: text, memo: memo)){
                return false
            }
        }
        return true
    }
    
    func send(destination: String) -> Bool {
        for service in self.services{
            if(!service.send(destination:destination)){
                return false
            }
        }
        return true
    }
    
    func summon(destination: String) -> Bool {
        for service in self.services{
            if(!service.summon(destination:destination)){
                return false
            }
        }
        return true
    }
    
    func find(person: String) -> Bool {
        for service in self.services{
            if(!service.find(person:person)){
                return false
            }
        }
        return true
    }
    
    func manage(command: CaBotManageCommand) -> Bool {
        for service in self.services{
            if(!service.manage(command:command)){
                return false
            }
        }
        return true
    }
    
    func startAdvertising() {
        for service in self.services{
            service.startAdvertising()
        }
    }
    
    func stopAdvertising() {
        for service in self.services{
            service.stopAdvertising()
        }
    }
    
    func notifyDeviceStatus(status: DeviceStatus) {
        for service in self.services{
            service.notifyDeviceStatus(status:status)
        }
    }
    
    func notifySystemStatus(status: SystemStatus) {
        for service in self.services{
            service.notifySystemStatus(status:status)
        }
    }
    
    func notifyBatteryStatus(status: BatteryStatus) {
        for service in self.services{
            service.notifyBatteryStatus(status:status)
        }
    }
}


final class CaBotAppModel: NSObject, ObservableObject, CaBotServiceDelegateBlueTooth, TourManagerDelegate, CLLocationManagerDelegate, CaBotTTSDelegate {
    
    private let selectedResourceKey = "SelectedResourceKey"
    private let selectedVoiceKey = "SelectedVoiceKey"
    private let speechRateKey = "speechRateKey"
    private let connectionTypeKey = "connection_type"
    private let teamIDKey = "team_id"
    private let socketAddrKey = "socket_url"
    private let menuDebugKey = "menu_debug"
    private let noSuitcaseDebugKey = "noSuitcaseDebugKey"
    private let adminModeKey = "adminModeKey"
    private let startSoundKey = "startSoundKey"
    private let arrivedSoundKey = "arrivedSoundKey"
    private let speedUpSoundKey = "speedUpSoundKey"
    private let speedDownSoundKey = "speedDownSoundKey"
    private let browserCloseDelayKey = "browserCloseDelayKey"
    

    @Published var versionMatched: Bool = false
    @Published var serverBLEVersion: String? = nil

    @Published var locationState: GrantState = .Init {
        didSet {
            self.checkOnboardCondition()
        }
    }
    @Published var bluetoothState: CBManagerState = .unknown {
        didSet {
            self.checkOnboardCondition()
        }
    }
    @Published var notificationState: GrantState = .Init {
        didSet {
            self.checkOnboardCondition()
        }
    }
    func checkOnboardCondition() {
        if self.bluetoothState == .poweredOn &&
            self.notificationState != .Init &&
            self.locationState != .Init
            {
            if authRequestedByUser {
                withAnimation() {
                    self.displayedScene = .ResourceSelect
                }
            } else {
                self.displayedScene = .ResourceSelect
            }
        }
        if self.displayedScene == .ResourceSelect {
            guard let value = UserDefaults.standard.value(forKey: ResourceSelectView.resourceSelectedKey) as? Bool else { return }
            if value {
                displayedScene = .App
            }
        }
    }
    @Published var displayedScene: DisplayedScene = .Onboard
    var authRequestedByUser: Bool = false

    @Published var resource: Resource? = nil {
        didSet {
            if let resource = resource {

                let key = "\(selectedVoiceKey)_\(resource.locale.identifier)"
                if let id = UserDefaults.standard.value(forKey: key) as? String {
                    self.voice = TTSHelper.getVoice(by: id)
                } else {
                    self.voice = TTSHelper.getVoices(by: resource.locale)[0]
                }
            }

            UserDefaults.standard.setValue(resource?.name, forKey: selectedResourceKey)
            UserDefaults.standard.synchronize()
        }
    }

    @Published var voice: Voice? = nil {
        didSet {
            if let id = voice?.AVvoice.identifier {
                let key = "\(selectedVoiceKey)_\(resource?.locale.identifier ?? "en-US")"
                UserDefaults.standard.setValue(id, forKey: key)
                UserDefaults.standard.synchronize()

                if let voice = self.voice {
                    self.tts.voice = voice.AVvoice
                }
            }
        }
    }
    @Published var speechRate: Double = 0.5 {
        didSet {
            UserDefaults.standard.setValue(speechRate, forKey: speechRateKey)
            UserDefaults.standard.synchronize()
            self.tts.rate = speechRate
        }
    }

    @Published var suitcaseConnected: Bool = false {
        didSet {
            if !self.suitcaseConnected {
                self.deviceStatus = DeviceStatus()
                self.systemStatus.clear()
                self.batteryStatus = BatteryStatus()
            }
        }
    }
    @Published var backpackConnected: Bool = false

    private func stop_ble(){
        self.bleService.stop()
    }
    private func start_ble(){
        if !self.teamID.isEmpty{
            self.bleService.teamID = self.teamID
            self.bleService.start()
            self.wrpService.set_service(service: self.bleService)
        }
    }
    private func stop_tcp(){
        self.tcpService.stop()
    }
    private func start_tcp(){
        if !self.socketAddr.isEmpty{
            self.tcpService.set_addr(addr: socketAddr)
            self.tcpService.start()
            self.wrpService.set_service(service: self.tcpService)
        }
    }
    enum conntype:String, CaseIterable{
        case ble = "ble"
        case tcp = "tcp"
    }
    @Published var connectionType:conntype = .ble{
        didSet{
            UserDefaults.standard.setValue(connectionType.rawValue, forKey: connectionTypeKey)
            UserDefaults.standard.synchronize()
            stop_ble()
            stop_tcp()
            switch self.connectionType{
            case .ble:
                self.start_ble()
            case .tcp:
                self.start_tcp()
            }
        }
    }
    @Published var teamID: String = "" {
        didSet {
            UserDefaults.standard.setValue(teamID, forKey: teamIDKey)
            UserDefaults.standard.synchronize()
            if self.connectionType == .ble{
                self.stop_ble()
                self.start_ble()
            }
        }
    }
    
    @Published var socketAddr: String = "172.20.10.7:5000" {
        didSet {
            UserDefaults.standard.setValue(socketAddr, forKey: socketAddrKey)
            UserDefaults.standard.synchronize()
            if self.connectionType == .tcp{
                self.stop_tcp()
                self.start_tcp()
            }
        }
    }
    @Published var menuDebug: Bool = false {
        didSet {
            UserDefaults.standard.setValue(menuDebug, forKey: menuDebugKey)
            UserDefaults.standard.synchronize()
        }
    }
    @Published var noSuitcaseDebug: Bool = false {
        didSet {
            UserDefaults.standard.setValue(noSuitcaseDebug, forKey: noSuitcaseDebugKey)
            UserDefaults.standard.synchronize()
            suitcaseConnected = true
        }
    }
    @Published var adminMode: Bool = true {
        didSet {
            UserDefaults.standard.setValue(noSuitcaseDebug, forKey: adminModeKey)
            UserDefaults.standard.synchronize()
        }
    }
    @Published var browserCloseDelay: Double = 1.2 {
        didSet {
            UserDefaults.standard.setValue(browserCloseDelay, forKey: browserCloseDelayKey)
            UserDefaults.standard.synchronize()
        }
    }

    @Published var isContentPresenting: Bool = false
    @Published var isConfirmingSummons: Bool = false
    @Published var contentURL: URL? = nil
    @Published var tourUpdated: Bool = false

    @Published var startSound: String = "/System/Library/Audio/UISounds/nano/3rdParty_Success_Haptic.caf" {
        didSet {
            UserDefaults.standard.setValue(startSound, forKey: startSoundKey)
            UserDefaults.standard.synchronize()
        }
    }
    @Published var arrivedSound: String = "/System/Library/Audio/UISounds/nano/HummingbirdNotification_Haptic.caf" {
        didSet {
            UserDefaults.standard.setValue(arrivedSound, forKey: arrivedSoundKey)
            UserDefaults.standard.synchronize()
        }
    }
    @Published var speedUpSound: String = "/System/Library/Audio/UISounds/nano/WalkieTalkieActiveStart_Haptic.caf" {
        didSet {
            UserDefaults.standard.setValue(speedUpSound, forKey: speedUpSoundKey)
            UserDefaults.standard.synchronize()
        }
    }
    @Published var speedDownSound: String = "/System/Library/Audio/UISounds/nano/ET_RemoteTap_Receive_Haptic.caf" {
        didSet {
            UserDefaults.standard.setValue(speedDownSound, forKey: speedDownSoundKey)
            UserDefaults.standard.synchronize()
        }
    }

    @Published var deviceStatus: DeviceStatus = DeviceStatus()
    @Published var systemStatus: SystemStatusData = SystemStatusData()
    @Published var batteryStatus: BatteryStatus = BatteryStatus()

    private var wrpService: wrapper_transportservice
    private var bleService: CaBotService
    private var tcpService: CaBotServiceTCP
    private let tts: CaBotTTS
    let preview: Bool
    let resourceManager: ResourceManager
    let tourManager: TourManager
    let dialogViewHelper: DialogViewHelper
    let notificationCenter: UNUserNotificationCenter

    let locationManager: CLLocationManager
    let locationUpdateTimeLimit: CFAbsoluteTime = 60*15
    var locationUpdateStartTime: CFAbsoluteTime = 0
    var audioAvailableEstimate: Bool = false
    var audioPlayer: AVAudioPlayer = AVAudioPlayer()

    convenience override init() {
        self.init(preview: true)
    }

    init(preview: Bool) {
        self.preview = preview
        self.tts = CaBotTTS(voice: nil)
        self.bleService = CaBotService(with: self.tts)
        self.tcpService = CaBotServiceTCP(with: self.tts)
        self.wrpService = wrapper_transportservice()
        self.resourceManager = ResourceManager(preview: preview)
        self.tourManager = TourManager()
        self.dialogViewHelper = DialogViewHelper()
        self.locationManager =  CLLocationManager()
        self.notificationCenter = UNUserNotificationCenter.current()
        super.init()

        self.tts.delegate = self
        self.bleService.delegate = self
        self.tcpService.delegate = self
        
        if let selectedName = UserDefaults.standard.value(forKey: selectedResourceKey) as? String {
            self.resource = resourceManager.resource(by: selectedName)
        }
        if let conntypestr = UserDefaults.standard.value(forKey: connectionTypeKey) as? String, let connectionType = conntype(rawValue: conntypestr){
            self.connectionType = connectionType
        }
        if let groupID = UserDefaults.standard.value(forKey: teamIDKey) as? String {
            self.teamID = groupID
        }
        if let socketUrl = UserDefaults.standard.value(forKey: socketAddrKey) as? String{
            self.socketAddr = socketUrl
        }
        if let menuDebug = UserDefaults.standard.value(forKey: menuDebugKey) as? Bool {
            self.menuDebug = menuDebug
        }
        if let speechRate = UserDefaults.standard.value(forKey: speechRateKey) as? Double {
            self.speechRate = speechRate
        }
        if let arrivedSound = UserDefaults.standard.value(forKey: arrivedSoundKey) as? String {
            self.arrivedSound = arrivedSound
        }
        if let browserCloseDelay = UserDefaults.standard.value(forKey: browserCloseDelayKey) as? Double {
            self.browserCloseDelay = browserCloseDelay
        }

        // services
        self.locationManager.delegate = self
        self.locationManagerDidChangeAuthorization(self.locationManager)
        
        self.bleService.prepareIfAuthorized()//startIfAuthorized()

        self.notificationCenter.getNotificationSettings { settings in
            if settings.alertSetting == .enabled &&
                settings.soundSetting == .enabled {
                self.notificationState = .Granted
            }
            self.checkOnboardCondition()
        }

        // tour manager
        self.tourManager.delegate = self
    }

    func onChange(of newScenePhase: ScenePhase) {
        switch newScenePhase {
        case .background:
            resetAudioSession()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
            break
        case .inactive:
            break
        case .active:
            audioAvailableEstimate = true
            self.initNotification()
            self.resetAudioSession()
            locationManager.stopUpdatingLocation()
            break
        @unknown default:
            break
        }
    }

    func initNotification() {
        let generalCategory = UNNotificationCategory(identifier: "GENERAL",
                                                     actions: [],
                                                     intentIdentifiers: [],
                                                     options: [.allowAnnouncement])
        notificationCenter.setNotificationCategories([generalCategory])
    }

    // MARK: onboading

    func requestLocationAuthorization() {
        self.authRequestedByUser = true
        self.locationManager.requestAlwaysAuthorization()
    }

    func requestBluetoothAuthorization() {
        self.authRequestedByUser = true
        self.bleService.prepare()//start()
        //self.bleService.startAdvertising()
    }

    func requestNotificationAuthorization() {
        self.authRequestedByUser = true
        self.notificationCenter.requestAuthorization(options:[UNAuthorizationOptions.alert,
                                             UNAuthorizationOptions.sound]) {
            (granted, error) in
            DispatchQueue.main.async {
                self.notificationState = granted ? .Granted : .Denied
            }
        }
    }

    // MARK: CaBotTTSDelegate

    func activityLog(category: String, text: String, memo: String) {
        self.wrpService.activityLog(category: category, text: text, memo: memo)
    }

    // MARK: LocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch(manager.authorizationStatus) {
        case .notDetermined:
            locationState = .Init
        case .restricted:
            locationState = .Denied
        case .denied:
            locationState = .Denied
        case .authorizedAlways:
            locationState = .Granted
        case .authorizedWhenInUse:
            locationState = .Denied
        @unknown default:
            locationState = .Off
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if suitcaseConnected {
            locationUpdateStartTime = 0
            return
        }

        if locationUpdateStartTime == 0 {
            locationUpdateStartTime = CFAbsoluteTimeGetCurrent()
        }
        if CFAbsoluteTimeGetCurrent() - locationUpdateStartTime > locationUpdateTimeLimit {
            NSLog("Location update time without Bluetooth connection exceeds the limit: %.2f/%.2f sec", CFAbsoluteTimeGetCurrent() - locationUpdateStartTime, locationUpdateTimeLimit)
            manager.stopUpdatingLocation()
            audioAvailableEstimate = false

        } else {
            NSLog("Location update time without Bluetooth connection: %.2f sec", CFAbsoluteTimeGetCurrent() - locationUpdateStartTime)
        }
    }



    // MARK: public functions

    func resetAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback,
                                         mode: .spokenAudio,
                                         options: [])
        } catch {
            NSLog("audioSession category weren't set because of an error. \(error)")
        }
        do {
            try audioSession.setActive(true, options: [])
        } catch {
            NSLog("audioSession cannot be set active. \(error)")
        }
    }

    func open(content: URL) {
        contentURL = content
        isContentPresenting = true
    }

    func summon(destination: String) -> Bool {
        DispatchQueue.main.async {
            print("Show modal waiting")
            NavUtil.showModalWaiting(withMessage: NSLocalizedString("processing...", comment: ""))
        }
        if self.wrpService.summon(destination: destination) || self.noSuitcaseDebug {
            self.speak(NSLocalizedString("Sending the command to the suitcase", comment: "")) {}
            DispatchQueue.main.async {
                print("hide modal waiting")
                NavUtil.hideModalWaiting()
            }
            return true
        } else {
            DispatchQueue.main.async {
                print("hide modal waiting")
                NavUtil.hideModalWaiting()
            }
            DispatchQueue.main.async {
                let message = NSLocalizedString("Suitcase may not be connected", comment: "")

                self.speak(message) {}
            }
            return false
        }
    }

    func speak(_ text:String, callback: @escaping () -> Void) {
        if (preview) {
            print("previewing speak - \(text)")
        } else {
            self.tts.speak(text, callback: callback)
        }
    }

    func stopSpeak() {
        self.tts.stop()
    }

    func playAudio(file: String) {
        DispatchQueue.main.async {
            let fileURL: URL = URL(fileURLWithPath: file)
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                self.audioPlayer.play()
            } catch {
                print("\(error)")
            }
        }
    }

    func needToStartAnnounce(wait: Bool) {
        let delay = wait ? self.browserCloseDelay : 0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.speak(NSLocalizedString("You can proceed by pressing the right button of the suitcase handle", comment: "")) {
            }
        }
    }

    func systemManageCommand(command: CaBotManageCommand) {
        if self.wrpService.manage(command: command) {
            switch(command) {
            case .poweroff, .reboot:
                deviceStatus.level = .Unknown
                systemStatus.level = .Unknown
                break
            case .start:
                systemStatus.level = .Activating
            case .stop:
                systemStatus.level = .Deactivating
                break
            }
            systemStatus.components.removeAll()
            objectWillChange.send()
        }
    }

    // MARK: TourManagerDelegate
    func tourUpdated(manager: TourManager) {
        tourUpdated = true
        UIApplication.shared.isIdleTimerDisabled = manager.hasDestination

    }

    func tour(manager: TourManager, destinationChanged destination: Destination?) {
        if let dest = destination {
            if let dest_id = dest.value {
                if !send(destination: dest_id) {
                    manager.cannotStartCurrent()
                } else {
                    // cancel all announcement
                    var delay = self.tts.isSpeaking ? 1.0 : 0

                    self.tts.stop(true)

                    if self.isContentPresenting {
                        self.isContentPresenting = false
                        delay = self.browserCloseDelay
                    }
                    // wait at least 1.0 seconds if tts was speaking
                    // wait 1.0 ~ 2.0 seconds if browser was open.
                    // hopefully closing browser and reading the content by voice over will be ended by then
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        let announce = String(format:NSLocalizedString("Going to %@", comment: ""), arguments: [dest.pron ?? dest.title])
                            + (dest.message?.content ?? "")

                        self.speak(announce){
                        }
                    }
                }
            }
        } else {
            _ = send(destination: "__cancel__")
        }
    }

    private func send(destination: String) -> Bool {
        DispatchQueue.main.async {
            print("Show modal waiting")
            NavUtil.showModalWaiting(withMessage: NSLocalizedString("processing...", comment: ""))
        }
        if wrpService.send(destination: destination) || self.noSuitcaseDebug  {
            DispatchQueue.main.async {
                print("hide modal waiting")
                NavUtil.hideModalWaiting()
            }
            return true
        } else {
            DispatchQueue.main.async {
                print("hide modal waiting")
                NavUtil.hideModalWaiting()
            }
            DispatchQueue.main.async {
                let message = NSLocalizedString("Suitcase may not be connected", comment: "")

                self.speak(message) {}
            }
            return false
        }
    }

    // MARK: CaBotServiceDelegate

    func caBot(service: CaBotTransportProtocol, versionMatched: Bool, with version: String) {
        self.versionMatched = versionMatched
        self.serverBLEVersion = version
    }

    func caBot(service: CaBotTransportProtocol, centralConnected: Bool) {
        if self.suitcaseConnected != centralConnected {
            self.suitcaseConnected = centralConnected

            let text = centralConnected ? NSLocalizedString("Suitcase has been connected", comment: "") :
                NSLocalizedString("Suitcase has been disconnected", comment: "")

            self.tts.speak(text, force: true) {_ in }
        }
    }

    func caBot(service: CaBotTransportProtocol, faceappConnected: Bool) {
        if self.backpackConnected != faceappConnected {
            self.backpackConnected = faceappConnected
        }
    }

    func cabot(service: CaBotTransportProtocol, bluetoothStateUpdated state: CBManagerState) {
        if bluetoothState != state {
            bluetoothState = state
        }

        #if targetEnvironment(simulator)
        bluetoothState = .poweredOn
        #endif
    }

    func cabot(service: CaBotTransportProtocol, openRequest url: URL) {
        NSLog("open request: %@", url.absoluteString)
        self.open(content: url)
    }

    func cabot(service: CaBotTransportProtocol, soundRequest: String) {
        switch(soundRequest) {
        case "SpeedUp":
            playAudio(file: speedUpSound)
            break
        case "SpeedDown":
            playAudio(file: speedDownSound)
            break
        default:
            NSLog("\"\(soundRequest)\" is unknown sound")
        }
    }

    func cabot(service: CaBotTransportProtocol, notification: NavigationNotification) {
        switch(notification){
        case .next:
            if tourManager.nextDestination() {
                self.playAudio(file: self.startSound)
            }else {
                self.speak(NSLocalizedString("No destination is selected", comment: "")) {
                }
            }
            break
        case .arrived:
            if let cd = tourManager.currentDestination {
                self.playAudio(file: self.arrivedSound)
                tourManager.arrivedCurrent()

                var announce = String(format:NSLocalizedString("You have arrived at %@", comment: ""), arguments: [cd.pron ?? cd.title])
                if let _ = cd.content?.url {
                    announce += String(format:NSLocalizedString("You can check detail of %@ on the phone", comment: ""), arguments: [cd.pron ?? cd.title])
                }
                if tourManager.hasDestination {
                    announce += NSLocalizedString("You can proceed by pressing the right button of the suitcase handle", comment: "")
                }

                self.speak(announce) {
                    // if user pressed the next button while reading announce, skip open content
                    if self.tourManager.currentDestination == nil {
                        if let contentURL = cd.content?.url {
                            self.open(content: contentURL)
                        }
                    }
                }
            }
            break
        }
    }

    func cabot(service: CaBotTransportProtocol, deviceStatus: DeviceStatus) -> Void {
        self.deviceStatus = deviceStatus
    }

    func cabot(service: CaBotTransportProtocol, systemStatus: SystemStatus) -> Void {
        self.systemStatus.update(with: systemStatus)
    }

    func cabot(service: CaBotTransportProtocol, batteryStatus: BatteryStatus) -> Void {
        self.batteryStatus = batteryStatus
    }

    func debugCabotArrived() {
        self.cabot(service: self.wrpService, notification: .arrived)
    }
}

class DiagnosticStatusData: NSObject, ObservableObject {
    @Published var name: String
    @Published var level: DiagnosticLevel
    @Published var message: String
    @Published var values: OrderedDictionary<String,String>
    init(with diagnostic: DiagnosticStatus) {
        self.name = diagnostic.componentName
        self.level = diagnostic.level
        self.message = diagnostic.message
        self.values = OrderedDictionary<String,String>()
        super.init()
        for value in diagnostic.values {
            self.values[value.key] = value.value
        }
    }
}

class ComponentData: DiagnosticStatusData {
    @Published var details: OrderedDictionary<String,DiagnosticStatusData>
    override init(with diagnostic: DiagnosticStatus) {
        self.details = OrderedDictionary<String,DiagnosticStatusData>()
        super.init(with: diagnostic)
    }
    func update(detail: DiagnosticStatus) {
        if let target = self.details[detail.componentName] {
            for value in detail.values {
                target.values[value.key] = value.value
            }
        } else {
            self.details[detail.componentName] = DiagnosticStatusData(with: detail)
        }
    }
}

class SystemStatusData: NSObject, ObservableObject {
    @Published var level: CaBotSystemLevel
    @Published var summary: DiagnosticLevel
    @Published var components: OrderedDictionary<String,ComponentData>

    static var cache:[String:ComponentData] = [:]

    override init() {
        level = .Unknown
        summary = .Stale
        components = OrderedDictionary<String,ComponentData>()
    }
    func levelText() -> String{
        switch(self.level) {
        case .Unknown, .Inactive, .Deactivating, .Error:
            if !self.components.isEmpty {
                return "Debug"
            }
            return self.level.rawValue
        case .Active, .Activating:
            return self.level.rawValue
        }
    }
    func clear() {
        self.components.removeAll()
    }
    func update(with status: SystemStatus) {
        self.level = status.level
        self.components = OrderedDictionary<String,ComponentData>()
        var allKeys = Set(self.components.keys)
        var max_level: Int = -1
        for diagnostic in status.diagnostics {
            if diagnostic.rootName == nil {
                let data = ComponentData(with: diagnostic)
                components[diagnostic.componentName] = data
                max_level = max(max_level, diagnostic.level.rawValue)
                allKeys.remove(diagnostic.componentName)
            }
        }
        for key in allKeys {
            self.components.removeValue(forKey: key)
        }
        self.summary = .Stale
        if max_level >= 0 {
            if let summary = DiagnosticLevel(rawValue: min(2, max_level)) {
                self.summary = summary
            }
        }
        for diagnostic in status.diagnostics {
            if let root = diagnostic.rootName {
                if let data = components[root] {
                    data.update(detail: diagnostic)
                }
            }
        }
    }

    var canStart:Bool {
        get {
            switch(self.level) {
            case .Unknown, .Active, .Activating, .Deactivating, .Error:
                return false
            case .Inactive:
                return true
            }
        }
    }

    var canStop:Bool {
        get {
            switch(self.level) {
            case .Unknown, .Inactive, .Activating, .Deactivating, .Error:
                return false
            case .Active:
                return true
                }
        }
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        return result
    }()

    static var empty: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CaBot")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                Typical reasons for an error here include:
                * The parent directory does not exist, cannot be created, or disallows writing.
                * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                * The device is out of space.
                * The store could not be migrated to the current model version.
                Check the error message to determine what the actual problem was.
                */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
}
