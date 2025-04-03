import Foundation

@frozen public struct Brush {
  let id: UInt64
  public init() {
    self.id = 0
  }
}

@frozen public struct Condition {
  let id: UInt64
  public init() {
    self.id = 0
  }
}

// MARK: - C-Callable Functions
@_cdecl("brush")
public func brush(name: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
  print("brush (Swift stub)")
  return nil
}

@_cdecl("when")
public func when(
  brush: UnsafeMutableRawPointer?, condition: UnsafeMutableRawPointer?, material: UInt16
) -> UnsafeMutableRawPointer? {
  print("when (Swift stub)")
  return nil
}

@_cdecl("layer")
public func layer(brushes: UnsafeMutableRawPointer?, count: Int32) -> UnsafeMutableRawPointer? {
  print("layer (Swift stub)")
  return nil
}

@_cdecl("depth")
public func depth(min: Float, max: Float) -> UnsafeMutableRawPointer? {
  print("depth (Swift stub)")
  return nil
}

@_cdecl("height")
public func height(min: Float, max: Float) -> UnsafeMutableRawPointer? {
  print("height (Swift stub)")
  return nil
}

@_cdecl("slope")
public func slope(min: Float, max: Float) -> UnsafeMutableRawPointer? {
  print("slope (Swift stub)")
  return nil
}

@_cdecl("noise")
public func noise(seed: UInt64, threshold: Float, scale: Float) -> UnsafeMutableRawPointer? {
  print("noise (Swift stub)")
  return nil
}

@_cdecl("curvature")
public func curvature(min: Float, max: Float) -> UnsafeMutableRawPointer? {
  print("curvature (Swift stub)")
  return nil
}

@_cdecl("distance")
public func distance(point_x: Float, point_y: Float, point_z: Float, min: Float, max: Float)
  -> UnsafeMutableRawPointer?
{
  print("distance (Swift stub)")
  return nil
}

@_cdecl("logical_and")
public func logical_and(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?)
  -> UnsafeMutableRawPointer?
{
  print("logical_and (Swift stub)")
  return nil
}

@_cdecl("logical_or")
public func logical_or(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?)
  -> UnsafeMutableRawPointer?
{
  print("logical_or (Swift stub)")
  return nil
}

@_cdecl("logical_not")
public func logical_not(condition: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
  print("logical_not (Swift stub)")
  return nil
}

@_cdecl("scatter")
public func scatter(
  base_brush: UnsafeMutableRawPointer?, feature_brush: UnsafeMutableRawPointer?, density: Float,
  seed: UInt64
) -> UnsafeMutableRawPointer? {
  print("scatter (Swift stub)")
  return nil
}

@_cdecl("paint")
public func paint(
  sdf: UnsafeMutableRawPointer?, size_x: UInt32, size_y: UInt32, size_z: UInt32,
  brush: UnsafeMutableRawPointer?
) -> UnsafeMutableRawPointer? {
  print("paint (Swift stub)")
  return nil
}
