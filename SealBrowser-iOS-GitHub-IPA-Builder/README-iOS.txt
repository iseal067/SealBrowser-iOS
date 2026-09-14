SEAL BROWSER FOR IPHONE - SOURCE PROJECT

This folder is a real native iOS SwiftUI + WKWebView browser project.

Why there is no ready-made IPA in this ZIP:
Apple requires iOS apps to be compiled and code-signed using Xcode on macOS with an Apple signing identity. This environment cannot perform Apple's signing step, so a downloadable IPA produced here would not be a real installable build.

Build it on a Mac:
1. Open SealBrowser.xcodeproj in Xcode.
2. Click the SealBrowser project, then the SealBrowser target.
3. Open Signing & Capabilities and choose your Apple Team.
4. Change the Bundle Identifier if Xcode says com.sealbrowser.app is already taken.
5. Connect your iPhone and press Run to install it directly.

Export an IPA:
1. In Xcode choose a physical iOS device or Any iOS Device (arm64).
2. Product > Archive.
3. When Organizer opens, choose Distribute App.
4. Pick the distribution method your Apple account supports and export the IPA.

The iPhone build uses Apple's WKWebView, which is the normal web-view engine for an iOS browser shell.
