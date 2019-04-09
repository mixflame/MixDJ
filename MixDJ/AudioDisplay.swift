//
//  AudioDisplay.swift
//  MixDJ
//
//  Created by Jonathan Silverman on 3/7/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

import Foundation
import AVFoundation
import CoreGraphics


let RUNNING_DISPLAY_WIDTH = 982.0
let RUNNING_DISPLAY_HALF_WIDTH = RUNNING_DISPLAY_WIDTH / 2
let RUNNING_DISPLAY_HEIGHT = 44.0
let RUNNING_DISPLAY_HALF_HEIGHT = RUNNING_DISPLAY_HEIGHT / 2
let SECONDS_OF_RUNNING_DISPLAY = 10.0
let MAX_CANVAS_WIDTH = 32000.0


func drawRunningDisplay(context: CGContext, cache: [CGContext], centerInSeconds: Double ) {
    let center = floor( centerInSeconds * Double(RUNNING_DISPLAY_WIDTH) / SECONDS_OF_RUNNING_DISPLAY )
//    print("Center: ", center)

    var leftEdgeIndex = Int((center - RUNNING_DISPLAY_HALF_WIDTH)/MAX_CANVAS_WIDTH)
    if (leftEdgeIndex < 0) {
        leftEdgeIndex = 0
    }
//    print("Left edge Index ", leftEdgeIndex)

    let rightEdgeIndex = Int(floor((center + RUNNING_DISPLAY_HALF_WIDTH)/MAX_CANVAS_WIDTH))
//    print("Right edge Index ", rightEdgeIndex)
    
    for i in leftEdgeIndex...rightEdgeIndex {
//        print("Drawing image ", i)
        if(i >= cache.count - 1) {
            return // avoid overflow
        }
        guard let image = cache[i].makeImage() else {
            print("Couldn't create CGImage.")
            return
        }
//        print("Created CGImage.")
        let rect = CGRect(x: Int(RUNNING_DISPLAY_HALF_WIDTH - center + (MAX_CANVAS_WIDTH*Double(i))), y: 0, width: image.width, height: image.height)
//        print("Created rect: ", rect)
        context.draw(image, in: rect)
//        print("Image drawn to context.")
    }
}


func createRunningDisplayCache(context: CGContext, buffer: AVAudioPCMBuffer, isTop: Bool, duration: Double) -> [CGContext]? {
    print("Creating running display cache")
    let timeBefore = NSDate().timeIntervalSince1970
    let step = SECONDS_OF_RUNNING_DISPLAY * buffer.format.sampleRate / RUNNING_DISPLAY_WIDTH
    let newLength = floor( duration / SECONDS_OF_RUNNING_DISPLAY * RUNNING_DISPLAY_WIDTH )
    let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
    let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
    let safeFloats: [Float] = Array(floats)
    var data = safeFloats
    let numCanvases = ceil( newLength / RUNNING_DISPLAY_WIDTH )
    print("numCanvases: ", numCanvases)
    var canvases: [CGContext] = Array()

    // draw the canvas
    for j in stride(from: 0, to: newLength, by: RUNNING_DISPLAY_WIDTH) {
//        print("j: ", j)
        let width = newLength - j
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let canvas_width = (width>MAX_CANVAS_WIDTH) ? MAX_CANVAS_WIDTH : width
//        print("Canvas width: ", canvas_width)
        let canvas_height = RUNNING_DISPLAY_HEIGHT
        guard let canvas = CGContext.init(data: nil, width: Int(canvas_width), height: Int(canvas_height), bitsPerComponent: Int(8), bytesPerRow: Int(0), space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
            // cannot create context - handle error
            print("Cannot create canvas context.")
            return nil
        }
//        print("Canvas size width: ", canvas.width)
//        print("Canvas size height: ", canvas.height)
        
//        print("Clearing canvas")
        canvas.clear(CGRect(x: 0, y: 0, width: newLength, height: RUNNING_DISPLAY_HEIGHT))

        // draw the canvas
        for i in 0..<Int(width) {
//            print("i: ", i)
            var max = 0.0;
            let offset = floor((Double(i)+j)*step)
            for k in 0..<Int(step) {
                var datum = data[Int(offset)+k]
                if (datum < 0) {
                    datum = -datum;
                }
                if (datum > Float(max)) {
                    max = Double(datum)
                }
            }
            max = floor( max * RUNNING_DISPLAY_HEIGHT / 2 )
            if (isTop) {
                let rect = CGRect(x: i, y: Int(RUNNING_DISPLAY_HEIGHT), width: 1, height: Int(-max))
                // get the frequency here via FFT and set color
                canvas.setFillColor(UIColor.orange.cgColor)
                canvas.fill(rect)
            } else {
                let rect = CGRect(x: i, y: 0, width: 1, height: Int(max))
                canvas.setFillColor(UIColor.blue.cgColor)
                canvas.fill(rect)
            }
            
        }
        canvases.append(canvas)
    }
    let timeAfter = NSDate().timeIntervalSince1970
    print("Display cache took: ", timeAfter - timeBefore)
    return canvases
}

