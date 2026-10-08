// Add a caller-supplied rights notice to a NEW MP4 copy without re-encoding.
// macOS / AVFoundation. Build:
//   swiftc -O tools/showcase/video_rights.swift -o /private/tmp/video_rights
// Usage:
//   video_rights input.mp4 output.mp4 --notice 'Exact notice' [--creator 'Exact name']
//   video_rights inspect input.mp4
//
// Stores a JSON document in standard ISO MP4 description metadata, containing the
// exact notice, a random asset ID, source-file SHA256 and optional supplied creator.
// Existing metadata is retained and checked. Encoded audio/video bytes and decoded
// playback timestamps/audio samples are checked before publishing the output.
// AVFoundation may regroup compressed buffers or change padding beyond the edit;
// those container details are not playback timing. Refuses existing outputs.
// If MP4 cannot retain existing metadata alongside the notice (e.g. an existing
// same-language ISO description), verification fails without publishing a copy.
//
// This is removable container metadata: no pixels are changed. It is not a pixel
// watermark, DRM, an AI-blocking mechanism, a signature, a C2PA credential, or proof
// of ownership/trademark registration. The tool invents no rights-holder identity.

import AVFoundation
import CryptoKit
import Foundation

enum RightsError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self { case .message(let text): return text }
    }
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw RightsError.message(message) }
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func fileHash(_ url: URL) throws -> String {
    sha256(try Data(contentsOf: url, options: .mappedIfSafe))
}

func metadataDescription(_ item: AVMetadataItem) -> [String: String] {
    var value = ["identifier": item.identifier?.rawValue ?? "",
                 "key_space": item.keySpace?.rawValue ?? "",
                 "key": String(describing: item.key ?? "" as NSString),
                 "language": item.extendedLanguageTag ?? ""]
    if let text = item.stringValue { value["value"] = text }
    else if let data = item.dataValue { value["data_base64"] = data.base64EncodedString() }
    else { value["value"] = String(describing: item.value) }
    return value
}

func metadataFingerprint(_ item: AVMetadataItem) throws -> String {
    String(data: try JSONSerialization.data(withJSONObject: metadataDescription(item), options: [.sortedKeys]), encoding: .utf8)!
}

func item(_ id: AVMetadataIdentifier, _ text: String) -> AVMetadataItem {
    let value = AVMutableMetadataItem()
    value.identifier = id
    value.value = text as NSString
    value.dataType = kCMMetadataBaseDataType_UTF8 as String
    value.extendedLanguageTag = "und"
    return value
}

func timeKey(_ time: CMTime) -> String {
    if !time.isValid { return "invalid" }
    if time.isIndefinite { return "indefinite" }
    // Compare equivalent timescales at nanosecond precision.
    return String(CMTimeConvertScale(time, timescale: 1_000_000_000, method: .roundHalfAwayFromZero).value)
}

func streams(_ asset: AVAsset) throws -> [[String: Any]] {
    var result: [[String: Any]] = []
    for track in asset.tracks where track.mediaType == .video || track.mediaType == .audio {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        try require(reader.canAdd(output), "Cannot inspect compressed \(track.mediaType.rawValue) samples")
        reader.add(output)
        try require(reader.startReading(), "Cannot read samples: \(String(describing: reader.error))")
        var payload = SHA256()
        var timings = SHA256()
        var buffers = 0
        var samples = 0
        var timeRows: [String] = []
        while let buffer = output.copyNextSampleBuffer() {
            buffers += 1
            samples += CMSampleBufferGetNumSamples(buffer)
            if let block = CMSampleBufferGetDataBuffer(buffer) {
                let count = CMBlockBufferGetDataLength(block)
                var bytes = Data(count: count)
                let status = bytes.withUnsafeMutableBytes { pointer in
                    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: pointer.baseAddress!)
                }
                try require(status == kCMBlockBufferNoErr, "Cannot inspect compressed payload")
                payload.update(data: bytes)
            }
            let row = [timeKey(CMSampleBufferGetPresentationTimeStamp(buffer)),
                       timeKey(CMSampleBufferGetDecodeTimeStamp(buffer)),
                       timeKey(CMSampleBufferGetDuration(buffer)),
                       String(CMSampleBufferGetNumSamples(buffer))].joined(separator: ",") + "\n"
            if CMSampleBufferGetNumSamples(buffer) > 0 {
                timings.update(data: Data(row.utf8))
                timeRows.append(row.trimmingCharacters(in: .newlines))
            }
        }
        try require(reader.status == .completed, "Sample read failed: \(String(describing: reader.error))")
        result.append(["type": track.mediaType.rawValue, "buffers": buffers, "samples": samples,
                       "start_ns": timeKey(track.timeRange.start), "duration_ns": timeKey(track.timeRange.duration),
                       "nominal_fps": track.nominalFrameRate,
                       "width": track.naturalSize.width, "height": track.naturalSize.height,
                       "transform": String(describing: track.preferredTransform),
                       "payload_sha256": payload.finalize().map { String(format: "%02x", $0) }.joined(),
                       "timing_head": Array(timeRows.prefix(5)), "timing_tail": Array(timeRows.suffix(2)),
                       "timing_sha256": timings.finalize().map { String(format: "%02x", $0) }.joined()])
    }
    return result
}

func json(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes])
}

func decodedPlayback(_ asset: AVAsset) throws -> [[String: Any]] {
    var result: [[String: Any]] = []
    for track in asset.tracks where track.mediaType == .video || track.mediaType == .audio {
        let video = track.mediaType == .video
        // Float PCM avoids nondeterministic dither observed with integer16 decode.
        let settings: [String: Any] = video
            ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            : [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
               AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false,
               AVLinearPCMIsNonInterleaved: false]
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        try require(reader.startReading(), "Cannot decode playback")
        var samples = 0
        var hash = SHA256()
        var first = CMTime.invalid
        var last = CMTime.invalid
        var rate = 0.0
        while let buffer = output.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
            if !first.isValid { first = pts }
            last = pts
            if video {
                hash.update(data: Data((timeKey(pts) + "\n").utf8))
            } else {
                if let format = CMSampleBufferGetFormatDescription(buffer),
                   let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) {
                    rate = asbd.pointee.mSampleRate
                }
                try require(rate > 0, "Missing decoded audio sample rate")
                let expected = first.seconds + Double(samples) / rate
                try require(abs(pts.seconds - expected) < 0.000001, "Decoded audio has a timing discontinuity")
                if let block = CMSampleBufferGetDataBuffer(buffer) {
                    let count = CMBlockBufferGetDataLength(block)
                    var bytes = Data(count: count)
                    let status = bytes.withUnsafeMutableBytes { pointer in
                        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: pointer.baseAddress!)
                    }
                    try require(status == kCMBlockBufferNoErr, "Cannot inspect decoded audio")
                    hash.update(data: bytes)
                }
            }
            samples += CMSampleBufferGetNumSamples(buffer)
        }
        try require(reader.status == .completed, "Playback decode failed: \(String(describing: reader.error))")
        var row: [String: Any] = ["type": track.mediaType.rawValue, "samples": samples,
            "first_pts_ns": timeKey(first), "duration_ns": timeKey(track.timeRange.duration),
            video ? "display_timestamps_sha256" : "decoded_pcm_sha256": hash.finalize().map { String(format: "%02x", $0) }.joined()]
        if video { row["last_pts_ns"] = timeKey(last) }
        else { row["sample_rate"] = rate; row["continuous"] = true }
        result.append(row)
    }
    return result
}

func essentialStreams(_ values: [[String: Any]]) -> [[String: Any]] {
    let keys = ["type", "samples", "start_ns", "duration_ns", "nominal_fps", "width", "height", "transform", "payload_sha256"]
    return values.map { value in Dictionary(uniqueKeysWithValues: keys.compactMap { key in value[key].map { (key, $0) } }) }
}

func inspect(_ url: URL) throws -> [String: Any] {
    let asset = AVURLAsset(url: url)
    return ["file": url.path, "sha256": try fileHash(url), "duration_ns": timeKey(asset.duration),
            "metadata": asset.metadata.map(metadataDescription), "streams": try streams(asset),
            "decoded_playback": try decodedPlayback(asset)]
}

func main() throws {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.count == 2 && args[0] == "inspect" {
        FileHandle.standardOutput.write(try json(inspect(URL(fileURLWithPath: args[1]))))
        print()
        return
    }
    try require(args.count >= 4, "Usage: video_rights input.mp4 output.mp4 --notice 'Exact notice' [--creator 'Exact name']; or inspect input.mp4")
    let input = URL(fileURLWithPath: args[0]).standardizedFileURL.resolvingSymlinksInPath()
    let output = URL(fileURLWithPath: args[1]).standardizedFileURL.resolvingSymlinksInPath()
    var notice: String?
    var creator: String?
    var index = 2
    while index < args.count {
        try require(index + 1 < args.count, "Missing option value")
        switch args[index] {
        case "--notice":
            try require(notice == nil, "Duplicate --notice")
            notice = args[index + 1]
        case "--creator":
            try require(creator == nil, "Duplicate --creator")
            creator = args[index + 1]
        default: throw RightsError.message("Unknown option: \(args[index])")
        }
        index += 2
    }
    try require(notice != nil && !notice!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "A nonempty caller-supplied notice is required")
    if let creator { try require(!creator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Creator must be nonempty when supplied") }
    try require(input != output, "Input and output must differ")
    let fm = FileManager.default
    try require(!fm.fileExists(atPath: output.path), "Output already exists; choose a new path")
    try require(input.pathExtension.lowercased() == "mp4" && output.pathExtension.lowercased() == "mp4", "This tool accepts MP4 input and output")
    let sourceHash = try fileHash(input)
    let asset = AVURLAsset(url: input)
    let originalMetadata = asset.metadata
    let originalStreams = try streams(asset)
    try require(!originalStreams.isEmpty, "No audio/video streams found")
    let assetID = "urn:uuid:" + UUID().uuidString.lowercased()
    var record: [String: Any] = ["schema": "video-rights-notice/v1", "asset_id": assetID,
                               "notice": notice!, "source_sha256": sourceHash]
    if let creator { record["creator"] = creator }
    let comment = String(data: try json(record), encoding: .utf8)!
    // MP4 export maps descriptions to ISO user data and filters iTunes comments.
    // Use its supported standard description directly; the exact notice is in JSON.
    var additions = [item(AVMetadataIdentifier(rawValue: "uiso/dscp"), comment)]
    if let creator { additions.append(item(AVMetadataIdentifier(rawValue: "uiso/auth"), creator)) }
    let temp = output.deletingLastPathComponent().appendingPathComponent(".video-rights-\(UUID().uuidString).mp4")
    defer { try? fm.removeItem(at: temp) }
    guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        throw RightsError.message("Passthrough export unavailable")
    }
    try require(exporter.supportedFileTypes.contains(.mp4), "MP4 passthrough unsupported for this asset")
    exporter.outputURL = temp
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = false
    exporter.metadata = originalMetadata + additions
    let done = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { done.signal() }
    done.wait()
    try require(exporter.status == .completed, "Export failed: \(String(describing: exporter.error))")
    let exported = AVURLAsset(url: temp)
    let actualStreams = try streams(exported)
    if try json(essentialStreams(originalStreams)) != json(essentialStreams(actualStreams)) {
        let difference = String(data: try json(["source": originalStreams, "exported": actualStreams]), encoding: .utf8)!
        throw RightsError.message("Encoded streams or timestamps changed; output not published\n" + difference)
    }
    let originalPlayback = try decodedPlayback(asset)
    let actualPlayback = try decodedPlayback(exported)
    if try json(originalPlayback) != json(actualPlayback) {
        let difference = String(data: try json(["source": originalPlayback, "exported": actualPlayback]), encoding: .utf8)!
        throw RightsError.message("Decoded playback timing or audio changed; output not published\n" + difference)
    }
    try require(timeKey(asset.duration) == timeKey(exported.duration), "Asset duration changed; output not published")
    let actualMetadata = exported.metadata
    var remaining = try actualMetadata.map(metadataFingerprint)
    for expected in originalMetadata + additions {
        let signature = try metadataFingerprint(expected)
        guard let position = remaining.firstIndex(of: signature) else {
            let found = String(data: try json(actualMetadata.map(metadataDescription)), encoding: .utf8)!
            throw RightsError.message("Metadata not preserved: \(metadataDescription(expected)); output not published\nReadback: " + found)
        }
        remaining.remove(at: position)
    }
    try require(try fileHash(input) == sourceHash, "Source changed during export")
    try fm.moveItem(at: temp, to: output)
    let report: [String: Any] = ["file": output.path, "sha256": try fileHash(output), "asset_id": assetID,
                               "source_sha256": sourceHash, "mode": "AVAssetExportPresetPassthrough",
                               "encoded_stream_payloads_unchanged": true,
                               "decoded_playback_timestamps_and_audio_unchanged": true,
                               "existing_metadata_preserved": true,
                               "duration_ns": timeKey(exported.duration),
                               "metadata": actualMetadata.map(metadataDescription), "streams": actualStreams,
                               "source_streams": originalStreams, "decoded_playback": actualPlayback]
    FileHandle.standardOutput.write(try json(report))
    print()
}

do { try main() }
catch {
    FileHandle.standardError.write(Data("video_rights: \(error)\n".utf8))
    exit(1)
}
