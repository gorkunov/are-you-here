// are-you-here: checks via the webcam whether someone is sitting at the Mac.
//
// Exit codes:  0 = person present, 1 = nobody there, 2 = error (no camera / no permission)
//
// Uses only built-in macOS frameworks (AVFoundation + Vision), so no dependencies.
// Run via the wrapper, which compiles and caches the binary: sh are-you-here.sh

import AVFoundation
import Foundation
import Vision

struct Options {
    var timeout: Double = 3.0   // seconds to keep looking before deciding "not here"
    var warmupFrames = 5        // first frames are often dark while exposure adjusts
    var quiet = false
    var verbose = false
}

func parseArgs() -> Options {
    var opts = Options()
    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = args.next() {
        switch arg {
        case "-t", "--timeout":
            guard let v = args.next(), let t = Double(v), t > 0 else { fail("--timeout needs a positive number") }
            opts.timeout = t
        case "-q", "--quiet": opts.quiet = true
        case "-v", "--verbose": opts.verbose = true
        case "-h", "--help":
            print("""
            usage: are-you-here [-t SECONDS] [-q] [-v]

            Looks through the webcam for a person (face or upper body).
              -t, --timeout SECONDS   how long to look before giving up (default 3)
              -q, --quiet             print nothing, only set the exit code
              -v, --verbose           log per-frame detections to stderr

            exit 0 = present, 1 = absent, 2 = error
            """)
            exit(0)
        default: fail("unknown argument: \(arg) (try --help)")
        }
    }
    return opts
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("are-you-here: \(msg)\n".data(using: .utf8)!)
    exit(2)
}

final class PresenceDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let opts: Options
    private let done = DispatchSemaphore(value: 0)
    private var framesSeen = 0
    private var finished = false
    private(set) var present = false

    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let bodyRequest: VNDetectHumanRectanglesRequest = {
        let r = VNDetectHumanRectanglesRequest()
        r.upperBodyOnly = true
        return r
    }()

    init(opts: Options) { self.opts = opts }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !finished, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        framesSeen += 1
        if framesSeen <= opts.warmupFrames { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, options: [:])
        try? handler.perform([faceRequest, bodyRequest])
        let faces = (faceRequest.results ?? []).filter { $0.confidence > 0.5 }
        let bodies = (bodyRequest.results ?? []).filter { $0.confidence > 0.5 }

        if opts.verbose {
            FileHandle.standardError.write("frame \(framesSeen): faces=\(faces.count) bodies=\(bodies.count)\n".data(using: .utf8)!)
        }
        if !faces.isEmpty || !bodies.isEmpty {
            present = true
            finished = true
            done.signal()
        }
    }

    /// Returns true if someone was seen before the timeout.
    func run() -> Bool {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video, position: .unspecified
        ).devices.first ?? AVCaptureDevice.default(for: .video)
        guard let device else { fail("no camera found") }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            fail("cannot open camera \"\(device.localizedName)\"")
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "frames"))
        guard session.canAddOutput(output) else { fail("cannot read frames from camera") }
        session.addOutput(output)

        session.startRunning()
        _ = done.wait(timeout: .now() + opts.timeout + 1.0) // +1s for camera startup
        session.stopRunning()
        return present
    }
}

func ensureCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return
    case .notDetermined:
        let sem = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .video) { granted = $0; sem.signal() }
        sem.wait()
        if !granted { fail("camera access denied") }
    default:
        fail("camera access denied — allow your terminal app in System Settings › Privacy & Security › Camera")
    }
}

let opts = parseArgs()
ensureCameraAccess()
let here = PresenceDetector(opts: opts).run()
if !opts.quiet { print(here ? "present" : "absent") }
exit(here ? 0 : 1)
