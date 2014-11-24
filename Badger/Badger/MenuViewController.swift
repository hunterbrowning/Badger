import UIKit

class MenuViewController: UITableViewController {

    let logoCellHeight: CGFloat = 46.0
    let contentCellHeight: CGFloat = 72.0
    let headerCellHeight: CGFloat = 40.0
    let settingCellHeight: CGFloat = 144.0
    let minFooterCellHeight: CGFloat = 72.0

    var teams = [Team]()

    override func viewDidLoad() {
        let userTableNib = UINib(nibName: "HeaderCell", bundle: nil)
        self.tableView.registerNib(userTableNib, forCellReuseIdentifier: "HeaderCell")
    }

    // TableViewController Overrides

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Logo + Header + MyProfile + Header + Teams + Header + Settings + Logo
        let teamCount = self.teams.isEmpty ? 1 : self.teams.count
        return 4 + teamCount + 3
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let teamCount = self.teams.isEmpty ? 1 : self.teams.count
        if (indexPath.row == 0) {
            return self.logoCellHeight
        } else if (indexPath.row == 1 || indexPath.row == 3 || indexPath.row == 4 + teamCount) {
            return self.headerCellHeight
        } else if (indexPath.row == teamCount + 5) {
            return self.settingCellHeight
        } else if (indexPath.row > teamCount + 5) {
            let contentCellsHeight = self.contentCellHeight * CGFloat(teamCount + 1)
            let headerCellsHeight = self.headerCellHeight * 3
            let contentHeight = self.logoCellHeight + contentCellsHeight + headerCellsHeight + self.settingCellHeight
            var height = tableView.frame.height - contentHeight - 20
            println(height)
            return height < self.minFooterCellHeight ? self.minFooterCellHeight : height
        }
        return self.contentCellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let teamCount = self.teams.isEmpty ? 1 : self.teams.count

        if (indexPath.row == 0) {
            return tableView.dequeueReusableCellWithIdentifier("LogoCell") as UITableViewCell
        } else if (indexPath.row == 1 || indexPath.row == 3 || indexPath.row == 4 + teamCount) {
            let cell = tableView.dequeueReusableCellWithIdentifier("HeaderCell") as HeaderCell
            cell.labelColor = Color.colorize(0x929292, alpha: 1)
            switch (indexPath.row) {
            case 1:
                cell.title = "MY PROFILE"
            case 3:
                cell.title = "MY TEAMS"
            default:
                cell.title = "SETTINGS"
            }
            return cell
        } else if (indexPath.row == 2) {
            let cell = tableView.dequeueReusableCellWithIdentifier("MyProfileCell") as MyProfileCell
            UserStore.sharedInstance().getAuthUser({ user in
                cell.setUser(user)
            })
            return cell
        } else if (indexPath.row < teamCount + 4) {
            if self.teams.isEmpty {
                return tableView.dequeueReusableCellWithIdentifier("MenuNoTeamsCell") as UITableViewCell
            }
            let cell = tableView.dequeueReusableCellWithIdentifier("MenuTeamCell") as MenuTeamCell
            cell.setTeam(self.teams[indexPath.row - 4])
            return cell
        } else if (indexPath.row == teamCount + 5) {
            let cell = tableView.dequeueReusableCellWithIdentifier("MenuSettingsCell") as MenuSettingsCell
            UserStore.sharedInstance().getAuthUser({ user in
                cell.setUser(user)
            })
            return cell
        }
        return tableView.dequeueReusableCellWithIdentifier("MenuFooterCell") as UITableViewCell
    }
}
