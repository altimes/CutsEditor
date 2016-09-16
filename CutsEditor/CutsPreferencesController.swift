
//
//  CutsPreferencesController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 24/06/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

class CutsPreferencesController: NSViewController,NSTextFieldDelegate, NSControlTextEditingDelegate {

  @IBOutlet weak var lh1Text: NSTextField!
  @IBOutlet weak var lh2Text: NSTextField!
  @IBOutlet weak var lh3Text: NSTextField!
  @IBOutlet weak var lh4Text: NSTextField!
  @IBOutlet weak var lh5Text: NSTextField!
  
  @IBOutlet weak var lh1Value: NSTextField!
  @IBOutlet weak var lh2Value: NSTextField!
  @IBOutlet weak var lh3Value: NSTextField!
  @IBOutlet weak var lh4Value: NSTextField!
  @IBOutlet weak var lh5Value: NSTextField!
  
  @IBOutlet weak var rh1Text: NSTextField!
  @IBOutlet weak var rh2Text: NSTextField!
  @IBOutlet weak var rh3Text: NSTextField!
  @IBOutlet weak var rh4Text: NSTextField!
  @IBOutlet weak var rh5Text: NSTextField!
  
  @IBOutlet weak var rh1Value: NSTextField!
  @IBOutlet weak var rh2Value: NSTextField!
  @IBOutlet weak var rh3Value: NSTextField!
  @IBOutlet weak var rh4Value: NSTextField!
  @IBOutlet weak var rh5Value: NSTextField!
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  var skips = skipPreferences()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      loadCurrentSkips()
    }
    
  @IBAction func saveAction(_ sender: NSButton)
  {
    // force text field to loose focus and end
    self.view.window?.makeFirstResponder(nil)
    preferences.saveSkipPreference(skips)
    NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
  }
  
  func loadCurrentSkips()
  {
    skips = preferences.skipPreference()
    lh1Text.stringValue = skips.lhs[0].display
    lh1Value.stringValue = String(skips.lhs[0].value)
    lh2Text.stringValue = skips.lhs[1].display
    lh2Value.stringValue = String(skips.lhs[1].value)
    lh3Text.stringValue = skips.lhs[2].display
    lh3Value.stringValue = String(skips.lhs[2].value)
    lh4Text.stringValue = skips.lhs[3].display
    lh4Value.stringValue = String(skips.lhs[3].value)
    lh5Text.stringValue = skips.lhs[4].display
    lh5Value.stringValue = String(skips.lhs[4].value)
    
    rh1Text.stringValue = skips.rhs[0].display
    rh1Value.stringValue = String(skips.rhs[0].value)
    rh2Text.stringValue = skips.rhs[1].display
    rh2Value.stringValue = String(skips.rhs[1].value)
    rh3Text.stringValue = skips.rhs[2].display
    rh3Value.stringValue = String(skips.rhs[2].value)
    rh4Text.stringValue = skips.rhs[3].display
    rh4Value.stringValue = String(skips.rhs[3].value)
    rh5Text.stringValue = skips.rhs[4].display
    rh5Value.stringValue = String(skips.rhs[4].value)
  }
  
  @IBAction func reloadButton(_ sender: NSButton)
  {
    // reload values from delegate
    loadCurrentSkips()
  }
  
//  func control(control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
////    print("Saw on tag \(fieldEditor.tag)")
////    let text = fieldEditor.string
////    print("save text of \(text)")
//    return true
//  }
  override func controlTextDidEndEditing(_ obj: Notification)
  {
    let textField = obj.object as! NSTextField
    // print (textField.stringValue)
    let tagValue = textField.tag
    if (tagValue > 0) {
      // rh column
      // display string or value
      if tagValue > 600 {
        // display field
        let index = tagValue - 600 - 1  // get a 0 based index
        skips.rhs[index].display = textField.stringValue
      }
      else {  // 500 series tag
        // value field
        let index = tagValue - 500 - 1 // get a zero based index
        skips.rhs[index].value = textField.doubleValue
      }
    }
    else {  // lh column
      if tagValue < -600
      {
        // display field
        let index = abs(tagValue) - 600 - 1
        skips.lhs[index].display = textField.stringValue
      }
      else { // -500 series tag
        // value field
        let index = abs(tagValue) - 500 - 1 // get a zero based index
        skips.lhs[index].value = textField.doubleValue
      }
    }
//    print(skips)
  }
  
  @IBAction func done(_ sender: NSButton) {
    self.presenting?.dismiss(sender)
  }

}
