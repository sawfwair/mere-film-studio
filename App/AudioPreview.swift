import AVFoundation
import SwiftUI

// MARK: - Audio preview

/// One shared preview player so takes never talk over each other; whichever
/// row is playing shows the stop control.
@MainActor
final class AudioPreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingURL: URL?
    private var player: AVAudioPlayer?

    func toggle(_ url: URL) {
        if playingURL == url {
            stop()
            return
        }
        stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        self.player = player
        player.play()
        playingURL = url
    }

    func stop() {
        player?.stop()
        player = nil
        playingURL = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

struct AudioPreviewButton: View {
    @ObservedObject var preview: AudioPreview
    let url: URL

    var body: some View {
        Button {
            preview.toggle(url)
        } label: {
            Image(systemName: preview.playingURL == url ? "stop.circle.fill" : "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Studio.accent)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(preview.playingURL == url ? "Stop" : "Play")
        .accessibilityLabel(preview.playingURL == url ? "Stop preview" : "Play preview")
    }
}
