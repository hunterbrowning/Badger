import UIKit

class TaskDetailViewController: UITableViewController, TaskDetailCompleteCellDelegate {
    private let authorCellHeight = CGFloat(72.0)
    private let headerCellHeight = CGFloat(40.0)
    private let titleCellHeight = CGFloat(72.0)
    private let completeButtonHeight = CGFloat(92.0)

    private var observer: FirebaseObserver<Task>?
    private var task: Task?
    private var contentCell: TaskDetailContentCell?
    private var isConfirmingDelete = false

    deinit {
        if let observer = self.observer {
            observer.dispose()
        }
    }

    override func viewDidLoad() {
        self.navigationItem.titleView = Helpers.createTitleLabel("Task")

        let headerCellNib = UINib(nibName: "HeaderCell", bundle: nil)
        self.tableView.registerNib(headerCellNib, forCellReuseIdentifier: "HeaderCell")

        self.setRightButton()
        super.viewDidLoad()
    }

    func setTask(owner: String, id: String, active: Bool) {
        TaskStore.tryGetTask(owner, id: id, startWithActive: active, withBlock: { maybeTask in
            if let task = maybeTask {
                self.observer = FirebaseObserver<Task>(query: task.ref, withBlock: { task in
                    self.task = task
                    self.getContentCell().setTask(task)

                    if (self.isViewLoaded()) {
                        // TODO: figure out a better way to update each cell.
                        self.tableView.reloadData()
                        self.setRightButton()
                    }
                })
            } else {
                // Task no longer exists.
                self.navigationController?.popViewControllerAnimated(true)
            }
        })
    }

    private func setRightButton() {
        let authId = UserStore.sharedInstance().getAuthUid()
        if let task = self.task {
            if task.author == authId {
                // Auth user is author, add "Edit" button.
                let button = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.Plain, target: self, action: "editButtonPressed")
                button.tintColor = Color.colorize(0x8E82FF, alpha: 1.0)
                self.navigationItem.rightBarButtonItem = button
            } else if task.owner == authId {
                // Auth user is owner, add "Delete" button.
                let button = UIBarButtonItem(title: "Delete", style: UIBarButtonItemStyle.Plain, target: self, action: "deleteButtonPressed")
                button.tintColor = Color.colorize(0xFF5C78, alpha: 1.0)
                self.navigationItem.rightBarButtonItem = button
            }
        }
    }

    func editButtonPressed() {
        self.performSegueWithIdentifier("TaskDetailEditExisting", sender: self)
    }

    func deleteButtonPressed() {
        if self.isConfirmingDelete {
            if let task = self.task {
                TaskStore.deleteTask(task)
                if let nav = self.navigationController {
                    nav.popViewControllerAnimated(true)
                }
            }
        } else {
            self.navigationItem.rightBarButtonItem?.title = "Confirm"
            self.isConfirmingDelete = true
            NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "stopConfirmingDelete", userInfo: nil, repeats: false)
        }
    }

    func stopConfirmingDelete() {
        self.isConfirmingDelete = false
        self.navigationItem.rightBarButtonItem?.title = "Delete"
    }

    // TableViewController Overrides

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let task = self.task {
            if UserStore.sharedInstance().isAuthUser(task.owner) {
                // Header + User + Header + Title + Content + Complete Button
                return 6
            }
        }
        // Header + User + Header + Title + Content
        return 5
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        switch (indexPath.row) {
        case 0, 2:
            return self.headerCellHeight
        case 1:
            return self.authorCellHeight
        case 3:
            return self.titleCellHeight
        case 4:
            let cell = self.getContentCell()
            return cell.calculateCellHeight()
        default:
            return self.completeButtonHeight
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch (indexPath.row) {
        case 0, 2:
            let cell = tableView.dequeueReusableCellWithIdentifier("HeaderCell") as! HeaderCell
            cell.labelColor = Color.colorize(0x929292, alpha: 1)
            cell.title = (indexPath.row == 0) ? "ASSIGNED BY" : "TASK INFO"
            return cell
        case 1:
            let cell = tableView.dequeueReusableCellWithIdentifier("TaskDetailAuthorCell") as! TaskDetailAuthorCell
            if let task = self.task {
                cell.setTask(task)
            }
            return cell
        case 3:
            let cell = tableView.dequeueReusableCellWithIdentifier("TaskDetailTitleCell") as! TaskDetailTitleCell
            if let task = self.task {
                cell.setTask(task)
            }
            return cell
        case 4:
            return getContentCell()
        default:
            let cell = tableView.dequeueReusableCellWithIdentifier("TaskDetailCompleteCell") as! TaskDetailCompleteCell
            cell.delegate = self
            if let task = self.task {
                cell.buttonTitle = task.active ? "Mark As Complete!" : "Mark As Incomplete"
            }
            return cell
        }
    }

    func detailCompleteCellPressed(cell: TaskDetailCompleteCell) {
        if let task = self.task {
            // Stop listening so that we don't get the value changed event.
            self.observer?.dispose()
            self.observer = nil

            let isActive = !task.active
            let oldRef = task.ref
            task.active = isActive
            task.completedAt = NSDate()

            // Get Firebase priority.
            let priority = task.firebasePriority

            // Move the task to its new list.
            task.ref.setValue(task.toJson(), andPriority: priority, withCompletionBlock: { (error, ref) in
                if error != nil {
                    println("Failed to change completion of task.")
                    println(task.toJson())
                    return
                }

                oldRef.removeValue()

                // Adjust active/completed counts for user.
                UserStore.adjustActiveTaskCount(task.owner, delta: isActive ? 1 : -1)
                UserStore.adjustCompletedTaskCount(task.owner, delta: isActive ? -1 : 1)

                // Update active task count for team.
                let combinedKey = Task.combineId(task.owner, id: task.id)
                if isActive {
                    TeamStore.addActiveTask(task.team, combinedId: combinedKey)
                } else {
                    TeamStore.removeActiveTask(task.team, combinedId: combinedKey)

                    // Add push notification for completing task.
                    let now = NSDate.javascriptTimestampNow()
                    Firebase(url: Global.FirebasePushCompletedTaskUrl).childByAppendingPath(combinedKey).setValue(now)
                }
            })

            self.navigationController?.popViewControllerAnimated(true)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "TaskDetailEditExisting" {
            let vc = segue.destinationViewController as! TaskEditViewController
            if let task = self.task {
                vc.setTask(task)
            }
        }
    }

    private func getContentCell() -> TaskDetailContentCell {
        if let cell = self.contentCell {
            return cell
        }
        self.contentCell = (self.tableView.dequeueReusableCellWithIdentifier("TaskDetailContentCell") as! TaskDetailContentCell)
        return self.contentCell!
    }
}