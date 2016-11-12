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
  
  static let pvrConfigKey = "pvrConfig"
  
  // checkbox states
  static let replaceMode = "replaceModeState"
  static let newFileMode = "newFileModeState"
  static let newTitleMode = "newTitleModeState"
  static let newDescriptionMode = "newDescriptonModeState"
  
  static let remoteProgramPath = "remoteProgramPath"
  static let localProgramPath = "localProgramPath"
  static let localMountPoint = "localMountPoint"
  static let remoteExport = "remoteExport"
  
  // field identifiers must match with storyboard
  static let shPath = "shPath"
  static let sshPath = "sshPath"
  static let remoteLogin = "remoteLogin"
  
  // dialog field identifiers
  static let inputValueFieldIdentifier = "generalPrefsValueEntryField"
  static let inputStringFieldIdentifier = "generalPrefsStringEntryField"
  
}

/// keys for user defaults associated with video player config
struct playerConfigKeys {
  static let playerControlStyle = "PlayerControlStyle"
  static let playerSecondaryButtons = "PlayerSecondaryButtons"
  static let playerHonourCuts = "PlayerHonourCuts"
}

class GeneralPreferencesViewController: NSViewController, NSTextFieldDelegate
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
  
  @IBOutlet weak var pathToShCommand: NSTextField!
  @IBOutlet weak var pathToSshCommand: NSTextField!
  @IBOutlet weak var remoteLogin: NSTextField!
  
  @IBOutlet weak var pathToShLabel: NSTextField!
  @IBOutlet weak var pathToSshLabel: NSTextField!
  @IBOutlet weak var remoteLoginLabel: NSTextField!
  
  @IBOutlet weak var newPVRLabel: NSButton!
  @IBOutlet weak var deletePVRLabel: NSButton!
  @IBOutlet weak var pvrPicker: NSPopUpButton!
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  var general = generalPreferences()
  var numberFieldEntryIsValid = false
  var numberFieldValue = 0
  var pvrSettings = [pvrPreferences]()
  var pvrIndex = 0
  var pvrChanged = false
  var pvr = pvrPreferences()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      fixedSteps.title = generalStringConsts.fixedCountTitle
      fixedSpacing.title = generalStringConsts.fixedTimeTitle
      loadCurrentGeneralPrefs()
      numberEntryField.delegate = self
    }
  
  @IBAction func saveAction(_ sender: NSButton)
  {
    // force text field to loose focus and end
    self.view.window?.makeFirstResponder(nil)
    if (pvrChanged) {
      pvrSettings[pvrIndex] = pvr
      general.systemConfig.pvrSettings = pvrSettings
    }
    preferences.saveGeneralPreference(general)
    NotificationCenter.default.post(name: Notification.Name(rawValue: generalDidChange), object: nil)
  }
  
  
  @IBAction func reloadAction(_ sender: NSButton) {
    loadCurrentGeneralPrefs()
  }
  
  func loadCurrentGeneralPrefs()
  {
    general = preferences.generalPreference()
    autoWriteCheckBox.state = (general.autoWrite == CheckMarkState.checked) ? NSOnState : NSOffState
    updateBookmarkGUI(general)
    
    // cuts program configuration
    pvrSettings = general.systemConfig.pvrSettings
    pvrIndex = 0
    pvrPicker.removeAllItems()
    for i in 0 ..< pvrSettings.count {
      var pvr = pvrSettings[i]
      if (pvrPicker.itemTitles.contains(pvr.title)) {
        pvr.title += " (\(i))"
      }
      pvrPicker.addItem(withTitle: pvr.title)
    }
    updateGUIpvrDetails(pvr: pvrSettings[pvrIndex])
    pvr = pvrSettings[pvrIndex]
  }
 
  func updateGUIpvrDetails(pvr: pvrPreferences)
  {
    remoteProgramPathField.stringValue = pvr.cutProgramRemotePath
    localProgramPathField.stringValue = pvr.cutProgramLocalPath
    remoteExportPath.stringValue = pvr.cutRemoteExport
    localMountPath.stringValue = pvr.cutLocalMountRoot
    
    fileReplaceFlagField.state = (pvr.cutReplace == CheckMarkState.checked) ? NSOnState : NSOffState
    changeDesciptionFlagField.state = (pvr.cutDescription == CheckMarkState.checked) ? NSOnState : NSOffState
    changeTitleFlagField.state = (pvr.cutRenamePrograme == CheckMarkState.checked) ? NSOnState : NSOffState
    newFileNameFlagField.state = (pvr.cutOutputFile == CheckMarkState.checked) ? NSOnState : NSOffState
    
    pathToShCommand.stringValue = pvr.shPath
    pathToSshCommand.stringValue = pvr.sshPath
    remoteLogin.stringValue = pvr.remoteMachineAndLogin
    
    // set fields enabled according being a pvr config or the local config
    if pvr.title == mcutConsts.fixedLocalName {
      remoteProgramPathField.isEnabled = false
      localProgramPathField.isEnabled = true
      remoteExportPath.isEnabled = false
      
      pathToShCommand.isEnabled = true
      pathToSshCommand.isEnabled = false
      remoteLogin.isEnabled = false
    }
    else {
      remoteProgramPathField.isEnabled = true
      localProgramPathField.isEnabled = false
      remoteExportPath.isEnabled = true
      
      pathToShCommand.isEnabled = false
      pathToSshCommand.isEnabled = true
      remoteLogin.isEnabled = true
    }
  }
  
  func updateBookmarkGUI(_ genPrefs: generalPreferences)
  {
    autoWriteCheckBox.state = (genPrefs.autoWrite == CheckMarkState.checked) ? NSOnState : NSOffState
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
//    print (#function+":"+textField.stringValue)
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
    general.autoWrite = (sender.state == NSOnState) ? CheckMarkState.checked : CheckMarkState.unchecked
  }
  
  @IBAction func done(_ sender: NSButton) {
    // TODO: build a "modified" and warn on exit without save of changes
    self.presenting?.dismiss(sender)
  }
  
  @IBAction func changeCutPathSetting(_ sender: NSTextField) {
    pvrChanged = true
//    print("got new path of \(sender.stringValue) for id of \(sender.identifier)")
    if let nextView = sender.nextKeyView {
      sender.resignFirstResponder()
      sender.window?.makeFirstResponder(nextView)
    }
    if let fieldIdentifier = sender.identifier {
//      print("got field identifier of \(fieldIdentifier)")
      switch (fieldIdentifier) {
        case generalStringConsts.remoteProgramPath: pvr.cutProgramRemotePath = sender.stringValue
        case generalStringConsts.localProgramPath: pvr.cutProgramLocalPath = sender.stringValue
        case generalStringConsts.localMountPoint: pvr.cutLocalMountRoot = sender.stringValue
        case generalStringConsts.remoteExport: pvr.cutRemoteExport = sender.stringValue
      default: print("Argh unknown \(sender.identifier) "+#function)
      }
    }
  }
  @IBAction func changeCutReplaceSetting(_ sender: NSButton) {
    pvrChanged = true
    pvr.cutReplace = (sender.state == NSOnState) ? CheckMarkState.checked : CheckMarkState.unchecked
  }
  @IBAction func changeCutDescriptionSetting(_ sender: NSButton) {
    pvrChanged = true
    pvr.cutDescription = (sender.state == NSOnState) ? CheckMarkState.checked : CheckMarkState.unchecked
  }
  @IBAction func changeCutTitleSetting(_ sender: NSButton) {
    pvrChanged = true
    pvr.cutRenamePrograme = (sender.state == NSOnState) ? CheckMarkState.checked : CheckMarkState.unchecked
  }
  @IBAction func changeCutFilenameSetting(_ sender: NSButton) {
    pvrChanged = true
    pvr.cutOutputFile = (sender.state == NSOnState) ? CheckMarkState.checked : CheckMarkState.unchecked
  }
  
  @IBAction func changePVRSetting(_ sender: NSTextField) {
    pvrChanged = true
    if let nextView = sender.nextKeyView {
      sender.resignFirstResponder()
      //      print("Trying to change focus ring")
      sender.resignFirstResponder()
      sender.window?.makeFirstResponder(nextView)
    }
    if let fieldIdentifier = sender.identifier {
      switch (fieldIdentifier) {
      case generalStringConsts.shPath: general.systemConfig.pvrSettings[pvrIndex].shPath = sender.stringValue
      case generalStringConsts.sshPath: general.systemConfig.pvrSettings[pvrIndex].sshPath = sender.stringValue
      case generalStringConsts.remoteLogin: general.systemConfig.pvrSettings[pvrIndex].remoteMachineAndLogin = sender.stringValue
      default: print("Argh unknown \(sender.identifier) "+#function)
      }
    }
  }
  
  @IBAction func changePVR(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    if (pvrChanged) {
      pvrSettings[pvrIndex] = pvr
      general.systemConfig.pvrSettings = pvrSettings
    }
    pvr = pvrSettings[index]
    pvrIndex = index
    updateGUIpvrDetails(pvr: pvr)
  }
  
  /// Prompt user for a new description of the PVR
  /// - parameter startTitle: initial string which has " (1)" appended to it
  /// if the system is already using that title
  /// - returns : valid string or nil to allow caller to give up
  func getNewPVRConfigTitle(starterTitle: String) -> String?
  {
    var newTitleOK = false
    var newTitle : String? = nil
    var promptingTitle = starterTitle
    let titleArray = pvrSettings.map{$0.title}
    if (titleArray.contains(starterTitle)) {
       promptingTitle = promptingTitle + " (1)"
    }
    while (!newTitleOK) {
      newTitle = ViewController.getString(title: "PVR Title", question: "Enter New PVR Description", defaultValue: promptingTitle)
      newTitle = newTitle?.trimmingCharacters(in: CharacterSet(charactersIn: " "))
      newTitleOK = !titleArray.contains(newTitle!) && !(newTitle?.isEmpty)!
      if (!newTitleOK) {
        let nameNoGoodAlert = NSAlert()
        nameNoGoodAlert.alertStyle = NSAlertStyle.critical
        let informativeText = (newTitle?.characters.count == 0) ? "Blank Name" : "Name \"\(newTitle!)\" in use"
        nameNoGoodAlert.informativeText = informativeText
        nameNoGoodAlert.window.title = "Please Try Again"
        nameNoGoodAlert.messageText = "Existing or Empty Name"
        nameNoGoodAlert.addButton(withTitle: "OK")
        nameNoGoodAlert.addButton(withTitle: "Quit creating")
        let result = nameNoGoodAlert.runModal()
        if (result == NSAlertSecondButtonReturn)
        {
          return nil
        }
      }
    }
    return newTitle
  }
  
  /// Create a new config as a duplicate of the curent configuration
  @IBAction func newPVRConfig(_ sender: NSButton) {
    if (pvrChanged) {
      pvrSettings[pvrIndex] = pvr
    }
    
    if let newTitle = getNewPVRConfigTitle(starterTitle: pvr.title)
    {
      pvr.title = newTitle
      pvrPicker.addItem(withTitle: pvr.title)
      updateGUIpvrDetails(pvr: pvr)
      pvrSettings.append(pvr)
      pvrIndex = pvrSettings.count - 1
      pvrPicker.selectItem(at: pvrIndex)
      general.systemConfig.pvrSettings = pvrSettings
    }
  }
  
  @IBAction func deletePVRConfig(_ sender: NSButton) {
    if (pvrSettings.count>1) {
      let newIndex = (pvrIndex == pvrSettings.count-1) ? pvrIndex - 1:pvrIndex
      pvrSettings.remove(at: pvrIndex)
      pvrPicker.removeItem(at: pvrIndex)
      pvrIndex = newIndex
      pvr = pvrSettings[pvrIndex]
      pvrPicker.selectItem(at: pvrIndex)
      updateGUIpvrDetails(pvr: pvr)
      general.systemConfig.pvrSettings = pvrSettings
    }
  }
}
