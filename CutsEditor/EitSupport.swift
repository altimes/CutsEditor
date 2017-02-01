//
//  EitSupport.swift
//  CutsEditor
//
//  Created by Alan Franklin on 30/05/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

// code for interpreting the xxxxxxx.eit file from a Beyonwiz PVR
// which is built around an Engima2 base code

// partly from transcription of python to swift from core parsing from

// https://github.com/betonme/e2openplugin-EnhancedMovieCenter/blob/master/src/EitSupport.py

// and from deciphering of sections of ETSI EN 300 468 V1.11.1 (2010-04)
// Digital Video Broadcasting (DVB); Specification for Service Information (SI) in DVB Systems

struct EITConst {
  static let SHORT_EVENT_DESCRIPTOR_TAG:UInt8 = 0x4D
  static let EXTENDED_EVENT_DESCRIPTOR_TAG:UInt8 = 0x4E
  static let PARENTAL_RATING_DESCRIPTOR_TAG:UInt8 = 0x55
  static let CONTENT_DESCRIPTOR_TAG:UInt8 = 0x54
}

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


extension UInt8 {
  func asHexString() -> String
  {
    return  String(format: "0x%02.2x", self)
  }
}
extension UInt16 {
  func asHexString() -> String
  {
    return  String(format: "0x%02=4.4x", self)
  }
}
extension UInt32 {
  func asHexString() -> String
  {
    return  String(format: "0x%08.8x", self)
  }
}

// MARK: structures mapping model

struct EventInfomationTable {
  var EventID = ""
  var When: String = ""             // def getEitWhen(self):  return self.eit.get('when', "")
  var StartDate: String = ""        // def getEitStartDate(self):  return self.eit.get('startdate', "")
  var StartTime: String = ""        // def getEitStartTime(self):  return self.eit.get('starttime', "")
  var Duration: String = ""         // def getEitDuration(self):  return self.eit.get('duration', "")
  var Encrypted: String = ""
  var shortDescriptors:[Short_Event_Descriptor]?
  var extendedDescriptors:[Extended_Event_Descriptor]?
}

struct Short_Event_Descriptor {
  var languageCode:String?
  let tag = EITConst.SHORT_EVENT_DESCRIPTOR_TAG
  var eventName:DVBTextString?
  var eventText:DVBTextString?
  var itemLength: Int
  
  init(buffer:[UInt8]) {
    self.itemLength = buffer.count
    self.languageCode = ""
    let languageFieldLength = 3
    var startIndex:Int = 0
    var endIndex:Int = startIndex + languageFieldLength
    languageCode = String.init(bytes: buffer[startIndex..<endIndex], encoding:String.Encoding.utf8)
    let eventNameLength = Int(buffer[endIndex])
    startIndex = endIndex + 1
    endIndex = startIndex+eventNameLength
    if (eventNameLength != 0)
    {
      eventName = DVBTextString.init(bytes: [UInt8](buffer[startIndex..<endIndex]))
    }
    let eventTextLength = Int(buffer[endIndex])
    startIndex = endIndex + 1
    endIndex = startIndex+eventTextLength
    if (eventTextLength != 0) {
      eventText = DVBTextString.init(bytes: [UInt8](buffer[startIndex..<endIndex]))
    }
  }
  init()
  {
    languageCode = ""
    eventName = DVBTextString()
    eventText = DVBTextString()
    itemLength = 0
  }
}

// Table 51 ETSI EN300 468 v1.11.1

struct Extended_Event_Descriptor {
  var descriptorNumber: Int = 0         // sequence identifier
  var highestDescriptorNuber: Int = 0   // to facilitate chaining of descriptors when more than 256 bytes is required
  var languageCode:String?
  var numberOfItems = 0
  var itemCount = 0                     // provision for additional multiple "columns" of text
  var itemDescription:[Extended_Event_Descriptor_Item]?         // should be itemCount of these
  var textLength = 0
  var descriptionText:DVBTextString?
  var descriptorLength: Int = 0
  let tag = EITConst.EXTENDED_EVENT_DESCRIPTOR_TAG
  
  init(buffer:[UInt8]) {
    
    // invert byte
    var startIndex:Int = 0
    descriptorLength = buffer.count
    let t = buffer[0]
    descriptorNumber = Int(t & 0xF0) >> 4
    highestDescriptorNuber = Int(t & 0x0F)
    
    languageCode = ""
    let languageFieldLength = 3
    startIndex += 1
    var endIndex:Int = startIndex + languageFieldLength
    languageCode = String.init(bytes: buffer[startIndex..<endIndex], encoding:String.Encoding.utf8)
    
    // extract a table of items and descriptions if present
    startIndex = endIndex
    itemCount = Int(buffer[startIndex])
    if (itemCount>0) {
      itemDescription = [Extended_Event_Descriptor_Item]()
    }
    startIndex += 1
    for _ in 0..<itemCount {
      let descriptionLength = Int(buffer[startIndex])
      startIndex += 1
      endIndex = startIndex+descriptionLength
      var description : DVBTextString?
      if (descriptionLength > 0) {
        description = DVBTextString.init(bytes: [UInt8](buffer[startIndex ..< endIndex]))
      }
      startIndex = endIndex
      let itemLength = Int(buffer[startIndex])
      startIndex += 1
      endIndex = startIndex+itemLength
      var item: DVBTextString?
      if (itemLength>0) {
        item = DVBTextString.init(bytes: [UInt8](buffer[startIndex ..< endIndex]))
      }
      startIndex = endIndex
      let eventItem = Extended_Event_Descriptor_Item(description: description, item: item)
      if (itemDescription == nil)
      {
        itemDescription = [Extended_Event_Descriptor_Item]()
      }
      itemDescription!.append(eventItem)
    }
    
    // extract event description
    textLength = Int(buffer[startIndex])
    startIndex += 1
    endIndex = startIndex+textLength
    if (textLength != 0)
    {
      descriptionText = DVBTextString(bytes: [UInt8](buffer[startIndex ..< endIndex]))
    }
  }
  
  init()
  {
    languageCode = ""
    descriptionText = DVBTextString()
  }
}

struct Extended_Event_Descriptor_Item {
  var description:DVBTextString?
  var item:DVBTextString?
  var asString: String? {
    get {
      return (description?.asString)! + (item?.asString)!
    }
  }
}

// placeholder for a more complete implementation by others....
// Encoding provided for a multitable text single/double byte text display system
// for now the "existence" of the characterTable selection byte is
// acknowledged and should non-ascii table selection show up it will
// present text as "unimplemented"

struct DVBTextString
{
  var characterTable :UInt8   // optional character table byte, we only implement 0x15 utf8 (ie not cyrilic, chinese, korean.... )
  var contentText:String?
  
  init(bytes: [UInt8])
  {
    characterTable = bytes[0]
    // we handle utf8 (char table 0x15) or no char table == char table 0 == latin
    //
    if ((characterTable>=0x20 && characterTable <= 0xFF) || (characterTable == 0x15))
    {
      characterTable = (characterTable == 0x15) ? characterTable : 0x00
      let startIndex = (characterTable == 0x15) ? 1 : 0     //  0x15 == explicit utf8, else it is just text without using code table 0 - latin
      contentText = String.init(bytes: bytes[startIndex..<bytes.count], encoding: String.Encoding.utf8)
    }
    else  {
      contentText = String.init(bytes: bytes[1..<bytes.count], encoding: String.Encoding.utf8)
//      let hexCodeTable = String.init(format: "%02.2x", characterTable)
      let hexCodeTable = characterTable.asHexString()
      contentText = "Unimpl code \(hexCodeTable) raw text = \(contentText)"
    }
  }
  
  init()
  {
    characterTable = 0
    contentText = ""
  }
  
  init(characterTable charTab: UInt8, contentText content: String)
  {
    characterTable = charTab
    contentText = content
  }
  
  var asString : String? {
    get {
      return String(format:"02.2X",characterTable)+":\(contentText)"
    }
  }
}

// extract a type with given length from the blob of data
extension Data {
  /// Extract the type T which has given byte length
  /// - parameter from: starting offset in the data
  /// - parameter length: number of bytes to use for referred to type
  func decodeValue<T>(from: Int, length: Int) -> T
  {
    return self.subdata(in: from..<from+length).withUnsafeBytes{$0.pointee}
  }
  /// Extract the unsigned byte array
  /// - parameter from: starting offset in the data
  /// - parameter length: number of bytes to use for array
  func decodeByteArray(from: Int, length: Int) -> [UInt8]
  {
    return Array(self.subdata(in: from..<from+length))
  }
}

// MARK: Class Info
class EITInfo
{
  
  // MARK: Model
  var eit = EventInfomationTable()
  let debug = false
  var container: Recording?
  
  // MARK: Initializers
  /// Failable. Decode the raw data, typically from file.
  /// Empty file unacceptable.
  convenience init?(data: Data)
  {
    guard data.count != 0 else { return nil }
    self.init()
    decodeEITData(data)
  }
  
  // MARK: Support functions
  
//  /// Get a UInt8 from a Data buffer at index
//  /// - parameter from: a Data<UInt8> object to extract element from
//  /// - parameter at: starting offset in the data of the element
//  /// - returns : the element
//  func getUInt8(from rawData: Data, at index: Int) -> UInt8
//  {
//    let itemRange = Range(index ..< index+MemoryLayout<UInt8>.size)
//    return rawData.subdata(in: itemRange).withUnsafeBytes{$0.pointee}
//  }
//  
//  /// Get a UInt8 Array from a Data buffer starting at index
//  /// - parameter from: a Data<UInt8> object to extract element from
//  /// - parameter at: starting offset in the data of the element
//  /// - parameter length: size of array
//  /// - returns : the array element
//  func getUInt8Array(from rawData: Data, at index: Int, length: Int) -> [UInt8]
//  {
////    var buffer = [UInt8].init(repeating: 0, count: Int(length))
//    let itemRange = Range(index ..< index+length*MemoryLayout<UInt8>.size)
//    let buffer:[UInt8] =  Array(rawData.subdata(in: itemRange))
//    return buffer
//  }
//  
//  /// Get a UInt16 from a Data buffer at index
//  /// - parameter from: a Data<UInt8> object to extract element from
//  /// - parameter at: starting offset in the data of the element
//  /// - returns : the element
//  func getUInt16(from rawData: Data, at index: Int) -> UInt16
//  {
//    let itemRange = Range(index ..< index+MemoryLayout<UInt16>.size)
//    return rawData.subdata(in: itemRange).withUnsafeBytes{$0.pointee}
//  }
//  
  
  /// Decode the raw data into the workable structures
  func decodeEITData(_ rawData: Data)
  {
    let uInt16Size = MemoryLayout<UInt16>.size
    let uInt8Size = MemoryLayout<UInt8>.size
    
    // nibble through the data buffer and populate structures
    
    // decode first 12 bytes bigEndian
    // two shorts, 6 chars, 1 short
    var start = 0
    var eventID:UInt16 = 0
    eventID = rawData.decodeValue(from: start, length: uInt16Size)
    start += uInt16Size
    
    var eventDate:UInt16 = 0
    eventDate = rawData.decodeValue(from: start, length: uInt16Size)
    start += uInt16Size
    if (debug) {
      print("eventID \(eventID) bigEndian \(eventID.bigEndian)")
    }
    
    eit.EventID = "\(eventID)"
    //        print("eventDate \(eventDate) bigEndian \(eventDate.bigEndian)")
    // decode date
    let MJD = parseMJD(eventDate.bigEndian)
    //        print("decoded event Date \(MJD.year)/\(MJD.month)/\(MJD.day)")
    
    // decode time HH MM SS
    var temp :UInt8 = 0
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventTimeHH = unBCD(temp)
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventTimeMM = unBCD(temp)
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventTimeSS = unBCD(temp)
    //        print("Event start time \(eventTimeHH):\(eventTimeMM):\(eventTimeSS) UTC")
    let datetimeString = String.init(format: "%4.4d-%02.2d-%02.2d %02d:%02d:%02d",
                                     MJD.year, MJD.month, MJD.day, eventTimeHH, eventTimeMM, eventTimeSS)
    
    // having picked the bits apart, build an internal datetime representation,
    // note that the file internal date time is GMT based, so we need to convert it to
    // local time
    
    let dateCreator = DateFormatter()
    dateCreator.timeZone = TimeZone(abbreviation: "UTC")
    dateCreator.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let startDateTime = dateCreator.date(from: datetimeString)
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = DateFormatter.Style.medium
    dateFormatter.timeStyle = DateFormatter.Style.medium
    dateFormatter.timeZone = TimeZone.ReferenceType.local
    //        let localDateTime = dateFormatter.stringFromDate(startDateTime!)
    //        print("Even start local: \(localDateTime)")
    dateFormatter.dateFormat = "dd MMM yyyy"
    eit.StartDate = dateFormatter.string(from: startDateTime!)
    dateFormatter.dateFormat = "h:mm:ss a zzz"
    eit.StartTime = dateFormatter.string(from: startDateTime!)
    if (debug) { print("Start Date \(eit.StartDate) Start Time \(eit.StartTime)") }
    
    // decode duration HH MM SS
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventDurationHH = unBCD(temp)
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventDurationMM = unBCD(temp)
    
    temp = rawData.decodeValue(from: start, length: uInt8Size)
    start += uInt8Size
    let eventDurationSS = unBCD(temp)
    eit.Duration = String(format:"%2.2d:%02.2d:%02.2d",eventDurationHH, eventDurationMM, eventDurationSS)
    //        print("Event Duration time \(eventDurationHH):\(eventDurationMM):\(eventDurationSS)")
    //        print (eit.Duration)
    
    // pull the next short apart for status, encryption and descriptor block length
    var statusShort : UInt16 = 0
    statusShort = rawData.decodeValue(from: start, length: uInt16Size)
    start += uInt16Size
    //        let shortText = String.init(format: "%08.8x", statusShort.bigEndian)
    //        print(shortText)
    
    // top 3 bits
    statusShort = statusShort.bigEndian
    //      let p1 = (statusShort & 0xE000)
    //      let p2 = p1 >> 13
    var runningStatus = Int((statusShort & 0xE000) >> 13)
    // bounds control
    let status = ["Recording", "not running", "starts in a few seconds", "pausing", "running", "service off air", "reserved for future 6", "reserved for future 7"]
    runningStatus = (runningStatus>=0 && runningStatus<status.count) ? runningStatus : 0
    
    //        print("running status \(runningStatus)")
    //        print("status meaning is \(status[runningStatus])")
    eit.When = status[runningStatus]
    
    let isEncrypted = ((statusShort & 0x1000) > 0)
    //        print(" is encrypted = \(isEncrypted)")
    eit.Encrypted = "\(isEncrypted)"
    
    // bottom 12 bits
    let descriptorLength = Int(statusShort & 0x0FFF)
    //        print("balance of data length = \(descriptorLength)")
    
    // nibble the rest of the record apart
    // it is a sequences of descriptor tag, followed by a descriptor length (bytes)
    // and then the bytes of the descriptor
    // repeat until all the data is decoded
    
    // we only see 0x4d and 0x4e tags currently
    
    //      let blockLength = (foundData?.length)!
    var blockIndex = 0
    while blockIndex < descriptorLength {
      var index = start+blockIndex
      //      while index < blockLength {
      // next a tag - descriptor type
      
      temp = rawData.decodeValue(from: index, length: uInt8Size)
      index += uInt8Size
      let tag = temp
      
      // next the descriptor item length

      temp = rawData.decodeValue(from: index, length: uInt8Size)
      index += uInt8Size
      let itemLength = Int(temp)
      
      let buffer = rawData.decodeByteArray(from: index, length: itemLength)
      blockIndex += Int(itemLength) + 2*uInt8Size  // allow for bytecount of tag, itemLength and item
      if (tag == EITConst.SHORT_EVENT_DESCRIPTOR_TAG) {
        let shortEventDescriptor = Short_Event_Descriptor.init(buffer: buffer)
        if (eit.shortDescriptors == nil ) {
          eit.shortDescriptors = [Short_Event_Descriptor]()
        }
        eit.shortDescriptors?.append(shortEventDescriptor)
      } else if (tag == EITConst.EXTENDED_EVENT_DESCRIPTOR_TAG ) {
        let extendedEventDescriptor = Extended_Event_Descriptor.init(buffer: buffer)
        if (eit.extendedDescriptors == nil ) {
          eit.extendedDescriptors = [Extended_Event_Descriptor]()
        }
        eit.extendedDescriptors?.append(extendedEventDescriptor)
      }
    }
//    print(self.description())
  }
  
  // MARK: Accessor Functions
  
  // Note is would look like both then eventName (program name) and episode title
  // could be easily packed into the one short descriptor.  
  // However from the recording that I have it appears that two decriptors are
  // used.  The first for the program name, the second for the episode title
  // It is unknown
  // if this is "Engima" or "BeyonWiz" peculiartiy.  As I only have BeyonWiz
  // recordings.  I work with that apparent convention
  
  /// nominally pick out the eventName field of the first short descriptor
  /// return: program name as text
  func programNameText() -> String
  {
    var program = ""
    if (self.eit.shortDescriptors != nil)
    {
      // seems no rational basis for eventName vs eventText being
      // populated.  Try the second if the first is nil
      if let text = self.eit.shortDescriptors![0].eventName
      {
        program = text.contentText!
      }
      else {
        if let text = self.eit.shortDescriptors![0].eventText
        {
          program = text.contentText!
        }
      }
    }
    return program
  }
  
  /// nominally pick out the eventText field of the second short descriptor
  /// return : episode text
  func episodeText() -> String
  {
    var title = ""
    if (self.eit.shortDescriptors?.count>=2)
    {
      if let text = self.eit.shortDescriptors![1].eventText {
        title = text.contentText!
      }
      else { // try eventName
        if let text = self.eit.shortDescriptors![1].eventName {
          title = text.contentText!
        }
      }
    }
    return title
  }
  
  /// Returns a single string with the concatentated contents
  /// of all the extendedDescriptors
  /// - returns: text or empty string if no extendedDescriptors
  func descriptionText() -> String
  {
    var description = ""
    if let extendedDescriptorArray = self.eit.extendedDescriptors
    {
      for item in extendedDescriptorArray {
        if let contentText = item.descriptionText?.contentText
        {
         description.append(contentText)
        }
      }
    }
    return description
  }
  
  /// Return contents of EIT in ordered printable form
  /// - returns: multiline string
  func description() -> String
  {
    let d1 = "EventID        : \(eit.EventID)\n"
    let d2 = "Type of Event  : \(eit.When)\n"
    let d3 = "Start Date     : \(eit.StartDate)\n"
    let d4 = "Start Time     : \(eit.StartTime)\n"
    let d5 = "Duration of Rec: \(eit.Duration)\n"
    let d6 = "Encrypted Rec  : \(eit.Encrypted)\n"
    let d7 = "ShortEventDescriptors:\n"
    var d8 = "<none>"
    if let shortDescArray = eit.shortDescriptors
    {
      d8 = ""
      for item in shortDescArray
      {
        let sdn = (item.eventName == nil) ? "nil" : item.eventName!.contentText!
        let sdt = (item.eventText == nil) ? "nil" : item.eventText!.contentText!
        let sdl = (item.languageCode == nil) ? "nil" : item.languageCode!
        d8.append("  Event Name :" + sdn + "\n")
        d8.append("  Event Text :" + sdt + "\n")
        d8.append("  Lang Code  :" + sdl + "\n")
      }
    }
    let d9 = "LongEventDescriptors:\n"
    var d10 = "<none>"
    if let extendedDescArray = eit.extendedDescriptors
    {
      d10 = ""
      for entry in extendedDescArray
      {
        let entryNumber = entry.descriptorNumber+1
        let lastNumber = entry.highestDescriptorNuber+1
        let sequence = "\(entryNumber) of \(lastNumber)\n"
        d10.append("Entry Number "+sequence)
        let sdl = (entry.languageCode == nil) ? "nil" : entry.languageCode!
        d10.append("  Lang Code   :" + sdl + "\n")
        // process item list
        let itemCount = entry.itemCount
        d10.append("  No. of Event Items: \(itemCount)\n")
        for itemIndex in 0..<itemCount
        {
          let item = entry.itemDescription![itemIndex]
          let itemDescription = item.description!.contentText!
          let itemContent = item.item!.contentText!
          d10.append("    \(itemDescription):\(itemContent)")
        }
        let sdt = (entry.descriptionText == nil) ? "nil" : entry.descriptionText!.contentText!
        d10.append("  Event Text  :" + sdt + "\n")
      }
    }
    return d1+d2+d3+d4+d5+d6+d7+d8+d9+d10
  }
}

// MARK: support decoders

/// unpack with "ETSI" "Modified Julian Date" algorithm
/// - parameter packed: 16 bit packed date
/// - return: touple of year, month, day as Ints
func parseMJD(_ packed:UInt16) -> (year:Int, month:Int, day:Int)
{
  let packedDate = Double(packed)
  let YY = Int((packedDate - 15078.2)/365.25)
  let yearFactor = trunc(Double(YY)*365.25)
  let MM = Int((packedDate - 14956.1 - yearFactor) / 30.6001)
  let K = (MM == 14 || MM == 15) ? 1 : 0
  let monthFactor = UInt16(Double(MM)*30.6001)
  let D = packed - UInt16(14956) - UInt16(yearFactor) - monthFactor
  return ((1900+YY+K),(MM-1-K*12),Int(D))
}

/// extract Values from BCD packing
/// - parameter byte: 8 bit Unsigned value
/// - returns : unpacked value as Int
func unBCD(_ byte:UInt8) -> Int
{
  var digit = 0
  digit = Int(byte>>4)*10 + Int(byte & 0xF)
  //    print(String.init(format: "%0.2X:%d", byte, digit))
  return digit
}

/// debugging hex print of buffer
/// - parameter: array of unsigned bytes
func decodeDescriptor(_ buffer:[UInt8])
{
  for i in 0 ..< (buffer.count)
  {
    var oneChar: UInt8 = 0
    oneChar = buffer[i]
//    let hexString = String(format: ">>%0.2X<<", oneChar)
    let hexString = oneChar.asHexString()
    let terminator = ((i+1)%16==0) ? "\n":""
    print("\(hexString) ", terminator:terminator)
  }
  print("\n")
}
