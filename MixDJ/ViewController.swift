//
//  ViewController.swift
//  MixDJ
//
//  Created by Jonathan Silverman on 2/21/19.
//  Copyright © 2019 Jonathan Silverman. All rights reserved.
//

import UIKit
import AVFoundation
import Alamofire
import AudioKit
import RealmSwift
//import SCWaveformView

// precious soundcloud id
let client_id = "48b5782b303b159c4dbdd05afab2fc1b"

// default URLs that will go away
var soundcloud1 = "https://api.soundcloud.com/tracks/345393623?client_id=\(client_id)"
var soundcloud2 = "https://api.soundcloud.com/tracks/358567736?client_id=\(client_id)"


// will mix
// input 2 modes and 2 numbers (camelot)
// false -> won't mix (dissonant)
// true -> will mix (harmonic)
func will_mix(last_number: Int, last_mode: String, mode: String, number: Int) -> Bool {
    if((abs(number - last_number) == 1) && (last_mode == mode)) {
        return true;
    } else if((last_number == number) && (last_mode != mode)) {
        return true;
    } else if((last_number == number) && (last_mode == mode)) {
        return true;
    } else if((last_number == 12) && (number == 1) && (mode == last_mode)) {
        return true;
    } else if((last_number == 1) && (number == 12) && (mode == last_mode)) {
        return true;
    } else {
        return false;
    }
}

// checks if tempos are more than 10% off in either direction
// true -> tempo match
// false -> out of range
func tempos_are_good(lasttempo: Float, tempo: Float) -> Bool {
    if ((tempo / lasttempo < 0.9) || (tempo / lasttempo > 1.1)) {
        return false;
    } else {
        return true;
    }
}

class ViewController: UIViewController {
    @IBOutlet weak var bpm1: UILabel! // deck 1 bpm display UILabel
    @IBOutlet weak var key_display1: UILabel! // deck 1 key display UILabel
    @IBOutlet weak var speed_control1: UISlider! // deck 1 speed control UISlider
    
    @IBOutlet weak var bpm2: UILabel! // deck 2 bpm display UILabel
    @IBOutlet weak var key_display2: UILabel! // deck 2 key display UILabel
    @IBOutlet weak var speed_control2: UISlider! // deck 2 speed control UISlider
    
    @IBOutlet weak var crossfader: UISlider! // crossfader UISlider
    @IBOutlet weak var preview_switch1: UISwitch!
    @IBOutlet weak var preview_switch2: UISwitch!
    
    // current tempo
    var current_tempo1 = 0.0 // current tempo deck 1
    var current_tempo2 = 0.0 // current tempo deck 2
    
    var tempo1: Float = 0.0 // song 1 original tempo
    var key1: String = "" // song 1 key
    
    var tempo2: Float = 0.0 // song 2 original tempo
    var key2: String = "" // song 2 key
    
    var timer1 = Timer() // timer updates waveform play position based on AVAudioPlayerNode time (deck 1)
    var timer2 = Timer() // same as above, deck 2
    var time_offset1: Double = 0 // used to offset AVAudioPlayerNode time by cue time (workaround)
    var time_offset2: Double = 0 // same but deck 2
    
    var engine = AVAudioEngine() // main audio engine
    let player1_speed = AVAudioUnitVarispeed() // player1 track speed
    let player1_pitch = AVAudioUnitTimePitch() // player1 pitch control
    let player2_speed = AVAudioUnitVarispeed() // player2 track speed
    let player2_pitch = AVAudioUnitTimePitch() // player2 pitch control
    var player1 = AVAudioPlayerNode() // deck 1 audio player node
    var player2 = AVAudioPlayerNode() // deck 2 audio player node
    var player1_xfadegain = AVAudioMixerNode() // deck 1 crossfader gain mixer node
    var player2_xfadegain = AVAudioMixerNode() // deck 2 crossfader gain mixer node
    var player1_preview = AVAudioMixerNode() // preview node
    var player2_preview = AVAudioMixerNode() // preview node deck 2
    var audioFormat1: AVAudioFormat? // deck 1 audio format
    var audioFormat2: AVAudioFormat? // deck 2 audio format
    var audioSampleRate1: Float = 0 // deck 1 sample rate
    var audioSampleRate2: Float = 0 // deck 2 sample rate
    var audioLengthSeconds1: Float = 0 // deck 1 length in seconds
    var audioLengthSeconds2: Float = 0 // deck 2 length in seconds
    var audioLengthSamples1: AVAudioFramePosition = 0 // deck 1 length in samples
    var audioLengthSamples2: AVAudioFramePosition = 0 // deck 2 length in samples
    var buffer1: AVAudioPCMBuffer?
    var buffer2: AVAudioPCMBuffer?
    
    // outlets for SCWaveformViews
    @IBOutlet weak var scWaveform1: SCWaveformView!
    @IBOutlet weak var scWaveform2: SCWaveformView!
    
    // running waveforms
    @IBOutlet weak var runningWaveform1: runningWaveform!
    
    @IBOutlet weak var runningWaveform2: runningWaveform!
    
    // cue times in seconds, set/gotten by cue buttons
    var cue_time1 = 0.0
    var cue_time2 = 0.0
    
    // audioFiles, sets important audio information
    var audioFile1: AVAudioFile? {
        didSet {
            if let audioFile1 = audioFile1 {
                audioLengthSamples1 = audioFile1.length
                audioFormat1 = audioFile1.processingFormat
                audioSampleRate1 = Float(audioFormat1?.sampleRate ?? 44100)
                audioLengthSeconds1 = Float(audioLengthSamples1) / audioSampleRate1
            }
        }
    }
    var audioFile2: AVAudioFile? {
        didSet {
            if let audioFile2 = audioFile2 {
                audioLengthSamples2 = audioFile2.length
                audioFormat2 = audioFile2.processingFormat
                audioSampleRate2 = Float(audioFormat2?.sampleRate ?? 44100)
                audioLengthSeconds2 = Float(audioLengthSamples2) / audioSampleRate2
            }
        }
    }
    
    // audioFileURLs, used to get the file for the player
    var audioFileURL1: URL? {
        didSet {
            if let audioFileURL1 = audioFileURL1 {
                audioFile1 = try? AVAudioFile(forReading: audioFileURL1)
            }
        }
    }
    var audioFileURL2: URL? {
        didSet {
            if let audioFileURL2 = audioFileURL2 {
                audioFile2 = try? AVAudioFile(forReading: audioFileURL2)
            }
        }
    }
    
    // setups up the audio graph (collections of nodes and connections)
    func setupAudio() {
        // players
        engine.attach(player1)
        engine.attach(player2)
        // speed and pitch
        engine.attach(player1_speed)
        engine.attach(player1_pitch)
        engine.attach(player2_speed)
        engine.attach(player2_pitch)
        // preview
        engine.attach(player1_preview)
        engine.attach(player2_preview)
        // crossfade gain (mixer node)
        engine.attach(player1_xfadegain)
        engine.attach(player2_xfadegain)
        
        // player1 connections
        engine.connect(player1, to: player1_speed, format: audioFormat1)
        engine.connect(player1_speed, to: player1_pitch, format: audioFormat1)
        let previewPoint1 = AVAudioConnectionPoint(node: player1_preview, bus: player1_preview.nextAvailableInputBus)
        let xfadePoint1 = AVAudioConnectionPoint(node: player1_xfadegain, bus: player1_xfadegain.nextAvailableInputBus)
        engine.connect(player1_pitch, to: [previewPoint1, xfadePoint1], fromBus: 0, format: audioFormat1)

        // configure preview
        player1_xfadegain.pan = -1.0 // main out
        player1_preview.pan = 1.0 // preview channel
        player1_preview.volume = 0 // muted at first
        
        // player2 connections
        engine.connect(player2, to: player2_speed, format: audioFormat2)
        engine.connect(player2_speed, to: player2_pitch, format: audioFormat2)
        let previewPoint2 = AVAudioConnectionPoint(node: player2_preview, bus: player2_preview.nextAvailableInputBus)
        let xfadePoint2 = AVAudioConnectionPoint(node: player2_xfadegain, bus: player2_xfadegain.nextAvailableInputBus)
        engine.connect(player2_pitch, to: [previewPoint2, xfadePoint2], fromBus: 0, format: audioFormat2)
        
        // configure preview
        player2_xfadegain.pan = -1.0 // main out
        player2_preview.pan = 1.0 // preview channel
        player2_preview.volume = 0 // muted at first
        
        // connect outputs to mainMixerNode (output)
        engine.connect(player1_xfadegain, to: engine.mainMixerNode, format: audioFormat1)
        engine.connect(player2_xfadegain, to: engine.mainMixerNode, format: audioFormat2)
        engine.connect(player1_preview, to: engine.mainMixerNode, format: audioFormat1)
        engine.connect(player2_preview, to: engine.mainMixerNode, format: audioFormat2)
        engine.prepare()
        
        do {
            try engine.start()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // reads audioFile1 or audioFile2 into a buffer and then schedules it to play
    func readToDeckFromBuffer(left: Bool, at: AVAudioTime?) {
        var file: AVAudioFile?
        if (left) {
            file = audioFile1
        } else {
            file = audioFile2
        }
        var buffer: AVAudioPCMBuffer? = nil
        if let processingFormat = file?.processingFormat {
            buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(file?.length ?? 0))
        }
        if let buffer = buffer {
            ((try? file?.read(into: buffer)) as ()??)
        }
        
        if(left){
            buffer1 = buffer
            self.postLoad(left: true)
        } else {
            buffer2 = buffer
            self.postLoad(left: false)
        }
        
        if let buffer = buffer {
            if(left){
                self.player1.scheduleBuffer(buffer, at: at, options: .interrupts, completionHandler: {
                    // reminder: we're not on the main thread in here
                    DispatchQueue.main.async(execute: {
                        print("done playing 1, as expected!")
                        // don't pause or stop
//                        self.player1.pause()
                    })
                })
            } else {
                self.player2.scheduleBuffer(buffer, at: at, options: .interrupts, completionHandler: {
                    // reminder: we're not on the main thread in here
                    DispatchQueue.main.async(execute: {
                        print("done playing 2, as expected!")
                        // don't pause or stop
//                        self.player2.pause()
                    })
                })
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // set background
        self.view.layer.contents =  UIImage(named: "MixflameiOS-Background3.png")?.cgImage
        // setup audio graph
        self.setupAudio()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        timer1.invalidate()
        timer2.invalidate()
        // maybe do something to the player or not
    }
    
    @IBAction func set_preview_one(_ sender: Any) {
        if(preview_switch1.isOn) {
            player1_preview.volume = 1
        } else {
            player1_preview.volume = 0
        }
    }
    
    
    @IBAction func set_preview_two(_ sender: Any) {
        if(preview_switch2.isOn) {
            player2_preview.volume = 1
        } else {
            player2_preview.volume = 0
        }
    }
    
    // set cue position deck 1
    @IBAction func set_cue_one(_ sender: Any) {
        if (audioFile1 == nil) {
            return
        }
        let songFormat: AVAudioFormat = audioFile1!.processingFormat
        let sampleRateSong = songFormat.sampleRate
        let startInSongSeconds = 0.0
        
        if player1.isPlaying {
            let nodeTime: AVAudioTime? = player1.lastRenderTime
            var playerTime: AVAudioTime? = nil
            if let nodeTime = nodeTime {
                playerTime = player1.playerTime(forNodeTime: nodeTime)
            }
            let elapsedSeconds = Float(startInSongSeconds + (Double(playerTime!.sampleTime) / sampleRateSong))
            if elapsedSeconds >= Float(audioLengthSeconds1) {
                return // cannot place cue after song has ended
            }
            cue_time1 = Double(elapsedSeconds) + time_offset1
            self.runningWaveform1.cue_time = cue_time1 // show it on the running display
//            print("Time offset 1: ", time_offset1)
            print("Cue 1: ", cue_time1)

        }
    }
    
    // set cue position deck 2
    @IBAction func set_cue_two(_ sender: Any) {
        if (audioFile2 == nil) {
            return
        }
        let songFormat: AVAudioFormat = audioFile2!.processingFormat
        let sampleRateSong = songFormat.sampleRate
        let startInSongSeconds = 0.0
        
        if player2.isPlaying {
            let nodeTime: AVAudioTime? = player2.lastRenderTime
            var playerTime: AVAudioTime? = nil
            if let nodeTime = nodeTime {
                playerTime = player2.playerTime(forNodeTime: nodeTime)
            }
            let elapsedSeconds = Float(startInSongSeconds + (Double(playerTime!.sampleTime) / sampleRateSong))
            if elapsedSeconds >= Float(audioLengthSeconds2) {
                return // cannot place cue after song has ended
            }
            cue_time2 = Double(elapsedSeconds) + time_offset2
            self.runningWaveform2.cue_time = cue_time2 // show it on the running display
            print("Cue 2: ", cue_time2)
        }
    }

    // cue (play from position) deck 1
    @IBAction func cue_one(_ sender: Any) {
        if (audioFile1 == nil) {
            return
        }
        let songLengthSamples = audioFile1!.length
        let songFormat: AVAudioFormat = audioFile1!.processingFormat
        let sampleRateSong = songFormat.sampleRate
        var startInSongSeconds = 0.0

        startInSongSeconds = cue_time1
        // set time offset before we stop
        time_offset1 = cue_time1 // time_offset1 is the number of seconds from beginning to cue
        player1.pause() // crash fix?
        player1.stop() // we've stopped, play time is 0
        
        let startSample: UInt = UInt(floor(startInSongSeconds * sampleRateSong))
        var lengthSamples: UInt = 0
        lengthSamples = UInt(songLengthSamples) - UInt(startSample)
        
        player1.scheduleSegment(audioFile1!, startingFrame: AVAudioFramePosition(startSample), frameCount: AVAudioFrameCount(lengthSamples), at: nil, completionHandler: {
            // do not pause. the deck might still be playing
            print("Done playing segment 1")
//            self.player1.pause()
        })
        addTimer1()
        player1.play()

    }
    
    // cue (play from position) deck 2
    @IBAction func cue_two(_ sender: Any) {
        if (audioFile2 == nil) {
            return
        }
        let songLengthSamples = audioFile2!.length
        let songFormat: AVAudioFormat = audioFile2!.processingFormat
        let sampleRateSong = songFormat.sampleRate
        var startInSongSeconds = 0.0
        
        startInSongSeconds = cue_time2
        // set time offset before we stop
        time_offset2 = cue_time2 // time_offset2 is the number of seconds from beginning to cue
        player2.pause() // crash fix?
        player2.stop() // we've stopped, play time is 0
        
        let startSample: UInt = UInt(floor(startInSongSeconds * sampleRateSong))
        var lengthSamples: UInt
        lengthSamples = UInt(songLengthSamples) - UInt(startSample)
        
        player2.scheduleSegment(audioFile2!, startingFrame: AVAudioFramePosition(startSample), frameCount: AVAudioFrameCount(lengthSamples), at: nil, completionHandler: {
            // do not pause. the deck might still be playing
            print("Done playing segment 2")
//            self.player2.pause()
        })
        addTimer2()
        player2.play()
    }
    
    
    // sync one deck to another, using current tempo
    @IBAction func sync_one(_ sender: Any) {
        if(self.current_tempo1 == 0 || self.current_tempo2 == 0) {
            return
        }
        let factor = self.current_tempo1 / self.current_tempo2
        var speed_control_value: Float
        if (factor < 1) {
            print("Move speed up")
            print("Factor: ", factor)
            speed_control_value = speed_control1.value + (Float(1 - factor) * 1)
            print("Speed control value: ", speed_control_value)
            let new_bpm = speed_control_value * self.tempo1
            print("New bpm: ", new_bpm)
            speed_control1.value = speed_control_value
            self.player1_speed.rate = self.speed_control1.value
            self.current_tempo1 = Double(self.player1_speed.rate * self.tempo1)
            self.bpm1.text = String(format: "%.2f", self.current_tempo1)
        } else {
            print("Move speed down")
            print("Factor: ", factor)
            speed_control_value = speed_control1.value - (Float(factor - 1) * 1)
            print("Speed control value: ", speed_control_value)
            let new_bpm = speed_control_value * self.tempo1
            print("New bpm: ", new_bpm)
            speed_control1.value = speed_control_value
            self.player1_speed.rate = self.speed_control1.value
            self.current_tempo1 = Double(self.player1_speed.rate * self.tempo1)
            self.bpm1.text = String(format: "%.2f", self.current_tempo1)
        }
        
    }
    
    @IBAction func sync_two(_ sender: Any) {
        if(self.current_tempo1 == 0 || self.current_tempo2 == 0) {
            return
        }
        let factor = self.current_tempo2 / self.current_tempo1
        var speed_control_value: Float
        if (factor < 1) {
            print("Move speed up")
            print("Factor: ", factor)
            speed_control_value = speed_control2.value + (Float(1 - factor) * 1)
            print("Speed control value: ", speed_control_value)
            let new_bpm = speed_control_value * self.tempo2
            print("New bpm: ", new_bpm)
            speed_control2.value = speed_control_value
            self.player2_speed.rate = self.speed_control2.value
            self.current_tempo2 = Double(self.player2_speed.rate * self.tempo2)
            self.bpm2.text = String(format: "%.2f", self.current_tempo2)
        } else {
            print("Move speed down")
            print("Factor: ", factor)
            speed_control_value = speed_control2.value - (Float(factor - 1) * 1)
            print("Speed control value: ", speed_control_value)
            let new_bpm = speed_control_value * self.tempo2
            print("New bpm: ", new_bpm)
            speed_control2.value = speed_control_value
            self.player2_speed.rate = self.speed_control2.value
            self.current_tempo2 = Double(self.player2_speed.rate * self.tempo2)
            self.bpm2.text = String(format: "%.2f", self.current_tempo2)
        }
        
    }
    
    // rate (speed) changing via UI Slider value changed
    
    @IBAction func change_speed_one(_ sender: Any) {
        if(self.current_tempo1 == 0) {
            return
        }
        self.player1_speed.rate = self.speed_control1.value
        self.current_tempo1 = Double(self.player1_speed.rate * self.tempo1)
        self.bpm1.text = String(format: "%.2f", self.current_tempo1)
    }
    
    @IBAction func change_speed_two(_ sender: Any) {
        if(self.current_tempo2 == 0) {
            return
        }
        self.player2_speed.rate = self.speed_control2.value
        self.current_tempo2 = Double(self.player2_speed.rate * self.tempo2)
        self.bpm2.text = String(format: "%.2f", self.current_tempo2)
    }
    
    // timer init
    func addTimer1() {
        // update play position
        self.timer1 = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateWaveformTimes), userInfo: nil, repeats: true)
    }
    // they are seperate because to save resources
    func addTimer2() {
        self.timer2 = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateWaveformTimes2), userInfo: nil, repeats: true)
    }
    
    // play buttons
    
    @IBAction func play_one(_ sender: Any) {
        if(self.player1.isPlaying == false) {
            print("Playing deck 1")
            addTimer1()
            self.player1.play()
        } else {
            print("Pausing deck 1")
            timer1.invalidate()
            self.player1.pause()
        }
    }
    
    @IBAction func play_two(_ sender: Any) {
        if(self.player2.isPlaying == false) {
            print("Playing deck 2")
            addTimer2()
            self.player2.play()
        } else {
            print("Pausing deck 2")
            timer2.invalidate()
            self.player2.pause()
        }
    }
    
    // load buttons
    
    @IBAction func load_one(_ sender: Any) {
        // change to loading from a playlist later
        DispatchQueue.global(qos: .background).async {
            self.load(left: true, url: soundcloud1)
        }
    }
    
    @IBAction func load_two(_ sender: Any) {
        DispatchQueue.global(qos: .background).async {
            self.load(left: false, url: soundcloud2)
        }
    }
    
    // UI crossfader value changed action
    @IBAction func crossfade(_ sender: Any) {
        // worky crossfader
        let value = self.crossfader.value
        var volumes = crossFade(t: value)
        let gain2 = volumes[0]
        let gain1 = volumes[1]
        DispatchQueue.main.async {
            self.player1_xfadegain.outputVolume = Float(gain1)
            self.player2_xfadegain.outputVolume = Float(gain2)
        }
    }
    
    // function which gets the volumes for crossfading
    func crossFade(t: Float) -> [Float] {
        var volumes: [Float] = [0.0, 0.0]
        volumes[0] = sqrt(0.5 * (1.0 + t));
        volumes[1] = sqrt(0.5 * (1.0 - t));
        return volumes;
    }
    
    // update waveform play positions while playing
    @objc func updateWaveformTimes(){
            var sampleRateSong: Float = 0.0
            let startInSongSeconds: Float = 0.0
            var songFormat: AVAudioFormat
            
            if self.player1.isPlaying {
                if (self.audioFormat1 == nil) {
                    // no track is loaded
                    return
                }
                songFormat = self.audioFormat1!
                sampleRateSong = Float(songFormat.sampleRate)
                
                let nodeTime: AVAudioTime? = self.player1.lastRenderTime
                var playerTime: AVAudioTime? = nil
                if let nodeTime = nodeTime {
                    playerTime = self.player1.playerTime(forNodeTime: nodeTime)
                }
                let elapsedSeconds = Float(startInSongSeconds + (Float(playerTime!.sampleTime) / sampleRateSong)) + Float(self.time_offset1)
                
                // this is probably better than the callback, which fires too early
                if Double(elapsedSeconds) >= Double(audioLengthSeconds1) {
                    self.timer1.invalidate()
                    return
                }
                self.scWaveform1.progressTime = CMTime(seconds: Double(elapsedSeconds), preferredTimescale: 1)

                self.runningWaveform1.seconds = Double(elapsedSeconds)
                self.runningWaveform1.setNeedsDisplay()
            }
    }
    
    @objc func updateWaveformTimes2() {
        var sampleRateSong: Double = 0.0
        let startInSongSeconds: Double = 0.0
        var songFormat: AVAudioFormat
        if self.player2.isPlaying {
            if (self.audioFormat2 == nil) {
                // no track is loaded
                return
            }
            songFormat = self.audioFormat2!
            sampleRateSong = Double(songFormat.sampleRate)
            
            let nodeTime: AVAudioTime? = self.player2.lastRenderTime
            var playerTime: AVAudioTime? = nil
            if let nodeTime = nodeTime {
                playerTime = self.player2.playerTime(forNodeTime: nodeTime)
            }
            let elapsedSeconds = startInSongSeconds + (Double(playerTime!.sampleTime) / sampleRateSong) + self.time_offset2
            // this is probably better than the callback, which fires too early
            if elapsedSeconds >= Double(audioLengthSeconds2) {
                self.timer2.invalidate()
                return
            }
            self.scWaveform2.progressTime = CMTime(seconds: Double(elapsedSeconds), preferredTimescale: 1)
            
            self.runningWaveform2.seconds = elapsedSeconds
            self.runningWaveform2.setNeedsDisplay()
        }
    }
    
    // load a track to left or right deck
    func load(left: Bool, url: String) {
        if(left) {
            print("Loading deck 1")
            self.player1.stop()
            time_offset1 = 0
        } else {
            print("Loading deck 2")
            self.player2.stop()
            time_offset2 = 0
        }
        guard let url = URL(string: url) else {
            print("Error: cannot create URL")
            return
        }
         let urlRequest = URLRequest(url: url)
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        // get track JSON
        let task = session.dataTask(with: urlRequest, completionHandler: {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error getting track")
                print(error!)
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            // parse the result as JSON, since that's what the API provides
            let json = try? JSONSerialization.jsonObject(with: responseData, options: [])
            let dictionary = json as? [String: Any]
            let streamUrl = dictionary?["stream_url"] as? String
            if (streamUrl == nil) {
                print("No stream url")
                return
            }
            let streamUrlWithClientId = "\(streamUrl!)?client_id=\(client_id)"
            print(streamUrl!)
            let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
            // download the mp3 file
            AF.download(streamUrlWithClientId, to: destination).response { response in
                print(response.fileURL!)
                if(left){
                    self.audioFileURL1 = response.fileURL
                } else {
                    self.audioFileURL2 = response.fileURL
                }
                print("File loaded")
                self.readToDeckFromBuffer(left: left, at: nil)
                
                // load waveform
                if(left == true) {
                    let asset: AVAsset? = AVURLAsset(url: self.audioFileURL1!)
                    self.scWaveform1.asset = asset
                    self.scWaveform1.normalColor = UIColor.orange
                    self.scWaveform1.progressColor = UIColor.white
                    self.scWaveform1.progressTime = CMTime(seconds: 0, preferredTimescale: 1)
                    self.scWaveform1.backgroundColor = UIColor(white: 1, alpha: 0.0)
                } else {
                    let asset: AVAsset? = AVURLAsset(url: self.audioFileURL2!)
                    self.scWaveform2.asset = asset
                    self.scWaveform2.normalColor = UIColor.blue
                    self.scWaveform2.progressColor = UIColor.white
                    self.scWaveform2.progressTime = CMTime(seconds: 0, preferredTimescale: 1)
                    self.scWaveform2.backgroundColor = UIColor(white: 1, alpha: 0.0)
                }
                
                let realm = try! Realm()
                // attempt to find existing objects
                let metadatas = realm.objects(AudioMetadata.self).filter("url = %@", streamUrl!)
                
                var no_remote_metadatas: Bool = true
                if(metadatas.count == 0) {
                    // no local metadata, try api.mixflame.com
                    let parameters: [String: String] = [
                        "token" : "ZWNkY2FlMGJlMzMwMjRkOWNkM2JkNDIw",
                        "url": streamUrl!,
                        "action": "get"
                    ]
                
                    let url = "https://api.mixflame.com/.netlify/functions/tracks"
                    
                    AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                        .responseJSON { response in
                            print(response)
                            //to get status code
                            if let status = response.response?.statusCode {
                                switch(status){
                                case 200:
                                    print("Success getting metadata from API")
                                default:
                                    print("Error getting metadata from API: \(status)")
                                }
                            }
                            //to get JSON return value
                            if let result = response.result.value {
                                let JSON = result as! NSDictionary
                                if (left) {
                                    self.key1 = JSON["key"] as! String
                                    self.tempo1 = JSON["bpm"] as! Float
                                    self.bpm1.text = String(format: "%.2f", self.tempo1)
                                    self.key_display1.text = self.key1
                                } else {
                                    self.key2 = JSON["key"] as! String
                                    self.tempo2 = JSON["bpm"] as! Float
                                    self.bpm2.text = String(format: "%.2f", self.tempo1)
                                    self.key_display2.text = self.key2
                                }
                                print(JSON)
                                print("Loaded key and tempo from JSON")
                                no_remote_metadatas = false
                            }
                            
                    }
                    
                }
            
                //decode mp3 (always, nothing supports mp3)
                let outputWav: String = "\(response.fileURL!.path.split(separator: ".")[0]).wav"
                
                var options = AKConverter.Options()
                // any options left nil will assume the value of the input file
                options.format = "wav"
                options.sampleRate = 44100
                options.bitDepth = 32
                let converter = AKConverter(inputURL: response.fileURL!, outputURL: URL(string: outputWav)!, options: options)
                converter.start(completionHandler: { error in
                    // check to see if error isn't nil, otherwise you're good
                    if (error != nil) {
                        print("Conversion failed.")
                    } else {
                        print("Conversion succeeded.");
                    }
                })
                
                // generate the colored waveform
                let cstr1 = (URL(string: outputWav)!.path as NSString).utf8String
                generateWaveformColors(cstr1!)
                
                if (metadatas.count == 0 && no_remote_metadatas) {
                    // no saved metadata. analyze
                    
                    // process the Wav
                    let processed: String
                    if (left) {
                        processed = "\(self.audioFileURL1!.path.split(separator: ".")[0]).raw"
                    } else {
                        processed = "\(self.audioFileURL2!.path.split(separator: ".")[0]).raw"
                    }
                    processWav(URL(string: outputWav), URL(string: processed))
                    print("Processing finished. \(processed)")
                    
                    //  run BPM detector on raw
                    let cstr = (URL(string: processed)!.path as NSString).utf8String
                    
                    if (left) {
                        self.tempo1 = processFile(cstr!)
                        self.bpm1.text = String(format: "%.2f", self.tempo1)
                        print("BPM: ", self.tempo1)
                    } else {
                        self.tempo2 = processFile(cstr!)
                        self.bpm2.text = String(format: "%.2f", self.tempo2)
                        print("BPM: ", self.tempo2)
                    }
                    
                    
                    
                    // run key detector on raw
                    var nameBuf = [Int8](repeating: 0, count: 2) // Buffer for C string
                    getKey(cstr, &nameBuf, nameBuf.count)
                    let name = String(cString: nameBuf)
                    print("Key: ", name)
                    if (left) {
                        self.key1 = name
                        self.key_display1.text = name
                    } else {
                        self.key2 = name
                        self.key_display2.text = name
                    }
                    
                    // prepare metadata object (realm)
                    let audioMetadata = AudioMetadata()
                    audioMetadata.url = streamUrl!
                    audioMetadata.key = name
                    if (left) {
                        audioMetadata.bpm = Double(self.tempo1)
                    } else {
                        audioMetadata.bpm = Double(self.tempo2)
                    }
                    // if none write the metadata
                    try! realm.write {
                        realm.delete(metadatas)
                        realm.add(audioMetadata)
                    }
                    
                    // write metadata to mixflame
                    let parameters: [String: String] = [
                        "token" : "ZWNkY2FlMGJlMzMwMjRkOWNkM2JkNDIw",
                        "url": streamUrl!,
                        "action": "set",
                        "bpm": left ? String(self.tempo1) : String(self.tempo2),
                        "key": name
                    ]
                    
                    let url = "https://api.mixflame.com/.netlify/functions/tracks"
                    
                    AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                        .responseJSON { response in
                            
                            if let status = response.response?.statusCode {
                                switch(status){
                                case 200:
                                    print("Successfully added a metadata to API")
                                default:
                                    print("Error adding metadata to API: \(status)")
                                }
                            }
                            
                            if let result = response.result.value {
                                let JSON = result as! NSDictionary
                                let status = JSON["status"] as! String
                                print("Post metadata status: ", status)
                            }
                            
                    }

                } else if (metadatas.count > 0 && no_remote_metadatas) {
                    // load metadata from local db
                    let metadata = metadatas.first!
                    if (left) {
                        self.tempo1 = Float(metadata.bpm)
                        self.bpm1.text = String(format: "%.2f", self.tempo1)
                        self.key1 = metadata.key
                        self.key_display1.text = metadata.key
                    } else {
                        self.tempo2 = Float(metadata.bpm)
                        self.bpm2.text = String(format: "%.2f", self.tempo2)
                        self.key2 = metadata.key
                        self.key_display2.text = metadata.key
                    }
                }
                
                // current tempo is initially the same as song tempo
                if(left) {
                    self.current_tempo1 = Double(self.tempo1)
                } else {
                    self.current_tempo2 = Double(self.tempo2)
                }
                
                // set bpm and key display colors, red means won't mix, green means will mix
                if (self.key1 != "" && self.key2 != "") {
                    let left_number = Int(String(self.key1.prefix(self.key1.count-1)))
                    let left_mode = String(self.key1.suffix(1))
                    let right_number = Int(String(self.key2.prefix(self.key2.count-1)))
                    let right_mode = String(self.key2.suffix(1))
                    let willMix = will_mix(last_number: left_number!, last_mode: left_mode, mode: right_mode, number: right_number!)
                    print("Will mix harmonically? ", willMix)
                    if(willMix) {
                        self.key_display1.textColor = UIColor.green
                        self.key_display2.textColor = UIColor.green
                    } else {
                        self.key_display1.textColor = UIColor.red
                        self.key_display2.textColor = UIColor.red
                    }
                }
                if (self.tempo1 != 0 && self.tempo2 != 0) {
                    let tempos_will_mix = tempos_are_good(lasttempo: self.tempo1, tempo: self.tempo2)
                    if (tempos_will_mix) {
                        self.bpm1.textColor = UIColor.green
                        self.bpm2.textColor = UIColor.green
                    } else {
                        self.bpm1.textColor = UIColor.red
                        self.bpm2.textColor = UIColor.red
                    }
                }
            }
        })
        task.resume()
    }
    
    func postLoad(left: Bool) {
        // must be run on main thread
        if(left){
            self.runningWaveform1.buffer = self.buffer1
            self.runningWaveform1.duration = Double(self.audioLengthSeconds1)
            self.runningWaveform1.isTop = true
            self.runningWaveform1.setNeedsDisplay() // first set loads waveform cache
        } else {
            self.runningWaveform2.buffer = self.buffer2
            self.runningWaveform2.duration = Double(self.audioLengthSeconds2)
            self.runningWaveform2.isTop = false
            self.runningWaveform2.setNeedsDisplay()
        }
        
        // set initial waveform display
        if(left) {
            self.runningWaveform1.seconds = 0
            self.runningWaveform1.setNeedsDisplay()
        } else {
            self.runningWaveform2.seconds = 0
            self.runningWaveform2.setNeedsDisplay()
        }
    }

}


