import UIKit

/// One-time iOS keyboard pre-warm.
///
/// The first time a UITextInput becomes first responder in a process, UIKit
/// loads the user's keyboard preferences from CFPreferences ("Reading from
/// public effective user settings…"), wakes the keyboard extension, and
/// inflates the keyboard window — adding up to roughly a second on a real
/// device. Doing it during app launch (off the splash) means the search /
/// email fields focus instantly the first time the user taps them.
enum KeyboardWarmup {
    @MainActor
    static func warm() {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        guard let window = scene?.windows.first else { return }

        let tf = UITextField(frame: .zero)
        tf.isHidden = true
        tf.alpha = 0
        window.addSubview(tf)
        tf.becomeFirstResponder()
        // Let the keyboard finish loading before we tear it down — anything
        // shorter and UIKit can short-circuit the initialisation we wanted.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            tf.resignFirstResponder()
            tf.removeFromSuperview()
        }
    }
}
