import UIKit

private enum Rows: Int {
    case TeamHeader = 0
    case SelectTeam = 1
    case InfoHeader = 2
    case Title = 3
    case Content = 4
    case Priority = 5
    case AssignToHeader = 6
    case Assignee = 7
    case Submit = 8
}

class TaskEditViewController: UITableViewController, TaskEditContentCellDelegate, TaskEditSubmitCellDelegate, SelectUserDelegate, SelectTeamDelegate, InputCellDelegate {
    private let selectTeamCellHeight = CGFloat(72.0)
    private let headerCellHeight = CGFloat(40.0)
    private let titleCellHeight = CGFloat(76.0)
    private let priorityCellHeight = CGFloat(72.0)
    private let assigneeCellHeight = CGFloat(72.0)
    private let submitButtonHeight = CGFloat(92.0)

    private let selectUserSegue = "EditTaskSelectUser"
    private let selectTeamSegue = "EditTaskSelectTeam"


    private var rightButton = UIBarButtonItem(title: "Done", style: .Plain, target: nil, action: "saveTask")
    private var task: Task?
    private var contentCell: TaskEditContentCell?
    private var owner: User?
    private var team: Team?
    private var isSaving = false
    private var isNew: Bool {
        return self.task == nil
    }
    private var isConfirmingDelete = false

    private var cells = [UITableViewCell?](count: 9, repeatedValue: nil)

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.rightButton.target = self
        self.rightButton.tintColor = Color.colorize(0x8E7EFF, alpha: 1.0)
    }

    override func viewDidLoad() {
        self.navigationItem.titleView = Helpers.createTitleLabel(self.isNew ? "Create Task" : "Edit Task")

        // Add Done button to nav header.
        self.navigationItem.rightBarButtonItem = rightButton

        let headerCellNib = UINib(nibName: "HeaderCell", bundle: nil)
        self.tableView.registerNib(headerCellNib, forCellReuseIdentifier: "HeaderCell")

        let userCellNib = UINib(nibName: "UserCell", bundle: nil)
        self.tableView.registerNib(userCellNib, forCellReuseIdentifier: "UserCell")

        let teamCellNib = UINib(nibName: "TeamCell", bundle: nil)
        self.tableView.registerNib(teamCellNib, forCellReuseIdentifier: "TeamCell")

        let textFieldCellNib = UINib(nibName: "TextFieldCell", bundle: nil)
        self.tableView.registerNib(textFieldCellNib, forCellReuseIdentifier: "TextFieldCell")

        // Auto populate the team if the auth user only is part of a single team.
        if self.team == nil {
            let authUser = UserStore.sharedInstance().getAuthUser()
            if authUser.teamIds.count == 1 {
                let ref = Team.createRef(authUser.teamIds.keys.array.first!)
                ref.observeSingleEventOfType(.Value, withBlock: { snapshot in
                    self.setTeam(Team.createFromSnapshot(snapshot) as! Team)
                })
            }
        }

        super.viewDidLoad()
    }

    func setTask(task: Task) {
        self.task = task
        if (self.isViewLoaded()) {
            self.navigationItem.titleView = Helpers.createTitleLabel("Edit Task")
            self.tableView.reloadData()
        }
        // Load the team and owner.
        Team.createRef(task.team).observeSingleEventOfType(.Value, withBlock: { snapshot in
            self.setTeam(Team.createFromSnapshot(snapshot) as! Team)
        })
        User.createRef(task.owner).observeSingleEventOfType(.Value, withBlock: { snapshot in
            self.setOwner(User.createFromSnapshot(snapshot) as! User)
        })

        // Set the right button to be "Delete" instead of "Done".
        self.rightButton.title = "Delete"
        self.rightButton.tintColor = Color.colorize(0xFF5C78, alpha: 1.0)
        self.rightButton.action = "deleteTask"
    }

    func setOwner(owner: User) {
        self.owner = owner
        if self.isViewLoaded() {
            self.cells[Rows.Assignee.rawValue] = nil
            let indexPath = NSIndexPath(forRow: Rows.Assignee.rawValue, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    func setTeam(team: Team) {
        self.team = team
        if self.isViewLoaded() {
            self.cells[Rows.SelectTeam.rawValue] = nil
            let indexPath = NSIndexPath(forRow: Rows.SelectTeam.rawValue, inSection: 0)
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    // TableViewController Overrides

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Header + Select Team + Header + Title + Content + Priority + Header + Assignee + Submit
        return 9
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let row = Rows(rawValue: indexPath.row)!
        switch (row) {
        case .TeamHeader, .InfoHeader, .AssignToHeader:
            return self.headerCellHeight
        case .SelectTeam:
            return self.selectTeamCellHeight
        case .Title:
            return self.titleCellHeight
        case .Content:
            let cell = self.getContentCell()
            return cell.calculateCellHeight()
        case .Priority:
            return self.priorityCellHeight
        case .Assignee:
            return self.assigneeCellHeight
        case .Submit:
            return self.submitButtonHeight
        default:
            return 0
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return self.cellForIndex(indexPath.row)
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.getContentCell().closeKeyboard()
        self.getTitleCell().closeKeyboard()

        if indexPath.row == Rows.SelectTeam.rawValue {
            self.performSegueWithIdentifier(self.selectTeamSegue, sender: self)
        } else if indexPath.row == Rows.Assignee.rawValue {
            self.performSegueWithIdentifier(self.selectUserSegue, sender: self)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == self.selectTeamSegue {
            let vc = segue.destinationViewController as! SelectTeamViewController
            vc.delegate = self
            if let owner = self.owner {
                vc.setUid(owner.uid)
            } else {
                vc.setUid(UserStore.sharedInstance().getAuthUid())
            }
        } else if segue.identifier == self.selectUserSegue {
            let vc = segue.destinationViewController as! SelectUserViewController
            vc.delegate = self
            if let team = self.team {
                vc.setTeamIds([team.id])
            } else {
                // Fetch all teams that the auth user's teams.
                let teamIds = UserStore.sharedInstance().getAuthUser().teamIds.keys.array
                vc.setTeamIds(teamIds)
            }
        }
    }

    // Adjusts the height of the content cell.
    func editContentCell(cell: TaskEditContentCell, hasChangedHeight: CGFloat) {
        self.tableView.beginUpdates()
        self.tableView.endUpdates()
    }

    func selectedUser(user: User) {
        // Don't do anything if this is the same owner.
        if let cur = self.owner {
            if cur.uid == user.uid {
                return
            }
        }
        self.owner = user
        self.cells[Rows.Assignee.rawValue] = nil
        let indexPath = NSIndexPath(forRow: Rows.Assignee.rawValue, inSection: 0)
        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    func selectedTeam(team: Team) {
        // Don't do anything if this is the same team.
        if let cur = self.team {
            if cur.id == team.id {
                return
            }
        }
        self.team = team
        self.cells[Rows.SelectTeam.rawValue] = nil
        let indexPath = NSIndexPath(forRow: Rows.SelectTeam.rawValue, inSection: 0)
        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    }

    func editSubmitCellSubmitted(cell: TaskEditSubmitCell) {
        self.saveTask()
    }

    func saveTask() {
        if (self.isSaving || self.owner == nil || self.team == nil) {
            return
        }
        self.isSaving = true

        let newOwner = self.owner!
        let newTeam = self.team!
        var createdAt = NSDate.javascriptTimestampNow()
        var completedAt: NSNumber? = nil
        var isActive = true
        var isNew = self.task == nil
        var isUpdated = self.task != nil

        var root = Firebase(url: isActive ? Global.FirebaseActiveTasksUrl : Global.FirebaseCompletedTasksUrl)
        var taskRef = root.childByAppendingPath(newOwner.uid).childByAutoId()

        if let task = self.task {
            if task.owner == newOwner.uid {
                taskRef = task.ref
            } else {
                // Task is moving to a different user so delete it from it's current location.
                task.ref.removeValue()
                isNew = true

                if isActive {
                    // Decrement active count if task is moving to a different user.
                    UserStore.adjustActiveTaskCount(task.owner, delta: -1)

                    // The user is going to be different so the combined id needs to be changed.
                    var oldTeamRef = Firebase(url: Global.FirebaseTeamsUrl).childByAppendingPath(task.team)
                    oldTeamRef.childByAppendingPath("tasks/\(task.owner)").removeValue()
                }
                // Keep the same id to be helpful for the UI.
                taskRef = root.childByAppendingPath("\(newOwner.uid)/\(task.id)")
            }
            // This is an active task that's being moved to a different team so decrement the active count.
            if task.team != newTeam.id && task.active {
                TeamStore.adjustActiveTaskCount(task.team, delta: -1)
            }
            // Keep the same timestamps and active state.
            isActive = task.active
            createdAt = NSDate.javascriptTimestampFromDate(task.createdAt)
            if let date = task.completedAt {
                completedAt = NSDate.javascriptTimestampFromDate(date)
            }
        }

        // Create the task values.
        var taskValues = [
            "author": UserStore.sharedInstance().getAuthUid(),
            "team": self.team!.id,
            "title": self.getTitleCell().getContent(),
            "content": self.getContentCell().getContent(),
            "priority": self.getPriorityCell().getPriority().rawValue as String,
            "active": isActive,
            "created_at": createdAt,

        ]

        // Date to be used for calculating Firebase priority.
        var dateForPriority = createdAt

        // If there is a completion date, added it to values and change priority.
        if let jsDate = completedAt {
            taskValues["completed_at"] = jsDate
            dateForPriority = jsDate
        }

        // Calculate what the firebase priority of the task should be.
        let mult = Task.getFirebasePriorityMult(self.getPriorityCell().getPriority(), isActive: isActive)
        var priority = (-1 * dateForPriority.doubleValue) * mult

        // Save the task.
        taskRef.setValue(taskValues, andPriority: priority, withCompletionBlock: { (err, ref) in
            if err != nil {
                println("Failed to create/edit task")
                println("Values: \(taskValues)")
                println("Error: \(err)")
                return
            }

            var combinedKey = "\(newOwner.uid)^\(taskRef.key)"

            // Increment the active tasks count for the user if it's new and active.
            if isActive && isNew {
                UserStore.adjustActiveTaskCount(newOwner.uid, delta: 1)
            }

            // Add the task to the appropriate team and incrememt count.
            if isActive {
                TeamStore.addActiveTask(newTeam.id, combinedId: combinedKey)
            }

            // Add to push message queues if new of updated.
            if isNew && isActive {
                let now = NSDate.javascriptTimestampNow()
                Firebase(url: Global.FirebasePushNewTaskUrl).childByAppendingPath(combinedKey).setValue(now)
            }
            self.isSaving = false
            if let nav = self.navigationController {
                nav.popViewControllerAnimated(true)
            }
        })
    }

    func deleteTask() {
        if self.isConfirmingDelete {
            if let task = self.task {
                TaskStore.deleteTask(task)
                if let nav = self.navigationController {
                    let previousIndex = nav.viewControllers.count - 2
                    // Skip the detail vc and pop back to the vc before.
                    if nav.viewControllers[previousIndex] is TaskDetailViewController {
                        let vc = nav.viewControllers[previousIndex - 1] as! UIViewController
                        nav.popToViewController(vc, animated: true)
                    } else {
                        nav.popViewControllerAnimated(true)
                    }
                }
            }
        } else {
            self.rightButton.title = "Confirm"
            self.isConfirmingDelete = true
            NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "stopConfirmingDelete", userInfo: nil, repeats: false)
        }
    }

    func stopConfirmingDelete() {
        self.isConfirmingDelete = false
        self.rightButton.title = "Delete"
    }

    // InputCellDelegate: opens the next cell when the "next" key is pressed on the keyboard.
    func shouldSelectNext(cell: InputCell) {
        let cell = self.cellForIndex(Rows.Content.rawValue) as! TaskEditContentCell
        cell.openKeyboard()
    }

    func cellDidBeginEditing(cell:InputCell) {
        var indexPath: NSIndexPath
        if cell === self.getTitleCell() {
            indexPath = NSIndexPath(forRow: Rows.InfoHeader.rawValue, inSection: 0)
        } else {
            indexPath = NSIndexPath(forRow: Rows.Content.rawValue, inSection: 0)
        }
        self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Top, animated: true)
    }

    private func cellForIndex(index: Int) -> UITableViewCell {
        if let cell = self.cells[index] {
            return cell
        }
        // Create new table cells.
        let row = Rows(rawValue: index)!
        switch (row) {
        case .TeamHeader, .InfoHeader, .AssignToHeader:
            let cell = tableView.dequeueReusableCellWithIdentifier("HeaderCell") as! HeaderCell
            cell.labelColor = Color.colorize(0x929292, alpha: 1)
            switch (row) {
            case .TeamHeader:
                cell.title = "TEAM"
            case .InfoHeader:
                cell.title = "TASK INFO"
            default:
                cell.title = "ASSIGN TO"
            }
            self.cells[index] = cell
            return cell
        case .SelectTeam:
            if let team = self.team {
                let cell = tableView.dequeueReusableCellWithIdentifier("TeamCell") as! TeamCell
                cell.setTeam(team)
                self.cells[index] = cell
            } else {
                self.cells[index] = tableView.dequeueReusableCellWithIdentifier("SelectTeamCell") as? UITableViewCell
            }
            return self.cells[index]!
        case .Title:
            let cell = tableView.dequeueReusableCellWithIdentifier("TextFieldCell") as! TextFieldCell
            cell.delegate = self
            cell.label.text = "Title"
            cell.label.textColor = Color.colorize(0x929292, alpha: 1.0)
            cell.textField.placeholder = "Title"
            cell.borderColor = Color.colorize(0xE1E1E1, alpha: 1.0)
            cell.topBorderStyle = "full"
            cell.bottomBorderStyle = "inset"
            if let task = self.task {
                cell.setContent(task.title)
            }
            self.cells[index] = cell
            return cell
        case .Content:
            let cell = (self.tableView.dequeueReusableCellWithIdentifier("TaskEditContentCell") as! TaskEditContentCell)
            cell.delegate = self
            cell.cellDelegate = self
            if let task = self.task {
                cell.setContent(task.content)
            }
            self.cells[index] = cell
            return cell
        case .Priority:
            let cell = tableView.dequeueReusableCellWithIdentifier("TaskEditPriorityCell") as! TaskEditPriorityCell
            if let task = self.task {
                cell.setTask(task)
            }
            self.cells[index] = cell
            return cell
        case .Assignee:
            if let owner = self.owner {
                let cell = tableView.dequeueReusableCellWithIdentifier("UserCell") as! UserCell
                cell.setUid(owner.uid)
                self.cells[index] = cell
                return cell
            }
            self.cells[index] = (tableView.dequeueReusableCellWithIdentifier("SelectUserCell") as! UITableViewCell)
            return self.cells[index]!
        default:
            let cell = tableView.dequeueReusableCellWithIdentifier("TaskEditSubmitCell") as! TaskEditSubmitCell
            cell.delegate = self
            self.cells[index] = cell
            return cell
        }
    }


    private func getTitleCell() -> TextFieldCell {
        return self.cellForIndex(Rows.Title.rawValue) as! TextFieldCell
    }

    private func getContentCell() -> TaskEditContentCell {
        return self.cellForIndex(Rows.Content.rawValue) as! TaskEditContentCell
    }

    private func getPriorityCell() -> TaskEditPriorityCell {
        return self.cellForIndex(Rows.Priority.rawValue) as! TaskEditPriorityCell
    }
}