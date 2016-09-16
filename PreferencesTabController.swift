//
//  PreferencesTabController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 29/06/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

class PreferencesTabController: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
  
  @IBAction override func dismiss(_ sender: Any?) {
    //
    // print(#function+" called")
    super.dismissViewController(self)
  }
}
