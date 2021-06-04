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
        modelHelper.addSectionTitle("Select")
        for dir in ResourceManager.shared.models {
            modelHelper.addActionTitle(dir.name, name: "select_model_"+dir.id)
        }
    }

    static func initDefaultMenus() {
        defaultHelper.removeAllSetting()
        defaultHelper.addSectionTitle("")

        guard let cm = ResourceManager.shared.currentModel else {
            return
        }

        if cm.coversationURL != nil {
            defaultHelper.addActionTitle(NSLocalizedString("START_CONVERSATION",
                                                           tableName: "CaBotLocalizable",
                                                           comment: "Start Conversation Menu"),
                                         name: "start_conversation")
        }

        if cm.destinationsURL != nil {
            defaultHelper.addActionTitle(NSLocalizedString("SELECT_DESTINATION",
                                                           tableName: "CaBotLocalizable",
                                                           comment: "Select Destintion Menu"),
                                         name: "select_destination")
        }

        // TODO add custom menus

        defaultHelper.addSectionTitle("")
        defaultHelper.addActionTitle(NSLocalizedString("CANCEL_NAVIGATION",
                                                       tableName: "CaBotLocalizable",
                                                       comment: "Cancel Navigation Menu"),
                                     name: "cancel_navigation")
        //defaultHelper.addActionTitle("System Settings", name: "system_settings")
    }

    static func initDestinations() {
        guard let cm = ResourceManager.shared.currentModel else { return }
        guard let dest = cm.destinationsURL else { return }
        destinationHelpers.removeAll()

        self.loadDestinations(at: dest, for: "default")
    }

    static func loadDestinations(at url: URL, for name:String){
        // TODO move this to resource location
        if let yaml = try? String(contentsOf: url) {
            if let destinations = try? Yams.load(yaml: yaml) as? [[String:String]] {
                let newhelper = HLPSettingHelper()
                for destination in destinations {
                    newhelper.addActionTitle(destination["title"], accLabel: destination["pron"], name: destination["value"])
                    if let val = destination["value"], val.hasPrefix("destinations_"){
                        let url2 = url.deletingLastPathComponent().appendingPathComponent(val)
                        ViewController.loadDestinations(at: url2, for: val)
                    }
                }
                self.destinationHelpers[name] = newhelper
            }
        }
    }

    static func initSettings() {
        systemHelper.removeAllSetting()
        systemHelper.addSetting(with: .double, label: "Walking Speed", name: CaBotService.CABOT_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.25, max: 1.2, interval: 0.05)
        systemHelper.addSetting(with: .double, label: "Speech Speed", name: CaBotService.SPEECH_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.1, max: 1.0, interval: 0.05)
    }
    
    func actionPerformed(_ setting: HLPSetting!) {
        if let name = setting.name{
            if name.hasPrefix("select_model_"){
                let index = name.index(name.startIndex, offsetBy: "select_model_".count)
                let id = String(name[index...])
                ResourceManager.shared.selectModel(by: id)
                ViewController.initDefaultMenus()
                ViewController.initDestinations()
                self.performSegue(withIdentifier: "default_menu", sender: self)
            }
            else if name.hasPrefix("destinations_"){
                self.next_group_id = name
                self.performSegue(withIdentifier: "select_destination", sender: self)
            }
            else if name == "cancel_navigation" {
                NavUtil.showModalWaiting(withMessage: "waiting")
                DispatchQueue.main.async {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NavUtil.hideModalWaiting()
                    }
                    _ = ViewController.service.send(destination: "__cancel__")
                }
            }
            else if name.hasPrefix("EDITOR_") {
                if let destination = setting.name {
                    
                    DispatchQueue.main.async {
                        NavUtil.showModalWaiting(withMessage: "waiting")
                        if ViewController.service.send(destination: destination) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.navigationController?.popViewController(animated: true)
                                NavUtil.hideModalWaiting()
                            }
                        } else {
                            let alertController = UIAlertController(title: "Error", message: "CaBot may not be connected", preferredStyle: .alert)
                            let ok = UIAlertAction(title: "Okay", style: .default) { (action:UIAlertAction) in
                                alertController.dismiss(animated: true, completion: {
                                })
                            }
                            alertController.addAction(ok)
                            self.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
            }
            else {
                self.performSegue(withIdentifier: setting.name, sender: self)
            }
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
                        accessibilityLabel = accessibilityLabel + " connected"

                        if self.faceappConnected {
                            title = title + "🎒"
                            accessibilityLabel = accessibilityLabel + ", backpack ready"
                        }
                    } else {
                        title = title + "📵"
                        accessibilityLabel = accessibilityLabel + " not connected"
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

