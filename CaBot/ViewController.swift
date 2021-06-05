/*******************************************************************************
 * Copyright (c) 2019  Carnegie Mellon University
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

import UIKit
import Yams
import CoreBluetooth
import HLPDialog

class ViewController: UITableViewController, HLPSettingHelperDelegate, CaBotServiceDelegate  {

    static let modelHelper:HLPSettingHelper = HLPSettingHelper()
    static let defaultHelper:HLPSettingHelper = HLPSettingHelper()
    static var destinationHelpers:[String:HLPSettingHelper] = [:]
    static let systemHelper:HLPSettingHelper = HLPSettingHelper()

    static var actionHandlers:[String: (ViewController, HLPSetting) -> Void] = [:]

    static var service:CaBotService!

    var centralConnected:Bool = false
    var faceappConnected:Bool = false
    var dest_group_id:String = "default"
    var next_group_id:String? = nil

    var viewIdentifier:String? = nil

    static func initHelper(){
        DialogManager.sharedManager().config = ["conv_server": "dummy",
                                                "conv_api_key": "dummy"]
        service = CaBotService()

        initModels()
        initSettings()

        // show version number
        let versionNo = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
        let buildNo = Bundle.main.infoDictionary?["CFBundleVersion"]
        defaultHelper.addSectionTitle("version: \(versionNo!) (\(buildNo!))")
    }

    static func initModels() {
        modelHelper.removeAllSetting()
        modelHelper.addSectionTitle(NSLocalizedString("Select", tableName: "CaBotLocalizable", comment: ""))
        for dir in ResourceManager.shared.models {
            modelHelper.addActionTitle(dir.name, name: "select_model_"+dir.id)

            actionHandlers["select_model_"+dir.id] = { view, setting in
                ResourceManager.shared.selectModel(by: dir.id)
                view.initDefaultMenus()
                view.initDestinations()
                view.performSegue(withIdentifier: "default_menu", sender: self)
            }
        }

    }

    func initDefaultMenus() {
        ViewController.defaultHelper.removeAllSetting()
        ViewController.defaultHelper.addSectionTitle("")

        guard let cm = ResourceManager.shared.currentModel else {
            return
        }

        if cm.coversationURL != nil {
            ViewController.defaultHelper.addActionTitle(NSLocalizedString("START_CONVERSATION",
                                                           tableName: "CaBotLocalizable",
                                                           comment: "Start Conversation Menu"),
                                         name: "start_conversation")
        }

        if cm.destinationsURL != nil {
            ViewController.defaultHelper.addActionTitle(NSLocalizedString("SELECT_DESTINATION",
                                                           tableName: "CaBotLocalizable",
                                                           comment: "Select Destintion Menu"),
                                         name: "select_destination")
        }

        for menu in cm.customeMenus {
            ViewController.defaultHelper.addActionTitle(menu.title,
                                         name: menu.id)
            ViewController.actionHandlers[menu.id] = { view, setting in
                let jsHelper = JSHelper(withScript: cm.resolveURL(from: menu.script), withView: view)
                _ = jsHelper.call(menu.function, withArguments: [])
            }
        }

        ViewController.defaultHelper.addSectionTitle("")
        ViewController.defaultHelper.addActionTitle(NSLocalizedString("CANCEL_NAVIGATION",
                                                       tableName: "CaBotLocalizable",
                                                       comment: "Cancel Navigation Menu"),
                                     name: "cancel_navigation")
        ViewController.actionHandlers["cancel_navigation"] = { view, setting in
            NavUtil.showModalWaiting(withMessage: "waiting")
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NavUtil.hideModalWaiting()
                }
                _ = ViewController.service.send(destination: "__cancel__")
            }
        }
        //defaultHelper.addActionTitle("System Settings", name: "system_settings")
    }

    func initDestinations() {
        guard let cm = ResourceManager.shared.currentModel else { return }
        guard let dest = cm.destinationsURL else { return }
        ViewController.destinationHelpers.removeAll()

        self.loadDestinations(at: dest, for: "default")
    }

    func loadDestinations(at url: URL, for name:String){
        guard let yaml = try? String(contentsOf: url) else { return }
        guard let destinations = try? Yams.load(yaml: yaml) as? [[String:String]] else { return }
        let newhelper = HLPSettingHelper()
        for destination in destinations {
            if let dest_id = destination["value"] {
                newhelper.addActionTitle(destination["title"], accLabel: destination["pron"], name: dest_id)
                ViewController.actionHandlers[dest_id] = { view, setting in
                    DispatchQueue.main.async {
                        NavUtil.showModalWaiting(withMessage: "waiting")
                        if ViewController.service.send(destination: dest_id) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                view.navigationController?.popViewController(animated: true)
                                NavUtil.hideModalWaiting()
                            }
                        } else {
                            NavUtil.hideModalWaiting()
                            let alertController = UIAlertController(title: NSLocalizedString("ERROR",
                                                                                             tableName: "CaBotLocalizable",
                                                                                             comment: "Alert Error Title"),
                                                                    message: NSLocalizedString("CaBot may not be connected",
                                                                                               tableName: "CaBotLocalizable",
                                                                                               comment: "CaBot may not be connected"),
                                                                    preferredStyle: .alert)
                            let ok = UIAlertAction(title: NSLocalizedString("Okay",
                                                                            tableName: "CaBotLocalizable",
                                                                            comment: "Okay"),
                                                   style: .default) { (action:UIAlertAction) in
                                alertController.dismiss(animated: true, completion: {
                                })
                            }
                            alertController.addAction(ok)
                            view.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
            if let src = destination["src"] {
                newhelper.addActionTitle(destination["title"], accLabel: destination["pron"], name: src)
                ViewController.actionHandlers[src] = { view, setting in
                    view.next_group_id = setting.name
                    view.performSegue(withIdentifier: "select_destination", sender: view)
                }

                let url2 = url.deletingLastPathComponent().appendingPathComponent(src)
                self.loadDestinations(at: url2, for: src)
            }
        }
        ViewController.destinationHelpers[name] = newhelper
    }

    static func initSettings() {
        systemHelper.removeAllSetting()
        systemHelper.addSetting(with: .double, label: "Walking Speed", name: CaBotService.CABOT_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.25, max: 1.2, interval: 0.05)
        systemHelper.addSetting(with: .double, label: "Speech Speed", name: CaBotService.SPEECH_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.1, max: 1.0, interval: 0.05)
    }
    
    func actionPerformed(_ setting: HLPSetting!) {
        if let handler = ViewController.actionHandlers[setting.name] {
            handler(self, setting)
        } else {
            self.performSegue(withIdentifier: setting.name, sender: self)
        }
    }
    
    func caBot(service: CaBotService, centralConnected: Bool) {
        self.centralConnected = centralConnected
        //NSLog(self.centralConnected)
        DispatchQueue.main.async {
            self.updateView()
        }
    }
    
    func caBot(service: CaBotService, faceappConnected: Bool) {
        self.faceappConnected = faceappConnected
        //NSLog(self.centralConnected)
        DispatchQueue.main.async {
            self.updateView()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.service.delegate = self
        
        var helper:HLPSettingHelper? = ViewController.defaultHelper
        //navigationController?.navigationBar.prefersLargeTitles = true
        
        self.updateView()
        if let rid:String = self.viewIdentifier{
            if rid == "select_destination" {
                helper = ViewController.destinationHelpers[self.dest_group_id]
            }else if rid == "system_settings" {
                helper = ViewController.systemHelper
            }
        } else {
            if ResourceManager.shared.hasDefaultModel {
                helper = ViewController.defaultHelper
            } else {
                helper = ViewController.modelHelper
            }
        }
        
        
        if let helper = helper {
            helper.delegate = self
            self.tableView.delegate = helper
            self.tableView.dataSource = helper
        }
    }
    
    func updateView() {
        DispatchQueue.main.async {
            let titleLabel = UILabel()
            
            var title:String = ""
            var accessibilityLabel:String = ""
            if let rid = self.viewIdentifier{
                if rid == "default_menu" {
                    title = "CaBot"
                    accessibilityLabel = "CaBot"
                    if self.centralConnected {
                        title = title + "📱"
                        accessibilityLabel = accessibilityLabel + NSLocalizedString(" connected", tableName: "CaBotLocalizabl", comment: "")

                        if self.faceappConnected {
                            title = title + "🎒"
                            accessibilityLabel = accessibilityLabel + NSLocalizedString(", backpack ready", tableName: "CaBotLocalizabl", comment: "")
                        }
                    } else {
                        title = title + "📵"
                        accessibilityLabel = accessibilityLabel + NSLocalizedString(" not connected", tableName: "CaBotLocalizabl", comment: "")
                    }
                    
                    
                    //NSLog(title)
                    if let settings = ViewController.defaultHelper.settings as! [HLPSetting]? {
                        for setting in settings {
                            //setting.disabled = !self.centralConnected
                            setting.disabled = false
                        }
                    }
                    self.tableView.reloadData()
                }else if rid == "select_destination" {
                    title = NSLocalizedString("DESTINATIONS_LABEL",
                                              tableName: "CaBotLocalizable",
                                              comment: "Destinations Label")
                }else if rid == "system_settings" {
                    title = NSLocalizedString("SETTINGS_LABEL",
                                              tableName: "CaBotLocalizable",
                                              comment: "Settings Label")
                }
            }
            
            titleLabel.text = title
            if accessibilityLabel.count > 0 {
                titleLabel.accessibilityLabel = accessibilityLabel
            }
            self.navigationItem.titleView = titleLabel
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextvc = segue.destination as? DialogViewControllerCabot {
            nextvc.modelURL = ResourceManager.shared.currentModel?.coversationURL
        }
        else {
            if let nextvc = segue.destination as? ViewController {
                if let nextgroupid = self.next_group_id {
                    nextvc.dest_group_id = nextgroupid
                }
                nextvc.viewIdentifier = segue.identifier
            }
        }
    }
}

