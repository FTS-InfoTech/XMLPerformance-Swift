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

class CocoaXMLParser: iTunesRSSParser, XMLParserDelegate {
    var currentString: String?
    var currentSong: Song?
    var storingCharacters = false
    var parseFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = DateFormatter.Style.none
        
        // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
        // the date formatter must be set to US locale in order to parse the dates
        formatter.locale = Locale(identifier: "US")
        return formatter
    }
    
    var xmlData: NSMutableData?
    var done = false
    var rssConnection: NSURLConnection?
    
    
    override class func parserName() -> String {
        return "NSXMLParser"
    }
    
    override class var parserType: XMLParserType {
        return .nsxmlParser
    }
    
    func startDownload(_ url: URL) {
        let request = NSURLRequest(url: url)
        
    }
    
    override func downloadAndParse(_ url: NSURL) {
        done = false
        
        xmlData = NSMutableData()
        URLCache.shared.removeAllCachedResponses()
        let theRequest = NSURLRequest(url: url as URL)
        
        // create the connection with the request and start loading the data
        rssConnection = NSURLConnection(request: theRequest as URLRequest, delegate: self)
        DispatchQueue.main.async {
            self .downloadStarted()
        }
        
        if rssConnection != nil {
            repeat {
                RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate.distantFuture )
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
    func connection(_ connection: NSURLConnection, willCacheResponse cachedResponse: CachedURLResponse) -> CachedURLResponse? {
        return nil
    }
    
    // Forward errors to the delegate
    func connection(_ connection: NSURLConnection, didFailWithError error: NSError) {
        done = true
        DispatchQueue.main.async {
            self .parseError(error)
        }
    }
    
    // Called when a chunk of data has been downloaded.
   func connection(_ connection: NSURLConnection, didReceiveData data: NSData) {
        // Append the downloaded chunk of data.
        xmlData?.append(data as Data)
    }
 
    func connectionDidFinishLoading(_ connection: NSURLConnection) {
        DispatchQueue.main.async {
            self.downloadEnded()
        }
        
        let parser = XMLParser(data: xmlData! as Data)
        parser.delegate = self
        
        currentString = ""
        
        let start = NSDate.timeIntervalSinceReferenceDate
        parser.parse()
        let duration = NSDate.timeIntervalSinceReferenceDate - start
        
        DispatchQueue.main.async {
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
            DispatchQueue.main.async {
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
    fileprivate let itemName = "item"
    fileprivate let titleName = "title"
    fileprivate let categoryName = "category"
    fileprivate let artistName = "itms:artist"
    fileprivate let albumName = "itms:album"
    fileprivate let releaseDateName = "itms:releasedate"

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == itemName {
            currentSong = Song()
        } else if elementName == titleName || elementName == categoryName || elementName == artistName || elementName == albumName || elementName == releaseDateName {
            currentString = ""
            storingCharacters = true
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
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
            currentSong?.releaseDate = parseFormatter.date(from: currentString!)
        }
        storingCharacters = false
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if storingCharacters {
            currentString = currentString! + string
        }
    }
    
    /*
    A production application should include robust error handling as part of its parsing implementation.
    The specifics of how errors are handled depends on the application.
    */
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Handle errors as appropriate for your application.
    }
    
}

