//
//  MetaData.swift
//  CutsEditor
//
//  Created by Alan Franklin on 11/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

// contents of BeyonWiz  (enigma2) .meta file decoded

import Cocoa
import Foundation

// ten item types in .meta file all text utf8

public struct MetaData {
  // REFTYPE:FLAGS:STYPE:SID:TSID:ONID:NS:PARENT_SID:PARENT_TSID:UNUSED:PATH:NAME
  var serviceReference : String
  var programName : String
  var programDescription : String
  var recordingTime : String
  var tags : String
  var duration : String
  var programFileSize : String
  var serviceData : String
  var packetSize : String
  var scrambled : String
  let debug = false
  
  init()
  {
    serviceReference = ""
    programName = ""
    programDescription = ""
    recordingTime = ""
    tags = ""
    duration = ""
    programFileSize = ""
    serviceData = ""
    packetSize = ""
    scrambled = ""
  }
  
  init(fromFilename: URL)
  {
    //    let location = NSString(string:"~/file.txt").stringByExpandingTildeInPath
    //    let fileContent = try? NSString(contentsOfFile: fromFilename.absoluteString, encoding: NSUTF8StringEncoding)
    self.init()
    
    if let fileText = try? String(contentsOf: fromFilename, encoding: String.Encoding.utf8) {
      if !decode(text: fileText) {
        print("Failed Decoding: Initialzed with empty values")
      }
    }
    else {
      print("Failed reading file: Initialzed with empty values")
    }
  }
  
  init(data rawData: Data) {
    self.init()
    if let fileText = String(data: rawData, encoding: String.Encoding.utf8)
    {
      if !decode(text: fileText) {
        print("Failed Decoding: Initialzed with empty values")
      }
    }
    else {
      print("Failed Converting Data To String: Initialzed with empty values")
    }
  }
  
  mutating func decode(text: String) -> Bool
  {
    var decoded = false
    if (debug) { print(">>>"+text+"<<<") }
    let fileAsArray = text.components(separatedBy: "\n")
    if (fileAsArray.count >= 10) {
      serviceReference = fileAsArray[0]
      programName = fileAsArray[1]
      programDescription = fileAsArray[2]
      recordingTime = fileAsArray[3]
      tags = fileAsArray[4]
      duration = fileAsArray[5]
      programFileSize = fileAsArray[6]
      serviceData = fileAsArray[7]
      packetSize = fileAsArray[8]
      scrambled = fileAsArray[9]
      decoded = true
    }
    return decoded
  }
  
  func description() -> String
  {
    let newLine = "\n"
    var returnString : String
    
    returnString = "eServiceRef:" + decodeServiceReference(serviceReference).description() + newLine
    returnString += newLine + "Name:"+programName
    returnString += newLine + "Description:" + programDescription
    returnString += newLine + "RecordingTime:"+recordingTime
    returnString += newLine + "Tags:"+tags
    returnString += newLine + "Duration:"+CutEntry.timeTextFromPTS(UInt64(duration)!)
    returnString += newLine + "FileSize:"+programFileSize
    returnString += newLine + "ServiceData:"+decodeServiceDataAsString(serviceData)
    returnString += newLine + "PacketSize:"+packetSize
    returnString += newLine + "Scrambled:"+scrambled
    
    return returnString
    
  }
  
  func decodeServiceReference(_ serviceRef : String) -> EServiceReference
  {
    // from http://radiovibrations.com/dreambox/services.htm
    //  REFTYPE:   -1=invalid id, 0=structure id, 1= Dvb Service, 2= File
    
    let items = serviceRef.components(separatedBy: ":")
    var referenceDecoded = EServiceReference()
    if let refTypeRawValue = Int(items[0]), let refType = ENIGMA2_SERVICEREFERENCE_REFTYPE(rawValue: refTypeRawValue)
      {
        referenceDecoded.referenceType = refType
      }
    else {
      referenceDecoded.referenceType = ENIGMA2_SERVICEREFERENCE_REFTYPE.INVALID
    }
    
    let flags = UInt8(items[1])!
    var flagSet = Set<ENIGMA2_SERVICEREFERENCE_FLAGS>()
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.ISADIRECTORY.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.ISADIRECTORY) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.CANNOT_BE_PLAYED.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.CANNOT_BE_PLAYED) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.MUST_CHANGE_TO_DIRECTORY.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.MUST_CHANGE_TO_DIRECTORY) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.NEEDS_SORTING.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.NEEDS_SORTING) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.SERVICE_HAS_SORT_KEY.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.SERVICE_HAS_SORT_KEY) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.SORT_KEY_IS_1.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.SORT_KEY_IS_1) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.ISAMARKER.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.ISAMARKER) }
    if ((flags & ENIGMA2_SERVICEREFERENCE_FLAGS.SERVICE_IS_NOT_PLAYABLE.rawValue)>0) { flagSet.insert(ENIGMA2_SERVICEREFERENCE_FLAGS.SERVICE_IS_NOT_PLAYABLE) }
    referenceDecoded.flags = flagSet
    
    if let serviceTypeRawValue = Int(items[2]), let serviceType = ENIGMA2_SERVICEREFERENCE_TYPE(rawValue: serviceTypeRawValue)
      {
        referenceDecoded.serviceType = serviceType
      }
    else {
      referenceDecoded.serviceType = ENIGMA2_SERVICEREFERENCE_TYPE.INVALID
    }
    
    referenceDecoded.service_id = UInt16(items[3], radix:16)
    referenceDecoded.transport_stream_id = UInt16(items[4], radix: 16)
    referenceDecoded.original_network_id = UInt16(items[5], radix: 16)
    referenceDecoded.namespace = UInt32(items[6], radix: 16)
    referenceDecoded.parent_service_id = UInt32(items[7], radix: 16)
    referenceDecoded.parent_transport_stream_id = UInt32(items[8], radix: 16)
    referenceDecoded.unused = items[9]
    referenceDecoded.path = items[10]
    if (items.count>=12) { referenceDecoded.name = items[11] }
    
    return referenceDecoded
  }
  
  func eServiceReferenceAsDescription(_ serviceRef : String) -> String
  {
    // from http://radiovibrations.com/dreambox/services.htm
    //  REFTYPE:   -1=invalid id, 0=structure id, 1= Dvb Service, 2= File
    
    let items = serviceRef.components(separatedBy: ":")
    if (debug) { print(items) }
    var returnString = "REFTYPE->\(items[0]):FLAGS->\(items[1]):STYPE->\(items[2]):SID->\(items[3]):TSID->\(items[4]):ONID->\(items[5]):NS->\(items[06]):PARENT_SID->\(items[7]):PARENT_TSID->\(items[08]):UNUSED->\(items[09]):PATH:->\(items[10])"
    if (items.count>=12)
    {
      returnString += "NAME->\(items[11])<"
    }
    else {
      returnString += "NAME->UNDEFINED<"
    }
//    Flags bitfield (in parenthesis the decimal value of the flag is stated):
//    1.Bit(01): It's about a Directory. // SHOULD enter (implies mustDescent)
//    2.Bit(02): The user must change to the directory // cannot be played directly - often used with "isDirectory" (implies canDescent)
//    3.Bit(04): The user may change to the directory  // supports enterDirectory/leaveDirectory
//    The Bits 1-3 have sense if set together
//    4.Bit(08): The content of the folder needs to be automatically sorted.
//               should be ASCII-sorted according to service_name. great for directories.
//    5.Bit(16): The Service has (enigma-internally) a sort-key. // has a sort key in data[3]. not having a sort key implies 0.
//    6.Bit(32): Sort key is 1 instead of 0
//    7.Bit(64): It's a marker
//    8.Bit(128): The service is not playable

    return (returnString)
  }
  
  struct serviceDataType: CustomStringConvertible {
    var flags:Int = 0        // duplication of reference flags ?
    var pidCache = [ENIGMA2_SERVICE_DATA_CACHE_TYPE:Int]()    // type and pid dictionary
    var provider = ""
    
    var description: String {
      get {
        var s = String(format:"flags:0x%04.4X",self.flags)
        for item in pidCache {
          if (item.key == ENIGMA2_SERVICE_DATA_CACHE_TYPE.cSUBTITLE)
          {
            s.append("\n"+subtitleDescription(value:item.value, teletextPID: pidCache[ENIGMA2_SERVICE_DATA_CACHE_TYPE.cTPID]))
          }
          else {
            let itemDescription = String(format:"\n%@:0x%04.4X",item.key.description,item.value)
              s.append(itemDescription)
          }
        }
        if !provider.isEmpty { s.append("\nprovider:"+self.provider)}
        return s
      }
    }
    
    /// format the various subtitle information elements decoded
    /// - parameter value: value element of numeric field
    /// - parameter teletextPID: pid of the teletext stream, if any
    /// - returns: printable formatted string
    
    func subtitleDescription(value: Int, teletextPID: Int?) -> String
    {
      var resultStr: String = ENIGMA2_SERVICE_DATA_CACHE_TYPE.cSUBTITLE.description
       // if teletext (track type 1) pid<<16 |page<<8,| sub <<3
       // if DVB (track type 2) pid<<16| composition page <<8
      
      let pid =  (value & 0xFFFF0000) >> 16
      let page = (value & 0x0000FF00) >> 8
      resultStr += String(format:":0x%4.4X", value)
      if (teletextPID != nil && pid == teletextPID)
      {       // teletext
       let sub =   (value & 0x000000F8) >> 3
        resultStr += String(format:"[0x%02.2X|%d:%d]", pid, page, sub)
      }
      else {  // DVB text
        resultStr += String(format:"[0x%02.2X:%d]", pid, page)
      }
      return resultStr
    }
  }
  
  // unix style "well formed" string, fields seperated by ","
  // fields encoded as char:digitsString
  
  func decodeServiceData(_ serviceData: String) -> serviceDataType
  {
    var decoded = serviceDataType()
    let kColon = ":"
    let kComma = ","
    
    let entries = serviceData.components(separatedBy: kComma)
    // split on ":"
    // first "must" be "f" field
    let serviceEntry = entries[0].components(separatedBy: kColon)
    guard serviceEntry[0] == "f" else { return decoded }
    if let serviceFlags = Int(serviceEntry[1]) {
      decoded.flags = serviceFlags
    }
    // TODO: think about and throw exception on bad flags field
    
    // process remaider of broken down string
//    var teletextPID:Int?
    for index in 1..<entries.count
    {
      let cacheEntry = entries[index]
      let cacheField = cacheEntry.components(separatedBy: kColon)
      if (cacheField[0] == "c")
      {
        // field is 2 decimal digits followed by 4 hex digits for all except subtitle, see below
        let decimalAsString = String(cacheField[1].characters.dropLast(cacheField[1].characters.count-2))
        let hexAsString = String(cacheField[1].characters.dropFirst(2))
        if let decimal = Int(decimalAsString), let entry = Int(hexAsString, radix:16) {
          if let fieldId = ENIGMA2_SERVICE_DATA_CACHE_TYPE(rawValue: decimal) {
              decoded.pidCache.updateValue(entry, forKey: fieldId)
          }
        }
        // TODO: throw expection on decoding failure
      }
      else if (cacheField[0] == "p") {
        decoded.provider = cacheField.count > 1 ? cacheField[1] : ""
      }
    }
    return decoded
  }
  
  func decodeServiceDataAsString(_ serviceData: String) -> String {
//    let kColon = ":"
//    let kComma = ","
//    var cacheString = ""
//    
//    let entries = serviceData.components(separatedBy: kComma)
//    // split on ":"
//    // first "must" be "f" field
//    let serviceEntry = entries[0].components(separatedBy: kColon)
//    let serviceFlags = serviceEntry[1]
//    for index in 1..<entries.count
//    {
//      var teletextPID:Int?
//      
//      let cacheEntry = entries[index]
//      let cacheField = cacheEntry.components(separatedBy: kColon)
//      // field is 2 decimal digits followed by 4 hex digits for all except subtitle, see below
//      let decimalAsString = String(cacheField[1].characters.dropLast(cacheField[1].characters.count-2))
//      let hexAsString = String(cacheField[1].characters.dropFirst(2))
//      let decimal = Int(decimalAsString)
//      let entry = Int(hexAsString, radix:16)
//      let fieldId = ENIGMA2_SERVICE_DATA_CACHE_TYPE(rawValue: decimal!)
//      if (fieldId == ENIGMA2_SERVICE_DATA_CACHE_TYPE.cTPID) {
//        // teltext PID, hang on to it for later cSubtitle Decoding
//        teletextPID = entry
//      }
//      var field: String
//      if (fieldId == ENIGMA2_SERVICE_DATA_CACHE_TYPE.cSUBTITLE) {
//         // if teletext (track type 1) pid<<16 |page<<8,| sub <<3
//         // if DVB (track type 2) pid<<16| composition page <<8
//         let pid =  (entry! & 0xFFFF0000) >> 16
//         let page = (entry! & 0x0000FF00) >> 8
//        if (pid == teletextPID && teletextPID != nil) {
//          // teletext
//         let sub =   (entry! & 0x000000F8) >> 3
//         field = "\(fieldId!.description):0x\(hexAsString)/[\(pid)|:(page):\(sub)]"
//        }
//        else {
//          field = "\(fieldId!.description):0x\(hexAsString)/[\(pid):\(page)]"
//        }
//      }
//      else {
//          field = "\(fieldId!.description):0x\(hexAsString)/\(entry!)"
//      }
//      cacheString += "\n"+field
//    }
//    let retStr = "\nService Flags:\(serviceFlags)" + cacheString
//    return retStr
    return decodeServiceData(serviceData).description
  }
}

public struct EServiceReference
{
  var referenceType : ENIGMA2_SERVICEREFERENCE_REFTYPE?
  var flags : Set<ENIGMA2_SERVICEREFERENCE_FLAGS>?
  var serviceType : ENIGMA2_SERVICEREFERENCE_TYPE?
  var service_id: UInt16?
  var transport_stream_id :UInt16?
  var original_network_id :UInt16?
  var namespace : UInt32?
  var parent_service_id : UInt32?
  var parent_transport_stream_id : UInt32?
  var unused: String?
  var path : String?
  var name : String?
  
  func description() -> String
  {
    
    let formatHexAndDecimal = { (value : UInt) -> String in return "0x" + String.init(value, radix: 16, uppercase: true) + " (\(value))" }
    
    var resultString = "Reference Type = \(self.referenceType!.description)"
    resultString += "\nReference Flags = \(self.flagsDescription())"
    resultString += "\nService Type \(String(describing:self.serviceType!))"
    resultString += "\nSID = " + formatHexAndDecimal(UInt(self.service_id!))
    resultString += "\nTSID = " + formatHexAndDecimal(UInt(self.transport_stream_id!))
    resultString += "\nONID = " + formatHexAndDecimal(UInt(self.original_network_id!))
    resultString += "\nNamespace = " + formatHexAndDecimal(UInt(self.namespace!))
    resultString += "\nParent SID = " + formatHexAndDecimal(UInt(self.parent_service_id!))
    resultString += "\nParent TSID = " + formatHexAndDecimal(UInt(self.parent_transport_stream_id!))
    resultString += "\nUnused = <\(self.unused!)>"
    resultString += "\nPath = <\(self.path!)>"
    resultString += "\nName = <\(self.name ?? "")>"
    
    return resultString
  }
  
  func flagsDescription() -> String
  {
    let bitSet = ENIGMA2_SERVICEREFERENCE_FLAGS.arrayOfFlagBits()
    var resultString = "["
    for flag in bitSet {
      var isAMember : String
      if ((self.flags?.contains(flag)) != nil) {
        isAMember = flag.toString()
      }
      else {
        isAMember = "Not Set \(flag.toString())|"
      }
      resultString += isAMember
    }
    resultString.remove(at: resultString.characters.index(before: resultString.endIndex))
    resultString += "]"
    return resultString
  }
}

enum ENIGMA2_SERVICEREFERENCE_REFTYPE : Int, CustomStringConvertible {
  case INVALID = -1
  case STRUCTURE_ID = 0
  case DVB_SERVICE = 1
  case FILE = 2
  
  var description: String
  {
    get {
      switch  self {
      case .INVALID: return "INVALID"
      case .STRUCTURE_ID: return "STRUCTURE_ID"
      case .DVB_SERVICE: return "DVB_SERVICE"
      case .FILE: return "FILE"
      }
    }
  }
  
  /// Utility to provide strings from UI display - should be language settable....
  static func allValues() -> [String]
  {
    return [String(describing:self.FILE),String(describing:self.DVB_SERVICE),String(describing:self.STRUCTURE_ID),String(describing:self.INVALID)]
  }
}

//    Flags bitfield (in parenthesis the decimal value of the flag is stated):
//    1.Bit(01): It's about a Directory. // SHOULD enter (implies mustDescent)
//    2.Bit(02): The user must change to the directory // cannot be played directly - often used with "isDirectory" (implies canDescent)
//    3.Bit(04): The user may change to the directory // supports enterDirectory/leaveDirectory
//    The Bits 1-3 have sense if set together
//    4.Bit(08): The content of the folder needs to be automatically sorted.
//               should be ASCII-sorted according to service_name. great for directories.
//    5.Bit(16): The Service has (enigma-internally) a sort-key. // has a sort key in data[3]. not having a sort key implies 0.
//    6.Bit(32): Sort key is 1 instead of 0
//    7.Bit(64): It's a marker
//    8.Bit(128): The service is not playable

enum ENIGMA2_SERVICEREFERENCE_FLAGS : UInt8 {
  case ISADIRECTORY = 1
  case CANNOT_BE_PLAYED = 2
  case MUST_CHANGE_TO_DIRECTORY = 4
  case NEEDS_SORTING = 8
  case SERVICE_HAS_SORT_KEY = 16
  case SORT_KEY_IS_1 = 32
  case ISAMARKER = 64
  case SERVICE_IS_NOT_PLAYABLE = 128
  
  func toString() -> String
  {
    switch  self
    {
    case .ISADIRECTORY: return "ISADIRECTORY"
    case .CANNOT_BE_PLAYED: return "CANNOT_BE_PLAYED"
    case .MUST_CHANGE_TO_DIRECTORY: return "MUST_CHANGE_TO_DIRECTORY"
    case .NEEDS_SORTING: return "NEEDS_SORTING"
    case .SERVICE_HAS_SORT_KEY: return "SERVICE_HAS_SORT_KEY"
    case .SORT_KEY_IS_1: return "SORT_KEY_IS_1"
    case .ISAMARKER: return "ISAMARKER"
    case .SERVICE_IS_NOT_PLAYABLE: return "SERVICE_IS_NOT_PLAYABLE"
    }
  }
  
  // create array containing all instances of the enum
  
  static func arrayOfFlagBits() -> [ENIGMA2_SERVICEREFERENCE_FLAGS]
  {
    var array = [ENIGMA2_SERVICEREFERENCE_FLAGS]()
    var bitValue :UInt8 = 1
    while (bitValue != 0)  // bit has not been shifted out of field width
    {
      if let flag = ENIGMA2_SERVICEREFERENCE_FLAGS(rawValue: bitValue)
      {
        array.append(flag)
      }
      bitValue = bitValue << 1
    }
    return array
  }
}


enum ENIGMA2_SERVICE_DATA_CACHE_TYPE : Int, CustomStringConvertible {
  case cVPID = 0,
  cAPID, cTPID, cPCRPID, cAC3PID, cVTYPE, cACHANNEL, cAC3DELAY, cPCMDELAY, cSUBTITLE,
  cacheMax  // sentinel
  
  var description: String {
  get {
    switch self {
    case .cVPID: return "Video Packet ID"
    case .cAPID: return "Audio Packet ID"
    case .cTPID: return "Teletext Packet ID"
    case .cPCRPID: return "Program Clock Reference Packet ID"
    case .cAC3PID: return "AC3 Packet ID"
    case .cVTYPE: return "Video Type"
    case .cACHANNEL: return "Audio Channel(Left/Right/Stereo)"
    case .cAC3DELAY: return "AC3 Delay"
    case .cPCMDELAY: return "PCM Delay"
    case .cSUBTITLE: return "Subtitle[PID:Page[:SubPage]]"
    case .cacheMax: return "Sentinel"
    }
  }
  }
}

enum ENIGMA2_SERVICEREFERENCE_TYPE : Int, CustomStringConvertible
{
  case INVALID = -1
  case TV = 1
  case RADIO = 2
  case DATA = 3
  
  var description: String
  {
    get {
      switch  self {
        case .INVALID: return "Invalid"
        case .TV: return "TV"
        case .RADIO: return "Radio"
        case .DATA: return "Data"
      }
    }
  }
  
  /// Utility to provide strings from UI display - should be language settable....
  static func allValues() -> [String]
  {
    return [String(describing:self.TV),String(describing:self.RADIO),String(describing:self.DATA),String(describing:self.INVALID)]
  }
}


