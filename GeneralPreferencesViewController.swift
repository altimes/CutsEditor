//
//  GeneralPreferencesViewController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 9/08/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

struct generalStringConsts {
  // keys for user defaults
  static let autoWrite = "AutoWrite"
  static let bookmarkMode = "BookmarkMode"
  static let bookmarkSpacing = "BookmarkSpacing"
  static let bookmarkCount = "BookmarkCount"
  
  static let fixedTimeTitle = "Fixed Step"
  static let fixedCountTitle = "Fixed Number"
  static let fixedTimeUnits = "Secs"
  static let fixedCountUnits = "Marks"
  
  // checkbox states
  static let replaceMode = "replaceModeState"
  static let newFileMode = "newFileModeState"
  static let newTitleMode = "newTitleModeState"
  static let newDescriptionMode = "newDescriptonModeState"
  
  static let remoteProgramPath = "remoteProgramPath"
  static let localProgramPath = "localProgramPath"
  static let localMountPoint = "localMountPoint"
  static let remoteExport = "remoteExport"
  
  // dialog field identifiers
  static let inputValueFieldIdentifier = "generalPrefsValueEntryField"
  static let inputStringFieldIdentifier = "generalPrefsStringEntryField"
  
}

class GeneralPreferencesViewController: NSViewController,NSControlTextEditingDelegate, NSTextDelegate
{
  @IBOutlet weak var markValueLabel: NSTextField!
  @IBOutlet weak var markValueUnitsLabel: NSTextField!
  @IBOutlet weak var autoWriteCheckBox: NSButton!
  @IBOutlet weak var fixedSteps: NSButton!
  @IBOutlet weak var fixedSpacing: NSButton!
  @IBOutlet weak var numberEntryField: NSTextField!
  
  @IBOutlet weak var remoteProgramPathField: NSTextField!
  @IBOutlet weak var localProgramPathField: NSTextField!
  @IBOutlet weak var localMountPath: NSTextField!
  @IBOutlet weak var remoteExportPath: NSTextField!
  @IBOutlet weak var fileReplaceFlagField: NSButton!
  @IBOutlet weak var changeDesciptionFlagField: NSButton!
  @IBOutlet weak var changeTitleFlagField: NSButton!
  @IBOutlet weak var newFileNameFlagField: NSButton!
  
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  var general = generalPreferences()
  var numberFieldEntryIsValid = false
  var numberFieldValue = 0
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      fixedSteps.title = generalStringConsts.fixedCountTitle
      fixedSpacing.title = generalStringConsts.fixedTimeTitle
      loadCurrentGeneralPrefs()
    }
  
  @IBAction func saveAction(_ sender: NSButton)
  {
    // force text field to loose focus and end
    self.view.window?.makeFirstResponder(nil)
    preferences.saveGeneralPreference(general)
    NotificationCenter.default.post(name: Notification.Name(rawValue: generalDidChange), object: nil)
  }
  
  
  @IBAction func reloadAction(_ sender: NSButton) {
    loadCurrentGeneralPrefs()
  }
  
  func loadCurrentGeneralPrefs()
  {
    general = preferences.generalPreference()
    autoWriteCheckBox.state = general.autoWrite ? NSOnState : NSOffState
    updateBookmarkGUI(general)
    
    // cuts program configuration
    remoteProgramPathField.stringValue = general.cutProgramRemotePath
    localProgramPathField.stringValue = general.cutProgramLocalPath
    remoteExportPath.stringValue = general.cutRemoteExport
    localMountPath.stringValue = general.cutLocalMountRoot
    
    fileReplaceFlagField.state = general.cutReplace
    changeDesciptionFlagField.state = general.cutDescription
    changeTitleFlagField.state = general.cutRenamePrograme
    newFileNameFlagField.state = general.cutOutputFile
    
  }
  
  func updateBookmarkGUI(_ genPrefs: generalPreferences)
  {
    autoWriteCheckBox.state = genPrefs.autoWrite ? NSOnState : NSOffState
    if (genPrefs.markMode == MARK_MODE.FIXED_COUNT_OF_MARKS)
    {
      fixedSteps.state = NSOnState
      markValueLabel.stringValue = generalStringConsts.fixedCountTitle
      markValueUnitsLabel.stringValue = generalStringConsts.fixedCountUnits
      numberEntryField.stringValue = "\(genPrefs.countModeNumberOfMarks)"
    }
    else {
      fixedSpacing.state = NSOnState
      markValueLabel.stringValue = generalStringConsts.fixedTimeTitle
      markValueUnitsLabel.stringValue = generalStringConsts.fixedTimeUnits
      numberEntryField.stringValue = "\(genPrefs.spacingModeDurationOfMarks)"
    }
    
  }
  
  @IBAction func bookmarkMode(_ sender: NSButton) {
    if (sender.title == generalStringConsts.fixedCountTitle) {
      general.markMode = MARK_MODE.FIXED_COUNT_OF_MARKS
    }
    else {
      general.markMode = MARK_MODE.FIXED_SPACING_OF_MARKS
    }
    updateBookmarkGUI(general)
  }
  
  @IBAction func changeMarkValue(_ sender: NSTextField) {
//    print("saw markfield action")
    if (numberFieldEntryIsValid)
    {
      switch general.markMode {
      case .FIXED_COUNT_OF_MARKS:
        general.countModeNumberOfMarks = numberFieldValue
      case .FIXED_SPACING_OF_MARKS:
        general.spacingModeDurationOfMarks = numberFieldValue
      }
    }
  }
  
  override func controlTextDidEndEditing(_ obj: Notification)
  {
    let textField = obj.object as! NSTextField
    print (#function+":"+textField.stringValue)
    if textField.identifier == generalStringConsts.inputValueFieldIdentifier
    {
      if let newValue = Int(textField.stringValue)
      {
        numberFieldValue = newValue
        numberFieldEntryIsValid = true
        textField.backgroundColor = NSColor.white
      }
      else {
        numberFieldEntryIsValid = false
        textField.backgroundColor = NSColor.red
        NSBeep()
      }
    }
  }
  
  @IBAction func autoWriteChanged(_ sender: NSButton)
  {
    general.autoWrite = sender.state == NSOnState
  }
  
  @IBAction func done(_ sender: NSButton) {
    self.presenting?.dismiss(sender)
  }
  
  @IBAction func changeCutPathSetting(_ sender: NSTextField) {
    print("got new path of \(sender.stringValue) for id of \(sender.identifier)")
    if let nextView = sender.nextKeyView {
      sender.resignFirstResponder()
      print("Trying to change focus ring")
      sender.window?.makeFirstResponder(nextView)
      sender.resignFirstResponder()
    }
    if let fieldIdentifier = sender.identifier {
      print("got field identifier of \(fieldIdentifier)")
      switch (fieldIdentifier) {
      case generalStringConsts.remoteProgramPath: general.cutProgramRemotePath = sender.stringValue
      case generalStringConsts.localProgramPath: general.cutProgramLocalPath = sender.stringValue
      case generalStringConsts.localMountPoint: general.cutLocalMountRoot = sender.stringValue
      case generalStringConsts.remoteExport: general.cutRemoteExport = sender.stringValue
      default: print("Argh unknown \(sender.identifier)")
      }
    }
  }
  @IBAction func changeCutReplaceSetting(_ sender: NSButton) {
    let stateString = sender.state == NSOnState ? "ON" : "OFF"
    print("saw replace toggle to \(stateString)")
    general.cutReplace = sender.state
  }
  @IBAction func changeCutDescriptionSetting(_ sender: NSButton) {
    let stateString = sender.state == NSOnState ? "ON" : "OFF"
    print("saw description toggle to \(stateString)")
    general.cutDescription = sender.state
  }
  @IBAction func changeCutTitleSetting(_ sender: NSButton) {
    let stateString = sender.state == NSOnState ? "ON" : "OFF"
    print("saw title toggle to \(stateString)")
    general.cutRenamePrograme = sender.state
  }
  @IBAction func changeCutFilenameSetting(_ sender: NSButton) {
    let stateString = sender.state == NSOnState ? "ON" : "OFF"
    print("saw newOutputfile toggle to \(stateString)")
    general.cutOutputFile = sender.state
  }
  
  
  
  
}
