import Foundation
import Math

public struct VoxelGrid {
  private var data: Palette
  private var origin: IVec3
  private var size: UVec3
  private var position: Vec3
  private var rotation: Quat

  private var dirty: Bool

  init(data: Palette, size: UVec3) {
    self.data = data
    self.size = size
    self.origin = iv3Splat(s: 0)
    self.position = v3Splat(s: 0)
    self.rotation = qId()
    self.dirty = true
  }

  mutating func setPos(pos: Vec3) {
    self.position = pos
    self.markDirty()
  }

  mutating func setRot(rot: Quat) {
    self.rotation = rot
    self.markDirty()
  }

  mutating func markDirty() {
    self.dirty = true
  }

  func isDirty() -> Bool {
    return self.dirty
  }

  mutating func clearDirty() {
    self.dirty = false
  }

  func getSize() -> UVec3 {
    return self.size
  }

  func getData() -> Palette {
    return self.data
  }
}
