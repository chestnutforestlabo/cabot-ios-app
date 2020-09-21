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
//  AppDelegate.swift
//  CaBot
//
//  Created by Daisuke Sato on 2019/05/08.
//  Copyright © 2019 Daisuke Sato. All rights reserved.
//

import UIKit
import AVKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ViewController.initHelper()
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self, selector: #selector(request_navigation(notification:)), name: Notification.Name(rawValue:"request_start_navigation"), object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(request_find_person(notification:)), name: Notification.Name(rawValue:"request_find_person"), object:nil)

        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true//reset sleep timer
        }
        return true
    }
    func cancel_navigation(){
        NavUtil.showModalWaiting(withMessage: "waiting")
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NavUtil.hideModalWaiting()
            }

            ViewController.service.send(destination: "__cancel__")
        }
    }
    @objc func request_navigation(notification:NSNotification?){
        if let info = notification?.userInfo, let destination:String = info["toID"] as? String{
            DispatchQueue.main.async {
                NavUtil.showModalWaiting(withMessage: "waiting")
                if ViewController.service.send(destination: destination) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NavUtil.hideModalWaiting()
                    }
                } else {
                    let alertController = UIAlertController(title: "Error", message: "CaBot may not be connected", preferredStyle: .alert)
                    let ok = UIAlertAction(title: "Okay", style: .default) { (action:UIAlertAction) in
                        alertController.dismiss(animated: true, completion: {
                            NavUtil.hideModalWaiting()
                        })
                    }
                    alertController.addAction(ok)
                    self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    @objc func request_find_person(notification:NSNotification?){
        if let info = notification?.userInfo, let name:String = info["name"] as? String{
            DispatchQueue.main.async {
                NavUtil.showModalWaiting(withMessage: "waiting")
                if ViewController.service.find(person: name) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        NavUtil.hideModalWaiting()
                    }
                } else {
                    let alertController = UIAlertController(title: "Error", message: "CaBot may not be connected", preferredStyle: .alert)
                    let ok = UIAlertAction(title: "Okay", style: .default) { (action:UIAlertAction) in
                        alertController.dismiss(animated: true, completion: {
                            NavUtil.hideModalWaiting()
                        })
                    }
                    alertController.addAction(ok)
                    self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .default,
                                                            policy: .longForm,
                                                            options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.

    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        do {
            try AVAudioSession.sharedInstance().setCategory(.soloAmbient, mode: .default,
                                                            options: .allowBluetooth)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

