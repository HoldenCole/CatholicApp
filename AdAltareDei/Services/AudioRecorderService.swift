import AVFoundation
import Combine

/// Audio recording service for user practice recordings (v1.4).
/// Records to the app's Documents directory.
@MainActor
class AudioRecorderService: ObservableObject {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var permissionGranted = false

    private var recorder: AVAudioRecorder?

    func requestPermission() async {
        if #available(iOS 17, *) {
            permissionGranted = await AVAudioApplication.requestRecordPermission()
        }
    }

    func startRecording(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent("\(fileName).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            recorder = try AVAudioRecorder(url: audioURL, settings: settings)
            recorder?.record()
            isRecording = true
            recordingURL = audioURL
        } catch {
            isRecording = false
        }
    }

    func stopRecording() {
        recorder?.stop()
        isRecording = false
    }
}
