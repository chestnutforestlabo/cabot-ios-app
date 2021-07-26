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

import CoreData
import SwiftUI
import Foundation
import CoreBluetooth
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
}

final class CaBotAppModel: NSObject, ObservableObject, CaBotServiceDelegate, TourManagerDelegate, CLLocationManagerDelegate {

    private let selectedResourceKey = "SelectedResourceKey"
    private let selectedVoiceKey = "SelectedVoiceKey"
    private let speechRateKey = "speechRateKey"
    private let teamIDKey = "team_id"
    private let menuDebugKey = "menu_debug"

    @Published var locationState: GrantState = .Init
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var notificationState: GrantState = .Init
    @Published var displayedScene: DisplayedScene = .Onboard

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
                    self.service.setVoice(voice.AVvoice)
                }
            }
        }
    }
    @Published var speechRate: Double = 0.5 {
        didSet {
            UserDefaults.standard.setValue(speechRate, forKey: speechRateKey)
            UserDefaults.standard.synchronize()
            service.tts.rate = speechRate
        }
    }

    @Published var suitcaseConnected: Bool = false
    @Published var backpackConnected: Bool = false

    @Published var teamID: String = "" {
        didSet {
            UserDefaults.standard.setValue(teamID, forKey: teamIDKey)
            UserDefaults.standard.synchronize()
            service.stopAdvertising()
            service.teamID = self.teamID
            service.startAdvertising()
        }
    }
    @Published var menuDebug: Bool = false {
        didSet {
            UserDefaults.standard.setValue(menuDebug, forKey: menuDebugKey)
            UserDefaults.standard.synchronize()
        }
    }

    @Published var hasDestination: Bool = false
    @Published var isContentPresenting:Bool = false
    @Published var contentURL: URL? = nil

    let service: CaBotService
    let preview: Bool
    let resourceManager: ResourceManager
    let tourManager: TourManager
    let dialogViewHelper: DialogViewHelper
    let notificationCenter: UNUserNotificationCenter

    let locationManager: CLLocationManager
    let locationUpdateTimeLimit: CFAbsoluteTime = 60*15
    var locationUpdateStartTime: CFAbsoluteTime = 0
    var audioAvailableEstimate: Bool = false

    convenience override init() {
        self.init(preview: true)
    }

    init(preview: Bool) {
        self.preview = preview
        self.service = CaBotService()
        self.resourceManager = ResourceManager(preview: preview)
        self.tourManager = TourManager()
        self.dialogViewHelper = DialogViewHelper()
        self.locationManager =  CLLocationManager()
        self.notificationCenter = UNUserNotificationCenter.current()
        super.init()
        self.tourManager.delegate = self
        self.service.delegate = self
        self.locationManager.delegate = self

        if let selectedName = UserDefaults.standard.value(forKey: selectedResourceKey) as? String {
            self.resource = resourceManager.resource(by: selectedName)
        }
        if let groupID = UserDefaults.standard.value(forKey: teamIDKey) as? String {
            self.teamID = groupID
        }
        if let menuDebug = UserDefaults.standard.value(forKey: menuDebugKey) as? Bool {
            self.menuDebug = menuDebug
        }
        if let speechRate = UserDefaults.standard.value(forKey: speechRateKey) as? Double {
            self.speechRate = speechRate
        }
    }

    func onChange(of newScenePhase: ScenePhase) {
        switch newScenePhase {
        case .background:
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback,
                                                                mode: .default,
                                                                policy: .default,
                                                                options: [.allowBluetooth])
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                NSLog("audioSession properties weren't set because of an error.")
            }

            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
            break
        case .inactive:
            break
        case .active:
            audioAvailableEstimate = true
            self.initNotification()
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback,
                                                                mode: .default,
                                                                policy: .default,
                                                                options: [.allowBluetooth])
                try AVAudioSession.sharedInstance().setActive(true, options: [])
            } catch {
                NSLog("audioSession properties weren't set because of an error.")
            }

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


    func requestAuthorization() {
        self.service.startAdvertising()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

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


    // MARK: TourManagerDelegate
    func tourUpdated(manager: TourManager) {
        hasDestination = manager.hasDestination
    }

    func tour(manager: TourManager, destinationChanged destination: Destination?) {
        if let dest = destination {
            if let dest_id = dest.value {
                if !send(destination: dest_id) {
                    manager.cannotStartCurrent()
                } else {
                    service.tts.speak(String(format:NSLocalizedString("Going to %@", comment: ""), arguments: [dest.pron ?? dest.title])) {
                        if let content = dest.message?.content {
                            self.service.tts.speak(content){

                            }
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
        if service.send(destination: destination) {
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
                let title = NSLocalizedString("ERROR", comment: "")
                let message = NSLocalizedString("Suitcase may not be connected", comment: "")

                self.service.tts.speak(message) {}
                /*
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let ok = UIAlertAction(title: NSLocalizedString("Okay",
                                                                comment: "Okay"),
                                       style: .default) { (action:UIAlertAction) in
                    alertController.dismiss(animated: true, completion: {
                    })
                }
                alertController.addAction(ok)

                if let view = UIApplication.shared.windows[0].visibleViewController {
                    view.present(alertController, animated: true, completion: nil)
                }
                 */
            }
            return false
        }
    }

    // MARK: CaBotServiceDelegate

    func caBot(service: CaBotService, centralConnected: Bool) {
        if self.suitcaseConnected != centralConnected {
            self.suitcaseConnected = centralConnected

            let text = centralConnected ? NSLocalizedString("Suitcase has been connected", comment: "") :
                NSLocalizedString("Suitcase has been disconnected", comment: "")

            service.tts.speak(text, force: true) {
            }
        }
    }

    func caBot(service: CaBotService, faceappConnected: Bool) {
        if self.backpackConnected != faceappConnected {
            self.backpackConnected = faceappConnected
        }
    }

    func cabot(service: CaBotService, bluetoothStateUpdated state: CBManagerState) {
        if bluetoothState != state {
            bluetoothState = state
        }

        #if targetEnvironment(simulator)
        bluetoothState = .poweredOn
        #endif
    }

    func cabot(service: CaBotService, openRequest url: URL) {
        NSLog("open request: %@", url.absoluteString)
        contentURL = url
        isContentPresenting = true
    }

    func cabot(service: CaBotService, notification: NavigationNotification) {
        switch(notification){
        case .next:
            tourManager.nextDestination()
            break
        case .arrived:
            if let cd = tourManager.currentDestination {
                self.service.tts.speak(String(format:NSLocalizedString("You have arrived at %@", comment: ""), arguments: [cd.pron ?? cd.title])) {
                }
                if let contentURL = cd.content?.url {
                    self.cabot(service: self.service, openRequest: contentURL)
                }
            }
            tourManager.arrivedCurrent()
            break
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
