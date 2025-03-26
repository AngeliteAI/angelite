import Foundation
import Math

public struct VoxelGrid {
    private var data: Palette
    private var size: IVec3
    private var position: Vec3
    private var rotation: Quat

    private var dirty: Bool

    init(data: Palette) {
        self.data = data
        self.dirty = true
    }

    func setPos(pos: Vec3) {
        self.position = pos
        self.dirty = true
    }

    func setRot(rot: Quat) {
        self.rotation = rot
        self.dirty = true
    }

    func isDirty() -> Bool {
        return self.dirty
    }

    func clearDirty() {
        self.dirty = false
    }

    func getSize() -> IVec3 {
        return self.size
    }

    func getData() -> Palette {
        return self.data
    }
}
