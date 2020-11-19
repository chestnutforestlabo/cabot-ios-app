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

//
//  ViewController.swift
//  CaBot
//
//  Created by Daisuke Sato on 2019/05/08.
//  Copyright © 2019 Daisuke Sato. All rights reserved.
//

import UIKit
import Yams
import CoreBluetooth

class ViewController: UITableViewController, HLPSettingHelperDelegate, CaBotServiceDelegate  {

    static let defaultHelper:HLPSettingHelper = HLPSettingHelper()
    static let destinationHelper:HLPSettingHelper = HLPSettingHelper()
    static let systemHelper:HLPSettingHelper = HLPSettingHelper()
    static var service:CaBotService!
    
    var centralConnected:Bool = false
    var faceappConnected:Bool = false
    
    static func initHelper(){
        
        service = CaBotService()
        
        // main menu
        ViewController.defaultHelper.addSectionTitle("")
        ViewController.defaultHelper.addActionTitle("Select Destination", name: "select_destination")
        ViewController.defaultHelper.addSectionTitle("")
        ViewController.defaultHelper.addActionTitle("Cancel Navigation", name: "cancel_navigation")
        //ViewController.defaultHelper.addActionTitle("System Settings", name: "system_settings")
        
        
        let versionNo = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
        let buildNo = Bundle.main.infoDictionary?["CFBundleVersion"]
        
        ViewController.defaultHelper.addSectionTitle("version: \(versionNo!) (\(buildNo!))")

        // load destination yaml and make destination list
        if let yamlfile = Bundle.main.path(forResource: "destinations_coredo_all"/*"destinations"*/, ofType: "yaml") {
            if let yaml = try? String(contentsOfFile: yamlfile) {
                if let destinations = try? Yams.load(yaml: yaml) as? [[String:String]] {
                    for destination in destinations {
                        ViewController.destinationHelper.addActionTitle(destination["title"],
                                                                        name: destination["value"])
                    }
                }
            }
        }
        
        // system settings
        ViewController.systemHelper.addSetting(with: .double, label: "Walking Speed", name: CaBotService.CABOT_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.25, max: 1.2, interval: 0.05)
        ViewController.systemHelper.addSetting(with: .double, label: "Speech Speed", name: CaBotService.SPEECH_SPEED_CONFIG,
                                                defaultValue: NSNumber(0.5), min: 0.1, max: 1.0, interval: 0.05)
    }
    
    func actionPerformed(_ setting: HLPSetting!) {
        if setting.name.hasPrefix("EDITOR_") {
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
        } else if setting.name == "cancel_navigation" {
            NavUtil.showModalWaiting(withMessage: "waiting")
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    NavUtil.hideModalWaiting()
                }

                ViewController.service.send(destination: "__cancel__")
            }
        } else {
            self.performSegue(withIdentifier: setting.name, sender: self)
        }
    }
    
    func caBot(service: CaBotService, centralConnected: Bool) {
        self.centralConnected = centralConnected
        //print(self.centralConnected)
        DispatchQueue.main.async {
            self.updateView()
        }
    }
    
    func caBot(service: CaBotService, faceappConnected: Bool) {
        self.faceappConnected = faceappConnected
        //print(self.centralConnected)
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
        if self.restorationIdentifier == "default_menu" {
            helper = ViewController.defaultHelper
        }
        if self.restorationIdentifier == "select_destination" {
            helper = ViewController.destinationHelper
        }
        if self.restorationIdentifier == "system_settings" {
            helper = ViewController.systemHelper
        }
        
        if let helper = helper {
            helper.delegate = self
            self.tableView.delegate = helper
            self.tableView.dataSource = helper
        }
    }
    
    func updateView() {
        DispatchQueue.main.async {
            
            var titleLabel = UILabel()
            
            var title:String = ""
            var accessibilityLabel:String = ""
            if self.restorationIdentifier == "default_menu" {
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
                
                
                //print(title)
                if let settings = ViewController.defaultHelper.settings as! [HLPSetting]? {
                    for setting in settings {
                        setting.disabled = !self.centralConnected
                    }
                }
                self.tableView.reloadData()
            }
            if self.restorationIdentifier == "select_destination" {
                title = "Destinations"
            }
            if self.restorationIdentifier == "system_settings" {
                title = "Settings"
            }
            
            titleLabel.text = title
            if accessibilityLabel.count > 0 {
                titleLabel.accessibilityLabel = accessibilityLabel
            }
            self.navigationItem.titleView = titleLabel
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.restorationIdentifier = segue.identifier
    }
}

