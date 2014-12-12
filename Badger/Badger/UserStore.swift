
@objc protocol UserObserver: class {
    func userUpdated(newUser: User)
}

class UserStore {
    // Accesses the singleton.
    class func sharedInstance() -> UserStore {
        struct Static {
            static var instance: UserStore?
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Static.token) {
            Static.instance = UserStore()
        }
        return Static.instance!
    }

    private let ref = Firebase(url: Global.FirebaseUsersUrl)
    private let dataStore: ObservableDataStore<User>

    init() {
        self.dataStore = ObservableDataStore<User>({ (user, observer:AnyObject) in
            if let userObserver = observer as? UserObserver {
                userObserver.userUpdated(user)
            }
        })
    }

    // Returns the current auth user's uid.
    func getAuthUid() -> String {
        return self.ref.authData.uid
    }

    // Returns a value indicating if this uid is the current auth user's.
    func isAuthUser(uid: String) -> Bool {
        return uid == self.ref.authData.uid
    }

    // Returns the authenticated user.
    func getAuthUser(withBlock: User -> ()) -> User? {
        return self.getUser(self.ref.authData.uid, withBlock: withBlock)
    }

    // Returns the user immediately if available and passes it to the block, otherwise
    // makes the request and passes the user to the block.
    func getUser(uid: String, withBlock: User -> ()) -> User? {
        return self.dataStore.getEntity(self.createUserRef(uid), withBlock: withBlock)
    }

    // Get users by uids.
    func getUsers(uids: [String], withBlock: [User] -> ()) {
        self.dataStore.getEntities(uids.map(self.createUserRef), withBlock: withBlock)
    }

    // Gets all users for the set of teams.
    func getUsersByTeams(teams: [Team], withBlock: [User] -> ()) {
        // Find all uids and remove duplicates.
        var uids = [String: Bool]()
        for team in teams {
            for member in team.memberIds {
                uids[member] = true
            }
        }
        self.getUsers(uids.keys.array, withBlock: withBlock)
    }

    // Gets all users for the set of team ids.
    func getUsersByTeamIds(ids: [String], withBlock: [User] -> ()) {
        if ids.isEmpty {
            withBlock([])
            return
        }
        TeamStore.sharedInstance().getTeams(ids, withBlock: { teams in
            self.getUsersByTeams(teams, withBlock: withBlock)
        })
    }

    // Atomically adjusts the active count.
    func adjustActiveTaskCount(id: String, delta: Int) {
        let activeRef = self.ref.childByAppendingPath(id).childByAppendingPath("active_tasks")
        FirebaseAsync.adjustValueForRef(activeRef, delta: delta)
    }

    // Adds an observer for a uid.
    func addObserver(observer: UserObserver, uid: String) {
        self.dataStore.addObserver(observer, ref: self.createUserRef(uid))
    }

    func removeObserver(observer: UserObserver, uid: String) {
        self.dataStore.removeObserver(observer, ref: self.createUserRef(uid))
    }

    private class func sendUpdate(user: User, toObserver: UserObserver) {
        toObserver.userUpdated(user)
    }

    private func createUserRef(uid: String) -> Firebase {
        return self.ref.childByAppendingPath(uid)
    }
}
