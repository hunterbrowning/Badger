import UIKit

class ProfileHeaderCell: UITableViewCell {

    private var hasAwakened = false
    private var user: User?

    @IBOutlet weak var profileCircle: ProfileCircle!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!

    override func awakeFromNib() {
        self.hasAwakened = true
        self.updateView()
    }

    func setUser(user: User) {
        self.user = user
        self.updateView()
    }

    private func updateView() {
        if self.hasAwakened {
            if let user = self.user? {
                self.nameLabel.text = user.fullName
                self.profileCircle.setUid(user.uid)
                self.statusLabel.text = Helpers.statusToText(nil, status: user.status)
                self.statusLabel.textColor = Helpers.statusToColor(user.status)
            }
        }
    }
}
