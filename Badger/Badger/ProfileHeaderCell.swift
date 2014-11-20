import UIKit

class ProfileHeaderCell: UITableViewCell, StatusRecipient {

    private var uid: String?

    @IBOutlet weak var profileCircle: ProfileCircle!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.nameLabel.font = UIFont(name: "OpenSans-Light", size: 24.0)
        self.statusLabel.font = UIFont(name: "OpenSans-Light", size: 18.0)
    }

    func setUser(user: User) {
        if let uid = self.uid? {
            StatusListener.sharedInstance().removeRecipient(self, uid: uid)
        }
        self.uid = user.uid
        StatusListener.sharedInstance().addRecipient(self, uid: user.uid)

        self.setStatusLabel(user.status)
        if let nameLabel = self.nameLabel? {
            nameLabel.text = user.fullName
        }
        if let profileCircle = self.profileCircle? {
            profileCircle.setUser(user)
        }
        // TODO: Set profile and background images.
    }

    func statusUpdated(uid: String, newStatus: UserStatus) {
        self.setStatusLabel(newStatus)
    }

    private func setStatusLabel(status: UserStatus) {
        if let label = self.statusLabel? {
            label.text = status.rawValue as String?
            label.textColor = Helpers.statusToColor(status)
        }
    }
}
