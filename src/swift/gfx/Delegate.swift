import Cocoa
import Metal
import MetalKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowRect = NSRect(x: 100, y: 100, width: 800, height: 600)
        window = NSWindow(contentRect: windowRect, 
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], 
                          backing: .buffered, 
                          defer: false)
        window.title = "Metal Hello Triangle"
        
        let viewController = ViewController()
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
    }
}

class ViewController: NSViewController {
    var metalView: MTKView!
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the Metal view
        metalView = MTKView(frame: view.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalView.autoresizingMask = [.width, .height]
        view.addSubview(metalView)
        
        guard let device = metalView.device else {
            fatalError("Device not created. Run on a physical device.")
        }
        
        // Create renderer with the Metal view's device
        renderer = Renderer(device: device)
        metalView.delegate = renderer
    }
}

