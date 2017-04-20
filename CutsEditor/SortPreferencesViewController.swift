//
//  SortPreferencesViewController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 24/06/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

protocol AppPreferences {
  func sortPreference() -> sortingPreferences
  func skipPreference() -> skipPreferences
  func adHunterPreference() -> adHunterPreferences
  func generalPreference() -> generalPreferences
  func videoPlayerPreference() -> videoPlayerPreferences
  func saveSortPreference(_ sortOrder: sortingPreferences)
  func saveSkipPreference(_ skips: skipPreferences)
  func saveGeneralPreference(_ general: generalPreferences)
  func saveVideoPlayerPreference(_ videoPlayer: videoPlayerPreferences)
  func cuttingQueue(withTitle title: String) -> CuttingQueue?
  func cuttingQueueTable() -> [CuttingQueue]
  func movie() -> Recording?
  func setMovie(movie: Recording?)
}

struct sortStringConsts {
  static let ascending = "Ascending"
  static let descending = "Descending"
  static let byDate = "Date"
  static let byName = "Name"
  static let byChannel = "Channel"
  
  // keys for user defaults
  static let order = "order"
  static let sortBy = "sortBy"
  static let skipDisplayArray = "skipDisplays"
  static let skipValueArray   = "skipValues"
}

struct adHunterStringConsts {
  static let visualClosing = "VisualClosing"
  static let speechClosing = "SpeechClosing"
  static let nearEngoughThreshold = "NearEnoughThreshold"
  static let closingBoundary = "ClosingBoundary"
}

class SortPreferencesViewController: NSViewController, NSControlTextEditingDelegate {

  // radio buttons - grouping is achieved by connection to common action function
  // group 1
  @IBOutlet weak var sortAscending: NSButton!
  @IBOutlet weak var sortDescending: NSButton!
  // group 2
  @IBOutlet weak var sortByName: NSButton!
  @IBOutlet weak var sortByDate: NSButton!
  @IBOutlet weak var sortByChannel: NSButton!
  
  @IBOutlet weak var visualClosingDisplay: NSButton!
  @IBOutlet weak var speechClosingDisplay: NSButton!
  @IBOutlet weak var nearEnoughForCutmark: NSTextField!
  @IBOutlet weak var gapForClosingReport: NSTextField!
  
  var delegate = NSApplication.shared().delegate as! AppPreferences
  var sortPreference = sortingPreferences()
  var adHunterPreference = adHunterPreferences()
  var adHunterChanged: Bool = false
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      getCurrentSettings()
      setupRadioButtonNames()
      adHunterChanged = false
    }
 
  func setupRadioButtonNames ()
  {
    sortAscending.title = sortStringConsts.ascending
    sortDescending.title = sortStringConsts.descending
    
    sortByName.title = sortStringConsts.byName
    sortByDate.title = sortStringConsts.byDate
    sortByChannel.title = sortStringConsts.byChannel
  }
  
  func getCurrentSettings()
  {
    sortPreference = delegate.sortPreference()
    if (sortPreference.isAscending) {
      sortAscending.selectCell(sortAscending.cell!)
    } else {
      sortDescending.selectCell(sortDescending.cell!)
    }
    
    if(sortPreference.sortBy == sortStringConsts.byDate) {
      sortByDate.selectCell(sortByDate.cell!)
    }
    else if (sortPreference.sortBy == sortStringConsts.byName ) {
      sortByName.selectCell(sortByName.cell!)
    }
    else if (sortPreference.sortBy == sortStringConsts.byChannel ) {
      sortByChannel.selectCell(sortByChannel.cell!)
    }
   
    adHunterPreference = delegate.adHunterPreference()
    visualClosingDisplay.state = adHunterPreference.isOverlayReporting ? NSOnState : NSOffState
    speechClosingDisplay.state = adHunterPreference.isSpeechReporting ? NSOnState : NSOffState
    nearEnoughForCutmark.doubleValue = adHunterPreference.nearEnough
    gapForClosingReport.doubleValue = adHunterPreference.closingReport
  }
  
  @IBAction func sortOrder(_ sender: NSButton) {
    if sender.title == sortStringConsts.ascending {
      sortPreference.isAscending = true
    }
    else {
      sortPreference.isAscending = false
    }
  }
  
  @IBAction func sortType(_ sender: NSButton) {
    sortPreference.sortBy = sender.title
  }
  
  @IBAction func saveSortPreferences(_ sender: NSButton) {
    delegate.saveSortPreference(sortPreference)
    NotificationCenter.default.post(name: Notification.Name(rawValue: sortDidChange), object: nil)
  }

  @IBAction func displayClosing(_ sender: NSButton)
  {
    adHunterPreference.isOverlayReporting = sender.state == NSOnState
    adHunterChanged = true
  }
  
  @IBAction func speakClosing(_ sender: NSButton)
  {
    adHunterPreference.isSpeechReporting = sender.state == NSOnState
    adHunterChanged = true
 }
  
  @IBAction func reloadSortPreferences(_ sender: NSButton) {
    getCurrentSettings()
  }
  
  @IBAction func done(_ sender: NSButton) {
    // TODO: build a "modified" and warn on exit without save of changes
    self.presenting?.dismiss(sender)
  }
  
  var originalBackgroundColor: NSColor? = nil
  
  /// handle changes to text fields
  override func controlTextDidEndEditing(_ obj: Notification)
  {
    var numberFieldEntryIsValid = false
    let textField = obj.object as! NSTextField
    // print (textField.stringValue)
    let fieldIdentifier = textField.identifier
    if originalBackgroundColor == nil {
      textField.wantsLayer = true
      originalBackgroundColor = textField.backgroundColor
    }
    
    if  Double(textField.stringValue) != nil
    {
      numberFieldEntryIsValid = true
      textField.backgroundColor = originalBackgroundColor
      textField.isBordered = false
      textField.isBordered = true
      textField.isBordered = false
    }
    else {
      numberFieldEntryIsValid = false
      textField.backgroundColor = NSColor.red
      NSBeep()
    }
    if numberFieldEntryIsValid && fieldIdentifier == adHunterStringConsts.nearEngoughThreshold
      {
        adHunterPreference.nearEnough = textField.doubleValue
        adHunterChanged = true
      }
      if numberFieldEntryIsValid && fieldIdentifier == adHunterStringConsts.closingBoundary
      {
        adHunterPreference.closingReport = textField.doubleValue
        adHunterChanged = true
      }
  }
  
  
}
