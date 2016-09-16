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
  func generalPreference() -> generalPreferences
  func saveSortPreference(_ sortOrder: sortingPreferences)
  func saveSkipPreference(_ skips: skipPreferences)
  func saveGeneralPreference(_ general: generalPreferences)
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

class SortPreferencesViewController: NSViewController {

  // radio buttons
  // group 1
  @IBOutlet weak var sortAscending: NSButton!
  @IBOutlet weak var sortDescending: NSButton!
  // group 2
  @IBOutlet weak var sortByName: NSButton!
  @IBOutlet weak var sortByDate: NSButton!
  @IBOutlet weak var sortByChannel: NSButton!
  
  
  var delegate = NSApplication.shared().delegate as! AppPreferences
  var sortPreference = sortingPreferences()
  
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
      getCurrentSettings()
      setupRadioButtonNames()
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

  @IBAction func reloadSortPreferences(_ sender: NSButton) {
    getCurrentSettings()
  }
  
  @IBAction func done(_ sender: NSButton) {
    self.presenting?.dismiss(sender)
  }
  
  
}
