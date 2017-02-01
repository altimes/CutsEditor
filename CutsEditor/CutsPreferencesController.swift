
//
//  CutsPreferencesController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 24/06/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

struct playerStringConsts {
  static let inLineRadio = "In Line"
  static let floatingRadio = "Floating"
  
  static let fastButtonsRadio = "Fastforward Buttons"
  static let steppingButtonsRadio = "Stepping Buttons"
  
  static let ffButtonTitle = "Fast"
  static let stepButtonTitle = "Step"
}

class CutsPreferencesController: NSViewController, NSTextFieldDelegate, NSControlTextEditingDelegate {

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
  
  @IBOutlet weak var inLineLabel: NSButton!
  @IBOutlet weak var floatingLabel: NSButton!
  @IBOutlet weak var fastforwardLabel: NSButton!
  @IBOutlet weak var steppingLabel: NSButton!
  
  @IBOutlet weak var honourOutIn: NSButton!
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  var skips = skipPreferences()
  var videoPlayerConfig = videoPlayerPreferences()
  var skipsChanged = false
  var playerChanged = false
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      loadCurrentSkips()
      loadCurrentVideoPlayerConfig()
    }
    
  @IBAction func saveAction(_ sender: NSButton)
  {
    // force text field to loose focus and end
    self.view.window?.makeFirstResponder(nil)
    if skipsChanged {
      preferences.saveSkipPreference(skips)
      NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
      skipsChanged = false
    }
    if playerChanged {
      preferences.saveVideoPlayerPreference(videoPlayerConfig)
      NotificationCenter.default.post(name: Notification.Name(rawValue: playerDidChange), object: nil)
      playerChanged = false
    }
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
  
  func secondaryPlayerButtons(showsSteppingControls: Bool) {
    // set Radio button state to match prefs
    fastforwardLabel.state = showsSteppingControls ? NSOffState : NSOnState
    steppingLabel.state = showsSteppingControls ? NSOnState : NSOffState
  }
  
  func loadCurrentVideoPlayerConfig()
  {
    videoPlayerConfig = preferences.videoPlayerPreference()
    if (videoPlayerConfig.playbackControlStyle == videoControlStyle.floating) {
      fastforwardLabel.isEnabled = true
      steppingLabel.isEnabled = true
      inLineLabel.state = (videoPlayerConfig.playbackControlStyle == videoControlStyle.inLine) ? NSOnState : NSOffState
      floatingLabel.state = (videoPlayerConfig.playbackControlStyle == videoControlStyle.floating) ? NSOnState : NSOffState
      // set Radio button state to match prefs
      secondaryPlayerButtons(showsSteppingControls: !videoPlayerConfig.playbackShowFastForwardControls)
    }
    else {
      fastforwardLabel.isEnabled = false
      steppingLabel.isBordered = false
    }
    setupRadioButtonNames()
    honourOutIn.state = (videoPlayerConfig.skipCutSections ? NSOnState : NSOffState)
    
  }
  
  func setupRadioButtonNames ()
  {
    inLineLabel.title = playerStringConsts.inLineRadio
    floatingLabel.title = playerStringConsts.floatingRadio
    
    fastforwardLabel.title = playerStringConsts.fastButtonsRadio
    steppingLabel.title = playerStringConsts.steppingButtonsRadio
  }
  
  @IBAction func reloadButton(_ sender: NSButton)
  {
    // reload values from delegate
    loadCurrentSkips()
    loadCurrentVideoPlayerConfig()
    playerChanged = false
  }
  
  /// Update from checkbox change of to player control to skip the Cut Out sections
  @IBAction func changeHonourOutIn(_ sender: NSButton)
  {
    videoPlayerConfig.skipCutSections = (sender.state == NSOnState)
    playerChanged = true
  }
  
  @IBAction func playerControlStyle(_ sender: NSButton)
  {
    if sender.title == playerStringConsts.inLineRadio {
      fastforwardLabel.isEnabled = false
      steppingLabel.isEnabled = false
      videoPlayerConfig.playbackControlStyle = videoControlStyle.inLine
    }
    if sender.title == playerStringConsts.floatingRadio {
      fastforwardLabel.isEnabled = true
      steppingLabel.isEnabled = true
      videoPlayerConfig.playbackControlStyle = videoControlStyle.floating
      // set Radio button state to match prefs
      secondaryPlayerButtons(showsSteppingControls: !videoPlayerConfig.playbackShowFastForwardControls)
    }
    playerChanged = true
  }
  
  @IBAction func controlButtonType(_ sender: NSButton) {
    videoPlayerConfig.playbackShowFastForwardControls = (sender.title == playerStringConsts.fastButtonsRadio)
    playerChanged = true
  }
  
  /// handle changes to text fields
  /// this relies of the tag codes +/- 501->505 / 601/605 ascribed to each of the 20 entry text fields
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
    skipsChanged = true
  }
  
  /// Close this model dialog
  @IBAction func done(_ sender: NSButton) {
    // TODO: build a "modified" and warn on exit without save of changes
    self.presenting?.dismiss(sender)
  }

}
