//
//  ParserChoiceViewController.swift
//  XMLPerformance
//
//  Created by David Francis on 7/27/15.
//  Copyright (c) 2015 FTS InfoTech, LLC. All rights reserved.
//

import UIKit

class ParserChoiceViewController: UITableViewController {
    
    var parserSelection: NSIndexPath = NSIndexPath(forRow: 0, inSection: 0)

    // When the parsing is finished, the user can return to the ParserChoiceViewController by
    // touching the Done button which will trigger the exit segue associated with this action.
    @IBAction func doneWithSongs(segue: UIStoryboardSegue) {
        
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowSongs" {
            let navController = segue.destinationViewController as! UINavigationController
            let songsViewController = navController.topViewController as! SongsViewController
            songsViewController.parserType = XMLParserType(rawValue: self.parserSelection.row)
        }
    }

    // MARK: - Table View
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
        
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = CocoaXMLParser.parserName()
        case 1:
            cell.textLabel!.text = LibXMLParser.parserName()
        default:
            break
        }
        
        cell.accessoryType = indexPath.isEqual(parserSelection) ? UITableViewCellAccessoryType.Checkmark : UITableViewCellAccessoryType.None
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.parserSelection = indexPath;
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        tableView.reloadData()
    }
    
}
