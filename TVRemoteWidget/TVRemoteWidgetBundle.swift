import WidgetKit
import SwiftUI

@main
struct TVRemoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        TVRemoteWidget()
        TVRemoteWidgetLegacy()
    }
}
