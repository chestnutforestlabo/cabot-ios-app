//
//  TestViewController.swift
//  CaBot
//
//  Created by CAL Cabot on 5/28/21.
//  Copyright © 2021 CMU. All rights reserved.
//

import UIKit

class TestViewController: UIViewController  {

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let view = segue.destination as? DialogViewControllerLocal {
            view.identifier = segue.identifier
        }
    }
}
