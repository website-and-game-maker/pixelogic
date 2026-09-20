// The iPhone/iPad widget bundle.
//
// Deployment target is iOS 18, one major above the app itself. That is
// deliberate: `AppIntentConfiguration`, `containerBackground` and
// `supplementalActivityFamily` (the wrist mirror) all want a modern floor, and
// paying for them with availability branches in every view is a worse trade
// than "older phones keep the app, without widgets".

import WidgetKit
import SwiftUI

@main
struct ClueweaveWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContinueWidget()
        TierWidget()
        ProgressWidget()
        ClueweaveLiveActivity()
    }
}
