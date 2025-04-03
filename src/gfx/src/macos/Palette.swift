import Math

public struct Palette {
  let bits: UInt32 = 32
  public var palette: [UInt32] = []
  public var count: Int
  public var data: [UInt32] = []

  init(single: UInt32, count: Int) {
    self.palette = [single]
    self.count = count
    self.data = []
  }

  init(uncompressed: [UInt32]) {
    count = uncompressed.count
    var seen = Set<UInt32>()
    for value in uncompressed {
      if !seen.contains(value) {
        seen.insert(value)
        palette.append(value)
      }
    }

    var bits = Int(ceil(x: log2(Float(palette.count))))
    var bitCursor = 0

    if bits == 0 {
      return  // No need to compress if there is only one value
    }

    var size = (uncompressed.count * bits) / Int(self.bits) + 1
    data = Array(repeating: 0, count: size)

    for value in uncompressed {
      let outerOffset = bitCursor / Int(self.bits)
      let innerOffset = bitCursor % Int(self.bits)

      if outerOffset >= size {
        break
      }

      // Find the index of value in palette
      let paletteIndex = UInt32(palette.firstIndex(of: value) ?? 0)
      // Create a proper mask with correct operator precedence
      let mask = (UInt32(1) << UInt32(bits)) - UInt32(1)

      let remainingBitsInCurrentUInt32 = Int(self.bits) - innerOffset

      if bits <= remainingBitsInCurrentUInt32 {
        data[outerOffset] |= (paletteIndex << innerOffset) & (mask << innerOffset)
      } else {
        let bitsInCurrent = remainingBitsInCurrentUInt32
        let bitsInNext = bits - bitsInCurrent

        // First part in current UInt32
        data[outerOffset] |= (paletteIndex << innerOffset)

        // Second part in next UInt32
        if outerOffset + 1 < size {
          data[outerOffset + 1] |= (paletteIndex >> bitsInCurrent) & ((1 << bitsInNext) - 1)
        } else {
          fatalError("out of bounds of data array")
        }
      }

      bitCursor += bits
    }
  }

  public func decompress() -> [UInt32] {
    if palette.isEmpty {
      return []  // Handle empty palette case to avoid log2 of 0
    }
    var bits = UInt32(ceil(x: log2(Float(palette.count))))
    var decompressedData: [UInt32] = []
    var bitCursor: UInt32 = 0

    let totalBitsInCompressedData = UInt32(data.count) * self.bits
    let maxValuesPossible = totalBitsInCompressedData / bits

    for _ in 0..<maxValuesPossible {
      let outerOffset = Int(bitCursor / self.bits)
      let innerOffset = Int(bitCursor % self.bits)

      var paletteIndex: UInt32 = 0

      let remainingBits = Int(self.bits) - innerOffset

      if bits <= remainingBits {
        if outerOffset < data.count {
          paletteIndex = (data[outerOffset] >> innerOffset) & ((1 << UInt32(bits)) - 1)
        } else {
          break  // Out of data bounds, stop decompression
        }
      } else {
        let bitsInCurrent = UInt32(remainingBits)
        let bitsInNext = bits - bitsInCurrent

        if outerOffset < data.count {
          paletteIndex |= (data[outerOffset] >> innerOffset) & ((1 << UInt32(bitsInCurrent)) - 1)
        } else {
          break  // Out of data bounds, stop decompression
        }
        if outerOffset + 1 < data.count {
          paletteIndex |= (data[outerOffset + 1] << UInt32(bitsInCurrent)) & ((1 << Int(bits)) - 1)
        } else {
          fatalError(
            "Warning: Palette index out of bounds: \(paletteIndex), palette count: \(palette.count)"
          )
        }
      }

      if UInt32(paletteIndex) < palette.count {
        decompressedData.append(palette[Int(paletteIndex)])
      } else {
        fatalError(
          "Warning: Palette index out of bounds: \(paletteIndex), palette count: \(palette.count)")
      }
      bitCursor += (bits)
    }
    return decompressedData
  }
  public subscript(index: UInt32) -> UInt32 {
    // 1. Input Validation
    precondition(index >= 0 && index < count, "Index \(index) out of bounds (count: \(count))")

    // 2. Handle Simple Cases (No Compressed Data)
    guard !palette.isEmpty else {
      // If count > 0 but palette is empty, this is an invalid state.
      fatalError("Palette is empty, cannot access index \(index).")
    }
    if data.isEmpty {
      // This means all values are the same (palette[0])
      return palette[0]
    }

    // 3. Calculate Bits Per Index (must match compression)
    // Use Swift.max(1, ...) to ensure bits is at least 1
    let bits = UInt32(Swift.max(1, UInt32(ceil(x: log2(Float(palette.count))))))
    guard bits > 0 else {
      // Should be caught by data.isEmpty check
      fatalError("UInt32ernal Error: bits calculated as 0 or less despite having data.")
    }

    // 4. Calculate Bit Position for the requested index
    let bitCursor = UInt32(index * bits)
    let outerOffset = Int(bitCursor / self.bits)
    let innerOffset = Int(bitCursor % self.bits)

    // 5. Safety Check: Ensure we don't read past the allocated data
    // Note: We might need outerOffset OR outerOffset+1
    let requiredDataIndex = (bitCursor + bits - 1) / self.bits  // The last data index needed
    precondition(
      requiredDataIndex < data.count,
      "Calculated data index \(requiredDataIndex) is out of bounds for data size \(data.count) when accessing index \(index)"
    )

    // 6. Extract the Palette Index from 'data' (Logic adapted from decompress)
    var paletteIndex: UInt32 = 0
    let remainingBits = UInt32(Int(self.bits) - innerOffset)
    let mask = (UInt32(1) << bits) - 1  // Mask to extract exactly 'bits' bits

    if bits <= remainingBits {
      // Value fits entirely in the current UInt32
      paletteIndex = (data[outerOffset] >> innerOffset) & mask
    } else {
      // Value spans across two UInt32s
      let bitsInCurrent = remainingBits
      let bitsInNext = bits - bitsInCurrent

      // Get lower bits from the current UInt32
      let part1 = data[outerOffset] >> innerOffset  // No mask needed here yet

      // Get upper bits from the next UInt32 (already checked bounds with requiredDataIndex)
      let maskNext = (UInt32(1) << bitsInNext) - 1
      let part2 = data[outerOffset + 1] & maskNext

      // Combine the parts
      paletteIndex = part1 | (part2 << bitsInCurrent)
      // Apply final mask for robustness (optional if logic is perfect, but safer)
      paletteIndex &= mask
    }

    // 7. Look Up Value in Palette
    let paletteArrayIndex = Int(paletteIndex)
    precondition(
      paletteArrayIndex >= 0 && paletteArrayIndex < palette.count,
      "Extracted palette index \(paletteIndex) is out of bounds for palette size \(palette.count) at index \(index)."
    )

    return palette[paletteArrayIndex]
  }
}

public struct PaletteId: Hashable {
  public var id: UInt32
  public init(id: UInt32) {
    self.id = id
  }
}
