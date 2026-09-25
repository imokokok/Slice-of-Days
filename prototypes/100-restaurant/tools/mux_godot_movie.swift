import Foundation
import AVFoundation

// Usage: swift tools/mux_godot_movie.swift silent.mp4 audio.wav final.mp4
let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let audioURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
let video = AVURLAsset(url: videoURL)
let audio = AVURLAsset(url: audioURL)
let composition = AVMutableComposition()
guard let sourceVideo = video.tracks(withMediaType: .video).first,
      let sourceAudio = audio.tracks(withMediaType: .audio).first,
      let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
      let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
else { fatalError("Missing video or audio track") }
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: video.duration), of: sourceVideo, at: .zero)
videoTrack.preferredTransform = sourceVideo.preferredTransform
try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audio.duration), of: sourceAudio, at: .zero)
try? FileManager.default.removeItem(at: outputURL)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    fatalError("Cannot create AV export session")
}
exporter.outputURL = outputURL
exporter.outputFileType = .mp4
exporter.shouldOptimizeForNetworkUse = true
let done = DispatchSemaphore(value: 0)
exporter.exportAsynchronously { done.signal() }
done.wait()
guard exporter.status == .completed else {
    fatalError("Movie export failed: \(exporter.error?.localizedDescription ?? "unknown")")
}
let result = AVURLAsset(url: outputURL)
print("MP4 ready: \(result.duration.seconds)s, video=\(result.tracks(withMediaType: .video).count), audio=\(result.tracks(withMediaType: .audio).count)")
