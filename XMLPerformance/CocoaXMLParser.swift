//
//  CocoaXMLParser.swift
//  XMLPerformance
//
//  Copyright (c) 2015 FTS InfoTech, LLC.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

class CocoaXMLParser: iTunesRSSParser, NSXMLParserDelegate {
    var currentString: String?
    var currentSong: Song?
    var storingCharacters = false
    var parseFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.LongStyle
        formatter.timeStyle = NSDateFormatterStyle.NoStyle
        
        // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
        // the date formatter must be set to US locale in order to parse the dates
        formatter.locale = NSLocale(localeIdentifier: "US")
        return formatter
    }
    
    var xmlData: NSMutableData?
    var done = false
    var rssConnection: NSURLConnection?
    
    
    override class func parserName() -> String {
        return "NSXMLParser"
    }
    
    override class var parserType: XMLParserType {
        return .NSXMLParser
    }

    override func downloadAndParse(url: NSURL) {
        done = false
        
        xmlData = NSMutableData()
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        let theRequest = NSURLRequest(URL: url)
        
        // create the connection with the request and start loading the data
        rssConnection = NSURLConnection(request: theRequest, delegate: self)
        dispatch_async(dispatch_get_main_queue()) {
            self .downloadStarted()
        }
        
        if rssConnection != nil {
            repeat {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() )
            } while !done
        }
        
        rssConnection = nil
        currentSong = nil
    }
    
    // :MARK - NSURLConnection Delegate methods
    
    /*
    Disable caching so that each time we run this app we are starting with a clean slate.
    You may not want to do this in your application.
    */
    func connection(connection: NSURLConnection, willCacheResponse cachedResponse: NSCachedURLResponse) -> NSCachedURLResponse? {
        return nil
    }
    
    // Forward errors to the delegate
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        done = true
        dispatch_async(dispatch_get_main_queue()) {
            self .parseError(error)
        }
    }
    
    // Called when a chunk of data has been downloaded.
   func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        // Append the downloaded chunk of data.
        xmlData?.appendData(data)
    }
 
    func connectionDidFinishLoading(connection: NSURLConnection) {
        dispatch_async(dispatch_get_main_queue()) {
            self.downloadEnded()
        }
        
        let parser = NSXMLParser(data: xmlData!)
        parser.delegate = self
        
        currentString = ""
        
        let start = NSDate.timeIntervalSinceReferenceDate()
        parser.parse()
        let duration = NSDate.timeIntervalSinceReferenceDate() - start
        
        dispatch_async(dispatch_get_main_queue()) {
            self.addToParseDuration(duration)
            self.parseEnded()
        }
        
        currentString = nil
        xmlData = nil
        
        // Set the condition which ends the run loop.
        done = true
    }

    
    // :MARK - Parsing support methods
    
    func finishedCurrentSong() {
        // dispatch_async will not retain the self.currentSong so we add a reference to it with if let
        if let currentSong = self.currentSong {
            dispatch_async(dispatch_get_main_queue()) {
                self.parsedSong(currentSong)
            }
        }
        self.currentSong = nil
    }
    
    
    // :MARK - NSXMLParser Parsing Callbacks

    // Constants for the XML element names that will be considered during the parse.
    // Declaring these as static constants reduces the number of objects created during the run
    // and is less prone to programmer error.
    //
    private let itemName = "item"
    private let titleName = "title"
    private let categoryName = "category"
    private let artistName = "itms:artist"
    private let albumName = "itms:album"
    private let releaseDateName = "itms:releasedate"

    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == itemName {
            currentSong = Song()
        } else if elementName == titleName || elementName == categoryName || elementName == artistName || elementName == albumName || elementName == releaseDateName {
            currentString = ""
            storingCharacters = true
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == itemName {
            finishedCurrentSong()
        } else if elementName == titleName {
            currentSong?.title = currentString
        } else if elementName == categoryName {
            currentSong?.category = currentString
        } else if elementName == artistName {
            currentSong?.artist = currentString
        } else if elementName == albumName {
            currentSong?.album = currentString
        } else if elementName == releaseDateName {
            currentSong?.releaseDate = parseFormatter.dateFromString(currentString!)
        }
        storingCharacters = false
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String) {
        if storingCharacters {
            currentString = currentString! + string
        }
    }
    
    /*
    A production application should include robust error handling as part of its parsing implementation.
    The specifics of how errors are handled depends on the application.
    */
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        // Handle errors as appropriate for your application.
    }
    
}

