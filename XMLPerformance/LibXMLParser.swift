//
//  LibXMLParser.swift
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

// This approach to parsing uses NSURLConnection to asychronously retrieve the XML data. libxml's SAX parsing supports chunked parsing, with no requirement for the chunks to be discrete blocks of well formed XML. The primary purpose of this class is to start the download, configure the parser with a set of C callback functions, and pass downloaded data to it. In addition, the class maintains a number of state variables for the parsing.
class LibXMLParser : iTunesRSSParser {
    
    // Reference to the libxml parser context
    var context: xmlParserCtxtPtr?
    var rssConnection: NSURLConnection?
    
    // State variable used to determine whether or not to ignore a given XML element
    var done = false

    // The following state variables deal with getting character data from XML elements. This is a potentially expensive
    // operation. The character data in a given element may be delivered over the course of multiple callbacks, so that
    // data must be appended to a buffer. The optimal way of doing this is to use a C string buffer that grows exponentially.
    // When all the characters have been delivered, an NSString is constructed and the buffer is reset.
    var storingCharacters = false
    var characterBuffer = NSMutableData()
    
    // A reference to the current song the parser is working with.
    var currentSong: Song?
    var parsingASong = false
    
    var parseFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.LongStyle
        formatter.timeStyle = NSDateFormatterStyle.NoStyle
        
        // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
        // the date formatter must be set to US locale in order to parse the dates
        formatter.locale = NSLocale(localeIdentifier: "US")
        return formatter
    }
    
    private var currentString : String {
        // Create a string with the character data using UTF-8 encoding. UTF-8 is the default XML data encoding.
        let currentString = NSString(data: characterBuffer, encoding: NSUTF8StringEncoding)! as String
        characterBuffer.length = 0
        return currentString
    }

    override class func parserName() -> String {
        return "libxml2"
    }
    
    override class var parserType: XMLParserType {
        return .LibXMLParser
    }
    
    /*
    This method is called on a secondary thread by the superclass. We have asynchronous work to do here with downloading and parsing data, so we will need a run loop to prevent the thread from exiting before we are finished.
    */
    override func downloadAndParse(url: NSURL) {
        done = false

        characterBuffer.length = 0
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        let theRequest = NSURLRequest(URL: url)
        
        // create the connection with the request and start loading the data
        rssConnection = NSURLConnection(request: theRequest, delegate: self)

        // This creates a context for "push" parsing in which chunks of data that are not "well balanced" can be passed
        // to the context for streaming parsing. The handler structure defined above will be used for all the parsing.
        // The second argument, self, will be passed as user data to each of the SAX handlers. The last three arguments
        // are left blank to avoid creating a tree in memory.
        // Reference: http://stackoverflow.com/questions/30786883/swift-2-unsafemutablepointervoid-to-object
        context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque())
            , nil, 0, nil)

        dispatch_async(dispatch_get_main_queue()) {
            self .downloadStarted()
        }
        
        if rssConnection != nil {
            repeat {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() )
            } while !done
        }
        
        xmlFreeParserCtxt(context!)
        context = nil
        characterBuffer.length = 0
        rssConnection = nil
        currentSong = nil
    }
    
    // :MARK - NSURLConnection Delegate methods
    
    /*
    Disable caching so that each time we run this app we are starting with a clean slate. You may not want to do this in your application.
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
        let start = NSDate.timeIntervalSinceReferenceDate()
        
        // Process the downloaded chunk of data.
        xmlParseChunk(context!, UnsafePointer<CChar>(data.bytes), CInt(data.length), CInt(0));
        
        let duration = NSDate.timeIntervalSinceReferenceDate() -  start
        dispatch_async(dispatch_get_main_queue()) {
            self .addToParseDuration(duration)
        }
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        dispatch_async(dispatch_get_main_queue()) {
            self.downloadEnded()
        }
        
        let start = NSDate.timeIntervalSinceReferenceDate()
    
        // Signal the context that parsing is complete by passing "1" as the last parameter.
        xmlParseChunk(context!, nil, 0, 1)
        
        let duration = NSDate.timeIntervalSinceReferenceDate() -  start
        dispatch_async(dispatch_get_main_queue()) {
            self.addToParseDuration(duration)
            self.parseEnded()
        }
        
        // Set the condition which ends the run loop.
        done = true
    }

    /*
    Character data is appended to a buffer until the current element ends.
    */
    func appendCharacters(charactersFound: UnsafePointer<xmlChar>, length:Int32) {
        characterBuffer.appendBytes(UnsafePointer<Void>(charactersFound), length: Int(length))
    }
    
    func finishedCurrentSong() {
        
        // dispatch_async will not retain the self.currentSong so we add a reference to it with if let
        if let currentSong = self.currentSong {
            dispatch_async(dispatch_get_main_queue()) {
                self.parsedSong(currentSong)
            }
        }
        self.currentSong = nil
    }
}


// The following constants are the XML element names.
private let itemName = "item"
private let titleName = "title"
private let categoryName = "category"
private let itmsName = "itms"
private let artistName = "artist"
private let albumName = "album"
private let releaseDateName = "releasedate"

/*
This callback is invoked when the parser finds the beginning of a node in the XML. For this application,
out parsing needs are relatively modest - we need only match the node name. An "item" node is a record of
data about a song. In that case we create a new Song object. The other nodes of interest are several of the
child nodes of the Song currently being parsed. For those nodes we want to accumulate the character data
in a buffer. Some of the child nodes use a namespace prefix.
*/
// Reference: http://stackoverflow.com/questions/31311166/swift-unsafemutablepointer-unsafemutablepointerunsafepointersometype
private func startElementSAX(ctx: UnsafeMutablePointer<Void>, name: UnsafePointer<xmlChar>, prefix: UnsafePointer<xmlChar>, URI: UnsafePointer<xmlChar>, nb_namespaces: CInt, namespaces: UnsafeMutablePointer<UnsafePointer<xmlChar>>, nb_attributes: CInt, nb_defaulted: CInt, attributes: UnsafeMutablePointer<UnsafePointer<xmlChar>>) {
        
        let parser = Unmanaged<LibXMLParser>.fromOpaque(COpaquePointer(ctx)).takeUnretainedValue()
    
        // Convert the name param to a Swift String 'localName'
        let cString = UnsafePointer<CChar>(name)
        let localName = String.fromCString(cString)
    
        if prefix == nil && localName == itemName {
            let newSong = Song()
            parser.currentSong = newSong
            parser.parsingASong = true
        } else if parser.parsingASong {
            if prefix == nil {
                if localName == titleName || localName == categoryName {
                    parser.storingCharacters = true
                }
            } else {
                let cString = UnsafePointer<CChar>(prefix)
                let localPrefix = String.fromCString(cString)
                if localPrefix == itmsName {
                    if localName == artistName || localName == albumName || localName == releaseDateName {
                        parser.storingCharacters = true
                    }
                }
                
            }
        }
}


/*
This callback is invoked when the parse reaches the end of a node. At that point we finish processing that node,
if it is of interest to us. For "item" nodes, that means we have completed parsing a Song object. We pass the song
to a method in the superclass which will eventually deliver it to the delegate. For the other nodes we
care about, this means we have all the character data. The next step is to create an NSString using the buffer
contents and store that with the current Song object.
*/
private func endElementSAX(ctx: UnsafeMutablePointer<Void>,
    name: UnsafePointer<xmlChar>,
    prefix: UnsafePointer<xmlChar>,
    URI: UnsafePointer<xmlChar>) {
        
        let parser = Unmanaged<LibXMLParser>.fromOpaque(COpaquePointer(ctx)).takeUnretainedValue()
        guard parser.parsingASong else {
            return
        }
        
        let cString = UnsafePointer<CChar>(name)
        let localName = String.fromCString(cString)

        if prefix == nil {
            if localName == itemName {
                parser.finishedCurrentSong()
                parser.parsingASong = false
            } else if localName == titleName {
                parser.currentSong?.title = parser.currentString
            } else if localName == categoryName {
                parser.currentSong?.category = parser.currentString
            }
        } else {
            let cString = UnsafePointer<CChar>(prefix)
            let localPrefix = String.fromCString(cString)
            if localPrefix == itmsName {
                if localName == artistName {
                    parser.currentSong?.artist = parser.currentString
                } else if localName == albumName {
                    parser.currentSong?.album = parser.currentString
                } else if localName == releaseDateName {
                    let dateString = parser.currentString
                    parser.currentSong?.releaseDate = parser.parseFormatter.dateFromString(dateString)
                }
            }
        }
        parser.storingCharacters = false
}


/*
This callback is invoked when the parser encounters character data inside a node. The parser class determines how to use the character data.
*/
private func charactersFoundSAX(ctx: UnsafeMutablePointer<Void>, ch: UnsafePointer<xmlChar>, len: CInt) {
    
    // Cast the ctx back to a LibXMLParser
    let parser = Unmanaged<LibXMLParser>.fromOpaque(COpaquePointer(ctx)).takeUnretainedValue()

    // A state variable, "storingCharacters", is set when nodes of interest begin and end.
    // This determines whether character data is handled or ignored.
    guard parser.storingCharacters else {
        return
    }
    parser.appendCharacters(ch, length: len)
}


/*
A production application should include robust error handling as part of its parsing implementation.
The specifics of how errors are handled depends on the application.
*/
private func errorEncounteredSAX(ctx: UnsafeMutablePointer<Void>, msg: UnsafePointer<CChar>...) {
    // Handle errors as appropriate for your application.
    assertionFailure("Unhandled error encountered during SAX parse.")
}


// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
var simpleSAXHandlerStruct : xmlSAXHandler = {
    
    // It appears struct is initialized to zeros by default, so no need to set each unused member to nil
    var handler = xmlSAXHandler()

    handler.characters = charactersFoundSAX
    // TBD, TODO - How to deal with variadic parameters in C?
//    handler.error = errorEncounteredSAX
    handler.initialized = XML_SAX2_MAGIC
    handler.startElementNs = startElementSAX
    handler.endElementNs = endElementSAX
    
    return handler
}()


