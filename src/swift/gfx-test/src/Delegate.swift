import Cocoa
import Metal
import MetalKit
import Gfx
import Math

class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!

  func applicationDidFinishLaunching(_ notification: Notification) {
    let surface = Gfx.createSurface()!
    "Meshpipe".withCString { ptr in
        Gfx.setName(s: surface, name: ptr)
    }
    Gfx.setFullscreen(s: surface, fullscreen: true)
    Gfx.initRenderer(surface: surface)
    var volume = Gfx.createEmptyVolume(size_x: 16, size_y: 16, size_z: 16)
    var outBlock = 0;
    var position = v3(x:0,y:0,z:0);
    withUnsafeMutablePointer(to: &outBlock) { outPtr in
        withUnsafeMutablePointer(to: &position) { posPtr in
            Gfx.getVoxel(vol: volume, positions: posPtr, out_blocks: outPtr, count: 1)
        }
    }
    print("outBlock: \(outBlock)")
  }
}
