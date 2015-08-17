//
//  StatsViewController.swift
//  XMLPerformance
//
//  Created by David Francis on 7/28/15.
//  Copyright © 2015 FTS InfoTech, LLC. All rights reserved.
//

import UIKit

class StatsViewController: UITableViewController {
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @IBAction func resetStatistics(sender: AnyObject) {
        ResetStatisticsDatabase()
        tableView.reloadData()
    }
    
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("StatsCell", forIndexPath: indexPath)

        switch (indexPath.row) {
        case 0:
            cell.textLabel!.text = NSLocalizedString("Mean Download Time", comment: "Mean Download Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanDownloadTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        case 1:
            cell.textLabel!.text = NSLocalizedString("Mean Parse Time", comment: "Mean Parse Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanParseTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        case 2:
            cell.textLabel!.text = NSLocalizedString("Mean Total Time", comment: "Mean Total Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanTotalTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        default:
            break;
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let numberOfRuns = NumberOfRunsForParserType(XMLParserType(rawValue: section)!)
        let parserName = (section == 0) ? CocoaXMLParser.parserName : LibXMLParser.parserName
        var title = ""
        if numberOfRuns == 1 {
            title = String(format: NSLocalizedString("%@ (%d run):", comment: "One Run format"), parserName(), numberOfRuns)
        } else {
            title = String(format: NSLocalizedString("%@ (%d runs):", comment: "Multiple Runs format"), parserName(), numberOfRuns)
        }
        return title
    }

}
