import AVFoundation
import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The storyboard's root view controller.
///
/// Edges (SHELL-FIXES 20): iOS holds touches near the left and right edges
/// back while it checks for a system swipe. Numory times a tap when it
/// reaches the game, so a tap in an edge column held back by iOS would count
/// against the player. Touches go to the game at once, and edge swipes need
/// a second swipe (the game has no swipes of its own).
///
/// Effects (iPhone only; the simulator doesn't suspend apps this way): the
/// audio plugin lets an effect stop at its end by itself and never pauses
/// it, so its player stays "told to play". Back in front, iOS rebuilt every
/// such player's audio one by one and played each effect the game had used
/// again, a burst of the whole game's sounds that also held the music up for
/// seconds (seen in Stretchy Frog). An effect player whose rate changes
/// without the game asking (its end, or iOS starting it again) is paused
/// here, so iOS has nothing to replay; effects still sounding are paused
/// when the app leaves the front and before its audio comes back on. The
/// game's own plays always carry `setRateCalled`.
///
/// Music: iOS deactivates a suspended app's audio session and says so only
/// once the app runs again, which can pause the music just after the game
/// resumed it. Back in front, the session is made active again, and an
/// interruption that arrives while the game is in front, or one that ends,
/// asks the game to play the music on ("numory/audio").
class GameViewController: FlutterViewController {
  private var audio: FlutterMethodChannel?

  /// Every player the audio plugin has used, seen through their rate changes.
  private let players = NSHashTable<AVPlayer>.weakObjects()

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.left, .right] }

  override func viewDidLoad() {
    super.viewDidLoad()
    audio = FlutterMethodChannel(name: "numory/audio", binaryMessenger: binaryMessenger)
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(resigningActive), name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    center.addObserver(forName: AVPlayer.rateDidChangeNotification, object: nil, queue: .main) { [weak self] note in
      guard let self, let p = note.object as? AVPlayer else { return }
      self.players.add(p)
      let reason = note.userInfo?[AVPlayer.rateDidChangeReasonKey] as? AVPlayer.RateDidChangeReason
      if reason != .setRateCalled && !Self.isMusic(p) {
        p.pause()
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.window?.gestureRecognizers?.forEach { $0.delaysTouchesBegan = false }
  }

  /// The loop is assets/audio/music.wav; every effect has another name.
  private static func isMusic(_ p: AVPlayer) -> Bool {
    ((p.currentItem?.asset as? AVURLAsset)?.url.lastPathComponent ?? "").hasPrefix("music")
  }

  private func hushEffects() {
    for p in players.allObjects where p.rate != 0 && !Self.isMusic(p) {
      p.pause()
    }
  }

  @objc private func resigningActive() {
    hushEffects()
  }

  @objc private func becameActive() {
    hushEffects()
    try? AVAudioSession.sharedInstance().setActive(true)
  }

  @objc private func interrupted(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw),
      type == .ended || UIApplication.shared.applicationState == .active
    else { return }
    // Fails harmlessly while a call still holds the audio; its end comes here.
    try? AVAudioSession.sharedInstance().setActive(true)
    audio?.invokeMethod("resume", arguments: nil)
  }
}
