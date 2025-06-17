import Cocoa
import Metal
import MetalKit
import Gfx
import Math

class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var displayLink: CVDisplayLink?
  var surface: UnsafeMutableRawPointer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    surface = Gfx.createSurface()!
    "Meshpipe".withCString { ptr in
        Gfx.setName(s: surface, name: ptr)
    }
    Gfx.initRenderer(surface: surface!)
    var volume = Gfx.createEmptyVolume(size_x: 16, size_y: 16, size_z: 16)
    var outBlock = 0;
    var position = v3(x:0,y:0,z:0);
    withUnsafeMutablePointer(to: &outBlock) { outPtr in
        withUnsafeMutablePointer(to: &position) { posPtr in
            Gfx.getVoxel(vol: volume, positions: posPtr, out_blocks: outPtr, count: 1)
        }
    }
    print("outBlock: \(outBlock)")
   
    setupDisplayLink()
    print("Display link set up")
}

func setupDisplayLink() {
    // Create display link
    var displayLink: CVDisplayLink?
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
    
    // Set callback
    let callback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext -> CVReturn in
        let delegate = unsafeBitCast(displayLinkContext, to: AppDelegate.self)
        delegate.render()
        return kCVReturnSuccess
    }
    
    // Set the display link's callback
    CVDisplayLinkSetOutputCallback(displayLink!, callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    
    // Start the display link
    CVDisplayLinkStart(displayLink!)
    self.displayLink = displayLink
}

func render() {
    // This function will be called by the display link at refresh rate
    
    // Process any pending events - MUST be on main thread
    DispatchQueue.main.async {
        autoreleasepool {
            let app = NSApplication.shared
            while let event = app.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) {
                app.sendEvent(event)
            }
        }
    }
    
    // We can still call render from the display link thread
    Gfx.render()
}

func applicationWillTerminate(_ notification: Notification) {
    // Stop the display link when terminating
    if let displayLink = displayLink {
        CVDisplayLinkStop(displayLink)
    }
}
}