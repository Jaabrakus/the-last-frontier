// The tour video's encoder and checks (macOS, AVFoundation: nothing to install).
//
//   swiftc -O tools/environment/tour_video_encode.swift -o <scratch>/tour_encode
//   tour_encode encode <frames dir> <fps> <out.mp4> [audio.wav] [bitrate, default 16000000]
//   tour_encode check  <movie.mp4>                     every frame decoded: black frames, repeated frames, jumps
//   tour_encode sheet  <movie.mp4> <out.png> <t,t,...> [cols, default 3]   a contact sheet from the finished file
//   tour_encode frames <movie.mp4> <out dir> <t,t,...>                    single frames as PNG
//   tour_encode join   <out.mp4> <in.mp4> <in.mp4> ...                  films one after the other (same size and codecs:
//                                                                         the samples are copied, not encoded again)
//
// encode: the JPEG / PNG frames of tools/environment/tour_video.gd (sorted by name) become an H.264 High profile
// .mp4 (BT.709) at `fps`; with a WAV (tools/environment/tour_video_audio.py) an AAC track is added. check: decodes
// the whole file and prints its length, tracks, and any frame that is near black (mean luma < 0.03), an exact repeat
// of the one before (a stutter) or a jump in the picture far above its neighbours (a cut or a flash).

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ msg: String) -> Never {
	FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
	exit(1)
}

func loadImage(_ url: URL) -> CGImage? {
	guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
	return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func savePNG(_ image: CGImage, _ path: String) {
	let url = URL(fileURLWithPath: path) as CFURL
	guard let dst = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
		fail("cannot write \(path)")
	}
	CGImageDestinationAddImage(dst, image, nil)
	CGImageDestinationFinalize(dst)
}

// MARK: encode

func encode(framesDir: String, fps: Int32, out: String, wav: String?, bitrate: Int) {
	let fm = FileManager.default
	let dir = URL(fileURLWithPath: framesDir)
	let names = ((try? fm.contentsOfDirectory(atPath: framesDir)) ?? [])
		.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }.sorted()
	guard let firstName = names.first, let first = loadImage(dir.appendingPathComponent(firstName)) else {
		fail("no frames in \(framesDir)")
	}
	let w = first.width, h = first.height
	let outURL = URL(fileURLWithPath: out)
	try? fm.removeItem(at: outURL)
	guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else { fail("cannot create \(out)") }
	let video: [String: Any] = [
		AVVideoCodecKey: AVVideoCodecType.h264,
		AVVideoWidthKey: w,
		AVVideoHeightKey: h,
		AVVideoColorPropertiesKey: [
			AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
			AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
			AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
		],
		AVVideoCompressionPropertiesKey: [
			AVVideoAverageBitRateKey: bitrate,
			AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
			AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
			AVVideoExpectedSourceFrameRateKey: Int(fps),
			AVVideoAllowFrameReorderingKey: true,
		],
	]
	let vin = AVAssetWriterInput(mediaType: .video, outputSettings: video)
	vin.expectsMediaDataInRealTime = false
	let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: [
		kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
		kCVPixelBufferWidthKey as String: w,
		kCVPixelBufferHeightKey as String: h,
	])
	writer.add(vin)

	var ain: AVAssetWriterInput?
	var reader: AVAssetReader?
	var rout: AVAssetReaderTrackOutput?
	if let wav = wav {
		let asset = AVURLAsset(url: URL(fileURLWithPath: wav))
		guard let track = asset.tracks(withMediaType: .audio).first else { fail("no audio in \(wav)") }
		guard let r = try? AVAssetReader(asset: asset) else { fail("cannot read \(wav)") }
		let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
			AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
			AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
		])
		r.add(o)
		var rate = 48000.0
		var channels = 2
		if let desc = track.formatDescriptions.first,
			let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc as! CMAudioFormatDescription) {
			rate = asbd.pointee.mSampleRate
			channels = Int(asbd.pointee.mChannelsPerFrame)
		}
		let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
			AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate, AVNumberOfChannelsKey: channels,
			AVEncoderBitRateKey: 192000,
		])
		a.expectsMediaDataInRealTime = false
		writer.add(a)
		ain = a
		reader = r
		rout = o
	}
	guard writer.startWriting() else { fail("writer: \(String(describing: writer.error))") }
	writer.startSession(atSourceTime: .zero)
	reader?.startReading()

	let group = DispatchGroup()
	let vq = DispatchQueue(label: "video")
	var index = 0
	group.enter()
	vin.requestMediaDataWhenReady(on: vq) {
		while vin.isReadyForMoreMediaData {
			if index >= names.count {
				vin.markAsFinished()
				group.leave()
				return
			}
			autoreleasepool {
				guard let img = loadImage(dir.appendingPathComponent(names[index])) else {
					fail("cannot read \(names[index])")
				}
				var pb: CVPixelBuffer?
				CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
				guard let buf = pb else { fail("no pixel buffer") }
				CVPixelBufferLockBaseAddress(buf, [])
				let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h, bitsPerComponent: 8,
					bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
					bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
				ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
				CVPixelBufferUnlockBaseAddress(buf, [])
				if !adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps)) {
					fail("append frame \(index): \(String(describing: writer.error))")
				}
			}
			index += 1
			if index % 300 == 0 {
				print("  \(index) / \(names.count) frames")
			}
		}
	}
	if let a = ain, let o = rout {
		let aq = DispatchQueue(label: "audio")
		group.enter()
		a.requestMediaDataWhenReady(on: aq) {
			while a.isReadyForMoreMediaData {
				if let sb = o.copyNextSampleBuffer() {
					a.append(sb)
				} else {
					a.markAsFinished()
					group.leave()
					return
				}
			}
		}
	}
	group.wait()
	let done = DispatchSemaphore(value: 0)
	writer.finishWriting { done.signal() }
	done.wait()
	if writer.status != .completed {
		fail("writer failed: \(String(describing: writer.error))")
	}
	let size = ((try? fm.attributesOfItem(atPath: out))?[.size] as? Int) ?? 0
	print(String(format: "ENCODED %@  %d frames %dx%d @ %d fps = %.2f s, %.1f MB%@", out, names.count, w, h, fps,
		Double(names.count) / Double(fps), Double(size) / 1e6, wav != nil ? ", with sound" : ""))
}

// MARK: check

func check(_ path: String) {
	let asset = AVURLAsset(url: URL(fileURLWithPath: path))
	guard let track = asset.tracks(withMediaType: .video).first else { fail("no video track") }
	let audio = asset.tracks(withMediaType: .audio).first
	print(String(format: "MOVIE %@  %.2f s  %dx%d  %.2f fps  audio: %@", path, CMTimeGetSeconds(asset.duration),
		Int(track.naturalSize.width), Int(track.naturalSize.height), track.nominalFrameRate,
		audio != nil ? String(format: "%.2f s", CMTimeGetSeconds(audio!.timeRange.duration)) : "none"))
	guard let reader = try? AVAssetReader(asset: asset) else { fail("cannot read") }
	let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
		kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
	])
	reader.add(out)
	reader.startReading()
	var lumas: [Double] = []
	var diffs: [Double] = []
	var times: [Double] = []
	var prev: [UInt8] = []
	while let sb = out.copyNextSampleBuffer() {
		guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
		CVPixelBufferLockBaseAddress(pb, .readOnly)
		let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), row = CVPixelBufferGetBytesPerRow(pb)
		let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
		// a 64 x 36 grid of samples
		var grid = [UInt8](repeating: 0, count: 64 * 36)
		var sum = 0.0
		for gy in 0..<36 {
			for gx in 0..<64 {
				let p = base + (gy * h / 36 + h / 72) * row + (gx * w / 64 + w / 128) * 4
				let l = (Int(p[2]) * 54 + Int(p[1]) * 183 + Int(p[0]) * 19) >> 8
				grid[gy * 64 + gx] = UInt8(l)
				sum += Double(l)
			}
		}
		CVPixelBufferUnlockBaseAddress(pb, .readOnly)
		lumas.append(sum / (64.0 * 36.0 * 255.0))
		times.append(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb)))
		if prev.isEmpty {
			diffs.append(0)
		} else {
			var d = 0
			for i in 0..<grid.count { d += abs(Int(grid[i]) - Int(prev[i])) }
			diffs.append(Double(d) / Double(grid.count) / 255.0)
		}
		prev = grid
	}
	print("decoded \(lumas.count) frames")
	var black = 0, repeats = 0, jumps = 0
	for i in 0..<lumas.count {
		if lumas[i] < 0.03 {
			black += 1
			if black <= 12 { print(String(format: "  near black  frame %5d  %6.2f s  luma %.3f", i, times[i], lumas[i])) }
		}
		if i > 0 && diffs[i] == 0 {
			repeats += 1
			if repeats <= 12 { print(String(format: "  repeat      frame %5d  %6.2f s", i, times[i])) }
		}
		if i > 2 && i + 3 < lumas.count {
			let around = [diffs[i - 2], diffs[i - 1], diffs[i + 1], diffs[i + 2]].sorted()
			let med = (around[1] + around[2]) / 2
			if diffs[i] > 0.04 && diffs[i] > 4 * med {
				jumps += 1
				if jumps <= 30 {
					print(String(format: "  jump        frame %5d  %6.2f s  change %.3f (neighbours %.3f)  luma %.3f", i, times[i], diffs[i], med, lumas[i]))
				}
			}
		}
	}
	let secs = Int(ceil(times.last ?? 0))
	var line = "luma per second:"
	for s in 0..<secs {
		let sel = lumas.indices.filter { Int(times[$0]) == s }
		if sel.isEmpty { continue }
		line += String(format: " %.2f", sel.map { lumas[$0] }.reduce(0, +) / Double(sel.count))
	}
	print(line)
	print("CHECK frames=\(lumas.count) near_black=\(black) repeats=\(repeats) jumps=\(jumps)")
}

// MARK: sheet / frames

func grab(_ path: String, _ times: [Double]) -> [CGImage] {
	let asset = AVURLAsset(url: URL(fileURLWithPath: path))
	let gen = AVAssetImageGenerator(asset: asset)
	gen.requestedTimeToleranceBefore = .zero
	gen.requestedTimeToleranceAfter = .zero
	gen.appliesPreferredTrackTransform = true
	return times.map { t in
		guard let img = try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else {
			fail("no frame at \(t) s")
		}
		return img
	}
}

func sheet(_ path: String, _ out: String, _ times: [Double], cols: Int) {
	let imgs = grab(path, times)
	let tw = 640, th = 640 * imgs[0].height / imgs[0].width
	let rows = (imgs.count + cols - 1) / cols
	let ctx = CGContext(data: nil, width: tw * cols, height: th * rows, bitsPerComponent: 8, bytesPerRow: 0,
		space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
	ctx.interpolationQuality = .high
	for (i, img) in imgs.enumerated() {
		let x = (i % cols) * tw, y = (rows - 1 - i / cols) * th
		ctx.draw(img, in: CGRect(x: x, y: y, width: tw, height: th))
	}
	savePNG(ctx.makeImage()!, out)
	print("SHEET \(out)  \(imgs.count) frames at \(times.map { String(format: "%.1f", $0) }.joined(separator: ", ")) s")
}

func frames(_ path: String, _ outDir: String, _ times: [Double]) {
	try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
	for (t, img) in zip(times, grab(path, times)) {
		let p = (outDir as NSString).appendingPathComponent(String(format: "t%06.2f.png", t))
		savePNG(img, p)
		print("FRAME \(p)")
	}
}

// MARK: join

func join(_ out: String, _ inputs: [String]) {
	let comp = AVMutableComposition()
	guard let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
		let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
		fail("cannot make the composition")
	}
	var cursor = CMTime.zero
	for path in inputs {
		let asset = AVURLAsset(url: URL(fileURLWithPath: path))
		let dur = asset.duration
		let range = CMTimeRange(start: .zero, duration: dur)
		guard let v = asset.tracks(withMediaType: .video).first else { fail("no video in \(path)") }
		do {
			try vt.insertTimeRange(range, of: v, at: cursor)
			if let a = asset.tracks(withMediaType: .audio).first {
				try at.insertTimeRange(CMTimeRange(start: .zero, duration: min(dur, a.timeRange.duration)), of: a, at: cursor)
			}
		} catch {
			fail("cannot add \(path): \(error)")
		}
		cursor = CMTimeAdd(cursor, dur)
	}
	let outURL = URL(fileURLWithPath: out)
	try? FileManager.default.removeItem(at: outURL)
	guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough) else { fail("no export session") }
	ex.outputURL = outURL
	ex.outputFileType = .mp4
	let done = DispatchSemaphore(value: 0)
	ex.exportAsynchronously { done.signal() }
	done.wait()
	if ex.status != .completed {
		fail("join failed: \(String(describing: ex.error))")
	}
	let size = ((try? FileManager.default.attributesOfItem(atPath: out))?[.size] as? Int) ?? 0
	print(String(format: "JOINED %@  %d films = %.2f s, %.1f MB", out, inputs.count, CMTimeGetSeconds(cursor), Double(size) / 1e6))
}

// MARK: main

let a = CommandLine.arguments
func times(_ s: String) -> [Double] { s.split(separator: ",").compactMap { Double($0) } }
guard a.count >= 3 else { fail("usage: see the header of tour_video_encode.swift") }
switch a[1] {
case "encode":
	guard a.count >= 5 else { fail("encode <frames dir> <fps> <out.mp4> [audio.wav] [bitrate]") }
	let wav = a.count > 5 && a[5] != "-" ? a[5] : nil
	encode(framesDir: a[2], fps: Int32(a[3]) ?? 30, out: a[4], wav: wav, bitrate: a.count > 6 ? Int(a[6]) ?? 16_000_000 : 16_000_000)
case "check":
	check(a[2])
case "sheet":
	guard a.count >= 5 else { fail("sheet <movie> <out.png> <t,t,...> [cols]") }
	sheet(a[2], a[3], times(a[4]), cols: a.count > 5 ? Int(a[5]) ?? 3 : 3)
case "frames":
	guard a.count >= 5 else { fail("frames <movie> <out dir> <t,t,...>") }
	frames(a[2], a[3], times(a[4]))
case "join":
	guard a.count >= 4 else { fail("join <out.mp4> <in.mp4> <in.mp4> ...") }
	join(a[2], Array(a[3...]))
default:
	fail("unknown mode \(a[1])")
}
