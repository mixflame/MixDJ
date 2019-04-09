//
//  audioMetadata.swift
//  MixDJ
//
//  Created by Jonathan Silverman on 3/1/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

import Foundation
import RealmSwift

class AudioMetadata: Object {
    @objc dynamic var url = ""
    @objc dynamic var key = ""
    @objc dynamic var bpm = 0.0
}
