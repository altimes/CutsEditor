//
//  AppDelegate.swift
//  CutsEditor
//
//  Created by Alan Franklin on 2/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate, AppPreferences {
  
  var defaultSkips = skipPreferences()
  var defaultSorting = sortingPreferences()
  var defaultGeneral = generalPreferences()
  var defaults : UserDefaults?
  var skipDisplayArray      = [String](repeating: "", count: 10)  // display 1..10
  var skipValueArray        = [Double](repeating: 0.0, count: 10)  // values 1..10
  var fileToOpen: String?
  
  func applicationDidFinishLaunching(_ notification: Notification)
  {
    // Insert code here to initialize your application
    // load up the user preferences or fabricate default settings
    defaults = UserDefaults.standard
    if defaults?.value(forKey: sortStringConsts.order) != nil
    {
      // sorting preferences
      defaultSorting.isAscending = (defaults?.bool(forKey: sortStringConsts.order))!
      defaultSorting.sortBy = (defaults?.string(forKey: sortStringConsts.sortBy))!
      NotificationCenter.default.post(name: Notification.Name(rawValue: sortDidChange), object: nil)
      
      // skip setting preferences
      let skipDisplayArray = defaults?.array(forKey: sortStringConsts.skipDisplayArray) as! [String]
      let skipValueArray = defaults?.array(forKey: sortStringConsts.skipValueArray) as! [Double]
      for i in 0 ... 4 {
        defaultSkips.lhs[i].value = skipValueArray[i]
        defaultSkips.lhs[i].display = skipDisplayArray[i]
        defaultSkips.rhs[i].value = skipValueArray[i+5]
        defaultSkips.rhs[i].display = skipDisplayArray[i+5]
      }
      NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
      
      // general preferences

      if let autoWriteValue = (defaults?.integer(forKey: generalStringConsts.autoWrite))
      {
        defaultGeneral.autoWrite = CheckMarkState.lookup(autoWriteValue)
        if let enumRawValue = defaults?.integer(forKey: generalStringConsts.bookmarkMode)
        {
          if let mode = MARK_MODE(rawValue: enumRawValue)
          {
            defaultGeneral.markMode = mode
          }
          else {
            defaultGeneral.markMode = MARK_MODE.FIXED_COUNT_OF_MARKS
          }
        }
        defaultGeneral.countModeNumberOfMarks = (defaults?.integer(forKey: generalStringConsts.bookmarkCount))!
        defaultGeneral.spacingModeDurationOfMarks = (defaults?.integer(forKey: generalStringConsts.bookmarkSpacing))!
        
        defaultGeneral.cutProgramLocalPath = (defaults?.string(forKey: generalStringConsts.localProgramPath))!
        defaultGeneral.cutProgramRemotePath = (defaults?.string(forKey: generalStringConsts.remoteProgramPath))!
        defaultGeneral.cutLocalMountRoot = (defaults?.string(forKey: generalStringConsts.localMountPoint))!
        defaultGeneral.cutRemoteExport = (defaults?.string(forKey: generalStringConsts.remoteExport))!
        
        defaultGeneral.cutReplace = CheckMarkState.lookup((defaults?.integer(forKey: generalStringConsts.replaceMode)))
        defaultGeneral.cutDescription = CheckMarkState.lookup((defaults?.integer(forKey: generalStringConsts.newDescriptionMode)))
        defaultGeneral.cutRenamePrograme = CheckMarkState.lookup((defaults?.integer(forKey: generalStringConsts.newTitleMode)))
        defaultGeneral.cutOutputFile = CheckMarkState.lookup((defaults?.integer(forKey: generalStringConsts.newFileMode)))
        
      }
      else {
        initGeneralSettings()
        saveGeneralPreference(defaultGeneral)
      }
      NotificationCenter.default.post(name: Notification.Name(rawValue: generalDidChange), object: nil)
    }
    else {
      initSkipSettings()
      initSortPreferences()
      initGeneralSettings()
      saveSkipPreference(defaultSkips)
      saveSortPreference(defaultSorting)
      saveGeneralPreference(defaultGeneral)
    }
    setInsertBookmarksMenuItemText()
  }

  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
  }
  
  func setInsertBookmarksMenuItemText()
  {
    let appMenu = NSApplication.shared().mainMenu
    let marksMenu = appMenu?.item(withTitle: "Marks")?.submenu
    let insertItem = marksMenu?.item(withTag: 100)
    let insertText = defaultGeneral.markMode == MARK_MODE.FIXED_COUNT_OF_MARKS ? "\(defaultGeneral.countModeNumberOfMarks) Bookmarks" : "\(defaultGeneral.spacingModeDurationOfMarks) sec Bookmarks"
    insertItem?.title = "Insert "+insertText
  }
  
  func initSortPreferences()
  {
    defaultSorting.isAscending = true
    defaultSorting.sortBy = sortStringConsts.byDate
    NotificationCenter.default.post(name: Notification.Name(rawValue: sortDidChange), object: nil)
  }
  
  func initSkipSettings()
  {
    let lh1 = skipPair(display: "-1s", value: -1.0)
    let lh2 = skipPair(display: "-5s", value: -5.0)
    let lh3 = skipPair(display: "-1m", value: -60.0)
    let lh4 = skipPair(display: "-15m", value: -15.0*60.0)
    let lh5 = skipPair(display: "-60m", value: -60.0*60.0)
    
    let rh1 = skipPair(display: "+1s", value: 1.0)
    let rh2 = skipPair(display: "+5s", value: 5.0)
    let rh3 = skipPair(display: "+1m", value: 60.0)
    let rh4 = skipPair(display: "+15m", value: 15.0*60.0)
    let rh5 = skipPair(display: "+60m", value: 60.0*60.0)
    
    defaultSkips = skipPreferences(lhs: [lh1,lh2,lh3,lh4,lh5], rhs: [rh1,rh2,rh3,rh4,rh5])
    NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
  }
  
  /// Create a default general preferences setting with nominally sensible values
  /// May be overriden by user defaults
  func initGeneralSettings()
  {
    defaultGeneral = generalPreferences()
//    defaultGeneral = generalPreferences(autoWrite: Checkmark.checked, markMode: MARK_MODE.FIXED_COUNT_OF_MARKS, countModeNumberOfMarks: 10, spacingModeDurationOfMarks: 180, cutReplace: CheckMarkState.checked, cutRenamePrograme: NSOffState, cutOutputFile: NSOffState, cutDescription: NSOffState, cutProgramLocalPath: "", cutProgramRemotePath: "", cutLocalMountRoot: "", cutRemoteExport: "")
  }
  
  // MARK: AppPreference Protocol
  
  func skipPreference() -> skipPreferences
  {
    return defaultSkips
  }
  
  func sortPreference() -> sortingPreferences
  {
//    print(defaultSorting)
    return defaultSorting
  }
 
  func generalPreference() -> generalPreferences
  {
    return defaultGeneral
  }
  
  func saveSortPreference(_ sortOrder: sortingPreferences)
  {
    defaultSorting = sortOrder
    defaults?.set(sortOrder.isAscending, forKey: sortStringConsts.order)
    defaults?.set(sortOrder.sortBy, forKey: sortStringConsts.sortBy)
  }
  
  func saveSkipPreference(_ newSkips: skipPreferences)
  {
    defaultSkips = newSkips
    
    // update userdefaults
    for i in 0 ... 4 {
       skipValueArray[i] = defaultSkips.lhs[i].value
       skipDisplayArray[i] = defaultSkips.lhs[i].display
       skipValueArray[i+5] = defaultSkips.rhs[i].value
       skipDisplayArray[i+5] = defaultSkips.rhs[i].display
    }
    defaults?.set(skipValueArray, forKey: sortStringConsts.skipValueArray)
    defaults?.set(skipDisplayArray, forKey: sortStringConsts.skipDisplayArray)
  }
  
  func saveGeneralPreference(_ general: generalPreferences) {
    defaultGeneral = general
    defaults?.set(defaultGeneral.autoWrite.rawValue, forKey: generalStringConsts.autoWrite)
    defaults?.set(defaultGeneral.countModeNumberOfMarks, forKey: generalStringConsts.bookmarkCount)
    defaults?.set(defaultGeneral.spacingModeDurationOfMarks, forKey: generalStringConsts.bookmarkSpacing)
    defaults?.set(defaultGeneral.markMode.rawValue, forKey: generalStringConsts.bookmarkMode)
   
    // checkBox settings
    defaults?.set(defaultGeneral.cutReplace.rawValue, forKey:generalStringConsts.replaceMode)
    defaults?.set(defaultGeneral.cutOutputFile.rawValue, forKey:generalStringConsts.newFileMode)
    defaults?.set(defaultGeneral.cutRenamePrograme.rawValue, forKey:generalStringConsts.newTitleMode)
    defaults?.set(defaultGeneral.cutDescription.rawValue, forKey:generalStringConsts.newDescriptionMode)
    
    // user path settings
    defaults?.set(defaultGeneral.cutProgramLocalPath, forKey:generalStringConsts.localProgramPath)
    defaults?.set(defaultGeneral.cutProgramRemotePath, forKey:generalStringConsts.remoteProgramPath)
    defaults?.set(defaultGeneral.cutLocalMountRoot, forKey:generalStringConsts.localMountPoint)
    defaults?.set(defaultGeneral.cutRemoteExport, forKey:generalStringConsts.remoteExport)
    
    // sync menu bar to match
    setInsertBookmarksMenuItemText()
  }
  
  func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    // print("saw request to open recent file with name <\(filename)")
    fileToOpen = filename
    NotificationCenter.default.post(name: Notification.Name(rawValue: fileOpenDidChange), object: fileToOpen!)
   return true
  }
}

