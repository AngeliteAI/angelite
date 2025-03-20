import Metal
import MetalKit
import simd

struct BufferTrackingInfo {
  let callId: Int
  let startTime: CFAbsoluteTime
  var endTime: CFAbsoluteTime?
  var status: String
  var additionalData: [String: Any]

  init(callId: Int) {
    self.callId = callId
    self.startTime = CFAbsoluteTimeGetCurrent()
    self.status = "Started"
    self.additionalData = [:]
  }

  mutating func complete() {
    self.endTime = CFAbsoluteTimeGetCurrent()
    self.status = "Completed"
  }

  var processingTime: TimeInterval? {
    if let endTime = endTime {
      return endTime - startTime
    }
    return nil
  }
}
