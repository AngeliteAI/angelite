import Foundation
import Math

// Dummy struct for vox.Volume
@frozen public struct Volume {
  let id: UInt64
  public init(id: UInt64) {
    self.id = id
  }
}

public var volumeGrids: [UInt64: UnsafeMutablePointer<VoxelGrid>] = [:]

// MARK: - C-Callable Functions
@_cdecl("createEmptyVolume")
public func createEmptyVolume(size_x: UInt32, size_y: UInt32, size_z: UInt32)
  -> UnsafeMutableRawPointer?
{
  let volumeId = UInt64(arc4random())  // Generate a random ID.  Don't do this in real code.
  let volume = Volume(id: volumeId)

  let volumeRawPointer = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
  let volumePointer = volumeRawPointer.bindMemory(to: Volume.self, capacity: 1)
  volumePointer.pointee = volume

  // Initialize the volume grid with default values
  let voxelGrid = VoxelGrid(
    data: Palette(single: 0, count: Int(size_x * size_y * size_z)),
    size: UVec3(x: size_x, y: size_y, z: size_z))
  let voxelGridPointer = UnsafeMutablePointer<VoxelGrid>.allocate(capacity: 1)
  voxelGridPointer.pointee = voxelGrid
  volumeGrids[volumePointer.pointee.id] = voxelGridPointer

  print(
    "createEmptyVolume (Swift): size = (\(size_x), \(size_y), \(size_z)), id = \(volumePointer.pointee.id)"
  )
  return volumeRawPointer
}

@_cdecl("createVolumeFromSDF")
public func createVolumeFromSDF(
  sdf: UnsafeMutableRawPointer?, brush: UnsafeRawPointer?, position: UnsafeRawPointer,
  size: UnsafeRawPointer
) -> UnsafeMutableRawPointer? {
  print("createVolumeFromSDF (Swift stub)")
  return nil
}

@_cdecl("cloneVolume")
public func cloneVolume(vol: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
  print("cloneVolume (Swift stub)")
  return nil
}

@_cdecl("releaseVolume")
public func releaseVolume(vol: UnsafeMutableRawPointer?) {
  print("releaseVolume (Swift stub)")
}

@_cdecl("unionVolume")
public func unionVolume(
  vol: UnsafeMutableRawPointer?, transform: UnsafeRawPointer?, brush: UnsafeRawPointer?,
  position: UnsafeRawPointer
) -> UnsafeMutableRawPointer? {
  print("unionVolume (Swift stub)")
  return nil
}

@_cdecl("subtractVolume")
public func subtractVolume(
  vol: UnsafeMutableRawPointer?, transform: UnsafeRawPointer?, position: UnsafeRawPointer
) -> UnsafeMutableRawPointer? {
  print("subtractVolume (Swift stub)")
  return nil
}

@_cdecl("replaceVolume")
public func replaceVolume(
  vol: UnsafeMutableRawPointer?, transform: UnsafeRawPointer?, brush: UnsafeRawPointer?,
  position: UnsafeRawPointer
) -> UnsafeMutableRawPointer? {
  print("replaceVolume (Swift stub)")
  return nil
}

@_cdecl("paintVolumeRegion")
public func paintVolumeRegion(
  vol: UnsafeMutableRawPointer?, transform: UnsafeRawPointer?, brush: UnsafeRawPointer?,
  position: UnsafeRawPointer
) -> UnsafeMutableRawPointer? {
  print("paintVolumeRegion (Swift stub)")
  return nil
}

@_cdecl("mergeVolumes")
public func mergeVolumes(volumes: UnsafeMutableRawPointer?, count: Int32)
  -> UnsafeMutableRawPointer?
{
  print("mergeVolumes (Swift stub)")
  return nil
}

@_cdecl("extractRegion")
public func extractRegion(
  vol: UnsafeMutableRawPointer?, min_x: Int32, min_y: Int32, min_z: Int32, max_x: Int32,
  max_y: Int32, max_z: Int32
) -> UnsafeMutableRawPointer? {
  print("extractRegion (Swift stub)")
  return nil
}

@_cdecl("registerStructure")
public func registerStructure(vol: UnsafeMutableRawPointer?, name: UnsafeRawPointer?) -> UInt32 {
  print("registerStructure (Swift stub)")
  return 0
}

@_cdecl("getStructure")
public func getStructure(id: UInt32) -> UnsafeMutableRawPointer? {
  print("getStructure (Swift stub)")
  return nil
}

@_cdecl("placeStructure")
public func placeStructure(
  world: UnsafeMutableRawPointer?, structure: UnsafeMutableRawPointer?, position: UnsafeRawPointer,
  rotation: UInt8
) -> UnsafeMutableRawPointer? {
  print("placeStructure (Swift stub)")
  return nil
}

@_cdecl("saveVolume")
public func saveVolume(vol: UnsafeMutableRawPointer?, path: UnsafeRawPointer?) -> Bool {
  print("saveVolume (Swift stub)")
  return false
}

@_cdecl("loadVolume")
public func loadVolume(path: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
  print("loadVolume (Swift stub)")
  return nil
}

@_cdecl("getVoxel")
public func getVoxel(
  vol: UnsafeMutableRawPointer?,
  positions: UnsafeRawPointer?,  // Changed to UnsafeRawPointer?
  out_blocks: UnsafeMutableRawPointer?,  // Changed to UnsafeMutableRawPointer?
  count: Int
) {
  // --- Initial Guard Checks ---
  guard let vol = vol else {
    print("getVoxel (Swift Error): Volume pointer is nil.")
    if let out_blocks = out_blocks, count > 0 {
      // Bind to UInt16 before initializing
      out_blocks.bindMemory(to: UInt16.self, capacity: count)
        .initialize(repeating: 0, count: count)
    }
    return
  }
  guard let positionsRaw = positions else {  // Use a different name temporarily
    print("getVoxel (Swift Error): Positions pointer is nil.")
    if let out_blocks = out_blocks, count > 0 {
      // Bind to UInt16 before initializing
      out_blocks.bindMemory(to: UInt16.self, capacity: count)
        .initialize(repeating: 0, count: count)
    }
    return
  }
  guard let out_blocksRaw = out_blocks else {  // Use a different name temporarily
    print("getVoxel (Swift Error): Output blocks pointer is nil.")
    // No need to initialize if the pointer itself is nil
    return
  }

  guard count > 0 else {
    // If count is 0 or less, there's nothing to do.
    // Technically not an error, but we can print for debugging if needed.
    // print("getVoxel (Swift Info): Count is \(count), doing nothing.")
    return
  }

  // --- Bind Raw Pointers to Typed Pointers ---
  // Assuming the caller guarantees these pointers point to valid memory
  // of the correct type and count.
  // Use bindMemory for safety if the memory isn't guaranteed to be pre-bound.
  // Use assumingMemoryBound if you know it's already bound (slightly faster).
  // We'll use bindMemory here.
  let typedPositions = positionsRaw.bindMemory(to: Vec3.self, capacity: count)
  let typedOutBlocks = out_blocksRaw.bindMemory(to: UInt64.self, capacity: count)

  // --- Core Logic (using typed pointers) ---
  let volume = vol.bindMemory(to: Volume.self, capacity: 1)
  let volumeId = volume.pointee.id

  guard let voxelGridPtr = volumeGrids[volumeId] else {
    print("getVoxel (Swift Error): VoxelGrid not found for volume id \(volumeId).")
    // Zero out the output buffer as the grid doesn't exist
    // typedOutBlocks is already bound from the guard check above
    typedOutBlocks.initialize(repeating: 0, count: count)
    return
  }

  let voxelGrid = voxelGridPtr.pointee  // Get the actual VoxelGrid struct
  let size = voxelGrid.getSize()  // IVec3(Int32)
  let sx = Int(size.x)
  let sy = Int(size.y)
  let sz = Int(size.z)  // Use Int for index calculations
  let sxsy = sx * sy  // Precompute for index calculation

  // Ensure grid dimensions are valid before proceeding
  let voxelData = voxelGrid.getData()
  guard sx > 0, sy > 0, sz > 0, voxelData != nil else {
    print(
      "getVoxel (Swift Error): Invalid grid dimensions or data pointer for volume id \(volumeId). (\(sx)x\(sy)x\(sz))"
    )
    typedOutBlocks.initialize(repeating: 0, count: count)
    return
  }

  return
}

@_cdecl("setVoxel")
public func setVoxel(
  vol: UnsafeMutableRawPointer?, positions: UnsafeRawPointer?, blocks: UnsafeRawPointer?, count: Int
) {
  print("setVoxel (Swift stub)")
}

@_cdecl("getVolumeSize")
public func getVolumeSize(
  vol: UnsafeMutableRawPointer?, size_ptr: UnsafeMutablePointer<SIMD3<UInt32>>?
) {
  print("getVolumeSize (Swift stub)")
}

@_cdecl("getVolumePosition")
public func getVolumePosition(
  vol: UnsafeMutableRawPointer?, position_ptr: UnsafeMutablePointer<SIMD3<Int32>>?
) {
  print("getVolumePosition (Swift stub)")
}

@_cdecl("moveVolume")
public func moveVolume(vol: UnsafeMutableRawPointer?, x: Int32, y: Int32, z: Int32)
  -> UnsafeMutableRawPointer?
{
  print("moveVolume (Swift stub)")
  return nil
}

@_cdecl("rotateVolume")
public func rotateVolume(vol: UnsafeMutableRawPointer?, rotation: UInt8) -> UnsafeMutableRawPointer?
{
  print("rotateVolume (Swift stub)")
  return nil
}

@_cdecl("mirrorVolume")
public func mirrorVolume(vol: UnsafeMutableRawPointer?, axis: UInt8) -> UnsafeMutableRawPointer? {
  print("mirrorVolume (Swift stub)")
  return nil
}
