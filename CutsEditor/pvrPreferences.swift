//
//  pvrPreferences.swift
//  CutsEditor
//
//  Created by Alan Franklin on 12/11/16.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation

/// per pvr preferences
public struct pvrPreferences {
  var title = "Beyonwiz Tx"
  var cutReplace = CheckMarkState.checked
  var cutRenamePrograme = CheckMarkState.unchecked
  var cutOutputFile = CheckMarkState.unchecked
  var cutDescription = CheckMarkState.unchecked
  
  var cutProgramLocalPath = mcutConsts.mcutProgramLocal
  var cutProgramRemotePath = mcutConsts.mcutProgramRemote
  var cutLocalMountRoot = mcutConsts.localMount
  var cutRemoteExport = mcutConsts.remoteExportPath
  var remoteMachineAndLogin = mcutConsts.remoteMachineAndLogin
  var sshPath = mcutConsts.sshPath
  var shPath = mcutConsts.shPath
}

// based on http://stackoverflow.com/questions/38406457/how-to-save-an-array-of-custom-struct-to-nsuserdefault-with-swift
extension pvrPreferences {
  init(title: String) {
    self.title = title
  }
  
  init?(data: NSData)
  {
    if let coding = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? Encoding
    {
      title = coding.title as String
      cutReplace = CheckMarkState(rawValue: coding.cutReplace)!
      cutRenamePrograme = CheckMarkState(rawValue: coding.cutRenamePrograme)!
      cutOutputFile = CheckMarkState(rawValue: coding.cutOutputFile)!
      cutDescription = CheckMarkState(rawValue: coding.cutDescription)!
      cutProgramLocalPath = coding.cutProgramLocalPath as String
      cutProgramRemotePath = coding.cutProgramRemotePath as String
      cutLocalMountRoot = coding.cutLocalMountRoot as String
      cutRemoteExport = coding.cutRemoteExport as String
      remoteMachineAndLogin = coding.remoteMachineAndLogin as String
      sshPath = coding.sshPath as String
      shPath = coding.shPath as String
    } else {
      return nil
    }
  }
  
  func encode() -> NSData {
    return NSKeyedArchiver.archivedData(withRootObject: Encoding(self)) as NSData
  }
  
  private class Encoding: NSObject, NSCoding
  {
    let title : String
    let cutReplace : Int
    let cutRenamePrograme : Int
    let cutOutputFile : Int
    let cutDescription : Int
    let cutProgramLocalPath : String
    let cutProgramRemotePath : String
    let cutLocalMountRoot : String
    let cutRemoteExport : String
    let remoteMachineAndLogin : String
    let sshPath : String
    let shPath : String
    
    init(_ pvr: pvrPreferences) {
      title = pvr.title
      cutReplace = pvr.cutReplace.rawValue
      cutRenamePrograme = pvr.cutRenamePrograme.rawValue
      cutOutputFile = pvr.cutOutputFile.rawValue
      cutDescription = pvr.cutDescription.rawValue
      cutProgramLocalPath = pvr.cutProgramLocalPath
      cutProgramRemotePath = pvr.cutProgramRemotePath
      cutLocalMountRoot = pvr.cutLocalMountRoot
      cutRemoteExport = pvr.cutRemoteExport
      remoteMachineAndLogin = pvr.remoteMachineAndLogin
      sshPath = pvr.sshPath
      shPath = pvr.shPath
    }
    
    @objc required init?(coder aDecoder: NSCoder) {
      guard aDecoder.containsValue(forKey: "cutReplace") else {
        return nil
      }
      title = aDecoder.decodeObject(forKey: "title") as! String
      cutReplace = aDecoder.decodeInteger(forKey: "cutReplace")
      cutRenamePrograme = aDecoder.decodeInteger(forKey: "cutRenamePrograme")
      cutOutputFile = aDecoder.decodeInteger(forKey: "cutOutputFile")
      cutDescription = aDecoder.decodeInteger(forKey: "cutDescription")
      cutProgramLocalPath = aDecoder.decodeObject(forKey: "cutProgramLocalPath") as! String
      cutProgramRemotePath = aDecoder.decodeObject(forKey: "cutProgramRemotePath") as! String
      cutLocalMountRoot = aDecoder.decodeObject(forKey: "cutLocalMountRoot") as! String
      cutRemoteExport = aDecoder.decodeObject(forKey: "cutRemoteExport") as! String
      remoteMachineAndLogin = aDecoder.decodeObject(forKey: "remoteMachineAndLogin") as! String
      sshPath = aDecoder.decodeObject(forKey: "sshPath") as! String
      shPath = aDecoder.decodeObject(forKey: "shPath") as! String
    }
    
    @objc func encode(with aCoder: NSCoder) {
      aCoder.encode(title, forKey: "title")
      aCoder.encode(cutReplace, forKey: "cutReplace")
      aCoder.encode(cutRenamePrograme, forKey: "cutRenamePrograme")
      aCoder.encode(cutOutputFile, forKey: "cutOutputFile")
      aCoder.encode(cutDescription, forKey: "cutDescription")
      aCoder.encode(cutProgramLocalPath, forKey: "cutProgramLocalPath")
      aCoder.encode(cutProgramRemotePath, forKey: "cutProgramRemotePath")
      aCoder.encode(cutLocalMountRoot, forKey: "cutLocalMountRoot")
      aCoder.encode(cutRemoteExport, forKey: "cutRemoteExport")
      aCoder.encode(remoteMachineAndLogin, forKey: "remoteMachineAndLogin")
      aCoder.encode(sshPath, forKey: "sshPath")
      aCoder.encode(shPath, forKey: "shPath")
    }
  }
}
