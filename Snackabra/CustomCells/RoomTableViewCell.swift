//
//  RoomTableViewCell.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import UIKit
import CoreData

class RoomTableViewCell: UITableViewCell {
    
    //MARK: - IBOutlets
    @IBOutlet weak var roomNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func configure(room: NSManagedObject){
        if let name = room.value(forKey: "roomName") as? String {
            roomNameLabel.text = name;
        }
        // if let unread = room.value(forKey: "unread") as? Bool, unread {
        //     roomNameLabel.font = UIFont.boldSystemFont(ofSize: 17);
        // }
        roomNameLabel.adjustsFontSizeToFitWidth = true;
        roomNameLabel.minimumScaleFactor = 0.9;
    }
}
