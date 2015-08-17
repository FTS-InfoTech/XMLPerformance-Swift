//
//  SongsViewController.swift
//  XMLPerformance
//
//  Created by David Francis on 7/27/15.
//  Copyright (c) 2015 FTS InfoTech, LLC. All rights reserved.
//

import UIKit

class SongsViewController: UITableViewController, iTunesRSSParserDelegate {

    var songs = [Song]()
    
    private var parser: iTunesRSSParser?
    
    var parserType: XMLParserType? {
        didSet {
            self.title = NSLocalizedString("Getting Top Songs...", comment: "Waiting for first results label")
            
            if let parserType = self.parserType {
                switch parserType {
                case .NSXMLParser:
                    parser = CocoaXMLParser()
                case .LibXMLParser:
                    parser = LibXMLParser()
                default:
                    break
                }
                
                parser?.delegate = self
                parser?.start()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        let selectedIndexPath = tableView.indexPathForSelectedRow
        if let indexPath = selectedIndexPath {
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowSongDetail" {
            let songDetailViewController = segue.destinationViewController as! SongDetailViewController
            if let indexPath = tableView.indexPathForSelectedRow {
                songDetailViewController.song = songs[indexPath.row]
            }
        }
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) 
        
        let song = songs[indexPath.row]
        cell.textLabel!.text = song.title
        return cell
    }
    
    func parserDidEndParsingData(parser: iTunesRSSParser) {
        title = String(format: NSLocalizedString("Top %d Songs", comment: "Top Songs format"), songs.count)
        tableView.reloadData()
        navigationItem.rightBarButtonItem?.enabled = true
        self.parser = nil
    }
    
    func parser(parser: iTunesRSSParser, didParseSongs parsedSongs: [AnyObject]!) {
        songs += parsedSongs as! [Song]
        
        // Three scroll view properties are checked to keep the user interface smooth during parse. When new objects are delivered by the parser, the table view is reloaded to display them. If the table is reloaded while the user is scrolling, this can result in eratic behavior. dragging, tracking, and decelerating can be checked for this purpose. When the parser finishes, reloadData will be called in parserDidEndParsingData:, guaranteeing that all data will ultimately be displayed even if reloadData is not called in this method because of user interaction.
        if !tableView.dragging && !tableView.tracking && !tableView.decelerating {
            title = String(format: NSLocalizedString("Top %d Songs", comment: "Top Songs format"), songs.count)
            tableView.reloadData()
        }
    }
    
    func parser(parser: iTunesRSSParser, didFailWithError: NSError) {
        // handle errors as appropriate to your application...
    }    
}
