//
//  runningWaveform.swift
//  MixDJ
//
//  Created by Jonathan Silverman on 3/7/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

import UIKit
import AVFoundation

// custom running display UI class
class runningWaveform: UIView {
    
    var buffer: AVAudioPCMBuffer?
    var color: CGColor = UIColor.red.cgColor
    var duration: Double = 0
    var isTop: Bool = true
    var waveformDisplayCache: [CGContext]?
    var seconds: Double = 0
    var cue_time: Double = 0.0
    
    

    override func draw(_ rect: CGRect) {
//        print("Drawing waveform display")
//        print("Width: ", self.frame.width)
//        print("Height: ", self.frame.height)
        let context = UIGraphicsGetCurrentContext()
        // draw center pos indicator, just for show
        UIColor.gray.set()
        let rect = CGRect(x: RUNNING_DISPLAY_HALF_WIDTH, y: 0, width: 1, height: RUNNING_DISPLAY_HEIGHT)
        context!.fill(rect)
        
        if(context == nil) {
            print("No context to render running waveform")
            return
        }
        if(buffer == nil) {
            print("No buffer for running waveform")
            return
        }
        if(duration == 0) {
            print("No duration yet, not drawing.")
            return
        }

        if (waveformDisplayCache == nil) {
//            akin to an analyze. can we cache the cache?
//            let main execution proceed
            self.waveformDisplayCache = createRunningDisplayCache(context: context!, buffer: self.buffer!, isTop: self.isTop, duration: self.duration)
            drawRunningDisplay(context: context!, cache: self.waveformDisplayCache!, centerInSeconds: self.seconds)
        } else {
            drawRunningDisplay(context: context!, cache: self.waveformDisplayCache!, centerInSeconds: self.seconds)
        }
        
        UIColor.gray.set()
        context!.fill(rect)
        
        drawCuesOnRunningDisplay()
    }
    
    func drawCuesOnRunningDisplay() {
        let context = UIGraphicsGetCurrentContext()
        let begin = self.seconds - (SECONDS_OF_RUNNING_DISPLAY/2)
        if(cue_time == 0) {
            // don't paint default cue (cue time 0)
            return
        }
        let end = begin + SECONDS_OF_RUNNING_DISPLAY
            let cue = cue_time
            if ((cue > begin) && (cue < end)) {
                let x = (cue-begin) * RUNNING_DISPLAY_WIDTH / SECONDS_OF_RUNNING_DISPLAY
                UIColor.red.set()
                context?.fill(CGRect(x: x, y:  0, width: 1, height: RUNNING_DISPLAY_HEIGHT))
        }
    }
}
