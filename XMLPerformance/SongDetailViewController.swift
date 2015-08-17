//
//  SongDetailViewController.swift
//  XMLPerformance
//
//  Created by David Francis on 7/27/15.
//  Copyright (c) 2015 FTS InfoTech, LLC. All rights reserved.
//

import UIKit

class SongDetailViewController: UITableViewController {
    
    var song: Song? {
        didSet {
            // When the song changes, update the navigation item title
            title = song?.title
        }
    }
    
    
    var dateFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .NoStyle
        return formatter
    }
    
    
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SongDetailCell", forIndexPath: indexPath)
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = NSLocalizedString("album", comment: "album label")
            cell.detailTextLabel!.text = song?.album
        case 1:
            cell.textLabel!.text = NSLocalizedString("artist", comment: "artist label")
            cell.detailTextLabel!.text = song?.artist
        case 2:
            cell.textLabel!.text = NSLocalizedString("category", comment: "category label")
            cell.detailTextLabel!.text = song?.category
        case 3:
            cell.textLabel!.text = NSLocalizedString("released", comment: "released label")
            cell.detailTextLabel!.text = ""
            if let date = song?.releaseDate {
                cell.detailTextLabel!.text = dateFormatter.stringFromDate(date)
            }
        default:
            break
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Song details:", comment: "Song details label")
    }
}
