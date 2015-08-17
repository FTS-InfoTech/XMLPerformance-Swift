//
//  iTunesRSSParser.swift
//  XMLPerformance
//
//  Created by David Francis on 7/27/15.
//  Copyright (c) 2015 FTS InfoTech, LLC. All rights reserved.
//

import UIKit

enum XMLParserType: Int {
    case Abstract      = -1
    case NSXMLParser
    case LibXMLParser
}

// Protocol for the parser to communicate with its delegate.
@objc protocol iTunesRSSParserDelegate: NSObjectProtocol {
    
    // Called by the parser when parsing is finished.
    optional func parserDidEndParsingData(parser: iTunesRSSParser)

    // Called by the parser in the case of an error.
    optional func parser(parser: iTunesRSSParser, didFailWithError: NSError)
    
    // Called by the parser when one or more songs have been parsed. This method may be called multiple times.
    optional func parser(parser: iTunesRSSParser, didParseSongs parsedSongs: [AnyObject]!)
}


class iTunesRSSParser: NSObject {
    private let countForNotification = 10
    
    var delegate: iTunesRSSParserDelegate?
    
    var parsedSongs = [Song]()

    // This time interval is used to measure the overall time the parser takes to download and parse XML.
    var startTimeReference: NSTimeInterval?
    var downloadStartTimeReference: NSTimeInterval?
    
    var parseDuration: NSTimeInterval = 0
    var downloadDuration: NSTimeInterval = 0
    var totalDuration: NSTimeInterval = 0
    
    class func parserName() -> String {
        assertionFailure("Class method parserName not valid for abstract base class iTunesRSSParser")
        return "Base Class"
    }
    
    class var parserType: XMLParserType {
        assertionFailure("Class method parserType not valid for abstract base class iTunesRSSParser")
        return .Abstract
    }
    
    func start() {
        startTimeReference = NSDate.timeIntervalSinceReferenceDate()
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        parsedSongs = [Song]()
        let url = NSURL(string: "http://ax.phobos.apple.com.edgesuite.net/WebObjects/MZStore.woa/wpa/MRSS/newreleases/limit=300/rss.xml")
        NSThread.detachNewThreadSelector("downloadAndParse:", toTarget: self, withObject: url)
    }
    
    // Subclasses must implement this method. It will be invoked on a secondary thread to keep the application responsive.
    // Although NSURLConnection is inherently asynchronous, the parsing can be quite CPU intensive on the device, so
    // the user interface can be kept responsive by moving that work off the main thread. This does create additional
    // complexity, as any code which interacts with the UI must then do so in a thread-safe manner.
    func downloadAndParse(url: NSURL) {
        assertionFailure("Object is of abstract base class iTunesRSSParser")
    }

    
    // Subclasses should invoke these methods and let the superclass manage communication with the delegate.
    // Each of these methods must be invoked on the main thread.
    func downloadStarted() {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        downloadStartTimeReference = NSDate.timeIntervalSinceReferenceDate()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    func downloadEnded() {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        let duration = NSDate.timeIntervalSinceReferenceDate() - downloadStartTimeReference!
        downloadDuration += duration
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
    
    func parseEnded() {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        
        if parsedSongs.count > 0 {
            delegate?.parser?(self, didParseSongs: parsedSongs)
        }
        
        parsedSongs.removeAll()
        
        delegate?.parserDidEndParsingData?(self)
        
        let duration = NSDate.timeIntervalSinceReferenceDate() - startTimeReference!
        totalDuration = duration
        
        WriteStatisticToDatabase(self.dynamicType.parserType, downloadDuration, parseDuration, totalDuration);
    }
    
    func parsedSong(song: Song) {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        parsedSongs.append(song)
        if parsedSongs.count > countForNotification {
            delegate?.parser?(self, didParseSongs: parsedSongs)
            parsedSongs.removeAll()
        }
    }
    
    func parseError(error: NSError) {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        delegate?.parser?(self, didFailWithError:error)
    }
    
    func addToParseDuration(duration: NSTimeInterval) {
        assert(NSThread.isMainThread(), "\(__FUNCTION__) at line \(__LINE__) called on secondary thread")
        parseDuration += duration
    }
}