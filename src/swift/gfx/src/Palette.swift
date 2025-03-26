import Math

public struct Palette {
  public var palette: [UInt64] = []
  public var count: Int
  public var data: [UInt64] = []

  init(single: UInt64, count: Int) {
    self.palette = [single]
    self.count = count
    self.data = []
  }

  init(uncompressed: [UInt64]) {
    count = uncompressed.count;
    var seen = Set<UInt64>()
    for value in uncompressed {
      if !seen.contains(value) {
        seen.insert(value)
        palette.append(value)
      }
    }

    var bits = Int(ceil(x: log2(Float(palette.count))))
    var bitCursor = 0

    if (bits == 1) {
        return // No need to compress if there is only one value
    }

    var size = (uncompressed.count * bits) / 64 + 1;
    data = Array(repeating: 0, count: size)

    for value in data {
      let outerOffset = bitCursor / 64
      let innerOffset = bitCursor % 64

      if outerOffset >= UInt64(palette.count) {
        break
      }

      let mask = UInt64(1) << UInt64(bits) - UInt64(1)
      let innerValue = value & mask

      let remainingBitsInCurrentUInt64 = 64 - innerOffset

      if bits <= remainingBitsInCurrentUInt64 {
        data[Int(outerOffset)] |= (innerValue << innerOffset)
      } else {
        let bitsInCurrent = remainingBitsInCurrentUInt64
        let bitsInNext = bits - bitsInCurrent

        data[Int(outerOffset)] |= (innerValue & ((1 << bitsInCurrent) - 1)) << innerOffset

        if outerOffset + 1 < UInt64(palette.count) {
          data[Int(outerOffset) + 1] |= (innerValue >> bitsInCurrent)
        } else {
            fatalError("out of bounds of palette")
        }
      }

      bitCursor += bits
    }
  }

  public func decompress() -> [UInt64] {
    if palette.isEmpty {
        return [] // Handle empty palette case to avoid log2 of 0
    }
    var bits = Int(ceil(x: log2(Float(palette.count))))
    var decompressedData: [UInt64] = []
    var bitCursor = 0

    let totalBitsInCompressedData = data.count * 64
    let maxValuesPossible = totalBitsInCompressedData / Int(bits)

    for _ in 0..<maxValuesPossible {
        let outerOffset = bitCursor / 64
        let innerOffset = bitCursor % 64

        var paletteIndex: UInt64 = 0

        let remainingBitsInCurrentUInt64 = 64 - innerOffset

        if bits <= remainingBitsInCurrentUInt64 {
            if outerOffset < data.count {
                paletteIndex = (data[outerOffset] >> innerOffset) & ((1 << Int(bits)) - 1)
            } else {
                break // Out of data bounds, stop decompression
            }
        } else {
            let bitsInCurrent = remainingBitsInCurrentUInt64
            let bitsInNext = bits - bitsInCurrent

            if outerOffset < data.count {
                paletteIndex |= (data[outerOffset] >> innerOffset) & ((1 << Int(bitsInCurrent)) - 1)
            } else {
                break // Out of data bounds, stop decompression
            }
            if outerOffset + 1 < data.count {
                paletteIndex |= (data[outerOffset + 1] << Int(bitsInCurrent)) & ((1 << Int(bits)) - 1)
            } else {
                fatalError("Warning: Palette index out of bounds: \(paletteIndex), palette count: \(palette.count)")
            }
        }

        if Int(paletteIndex) < palette.count {
            decompressedData.append(palette[Int(paletteIndex)])
        } else {
            fatalError("Warning: Palette index out of bounds: \(paletteIndex), palette count: \(palette.count)")
        }
        bitCursor += Int(bits)
    }
    return decompressedData
  }
    public subscript(index: Int) -> UInt64 {
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
        let bits = Swift.max(1, Int(ceil(x: log2(Float(palette.count)))))
        guard bits > 0 else {
            // Should be caught by data.isEmpty check
            fatalError("Internal Error: bits calculated as 0 or less despite having data.")
        }


        // 4. Calculate Bit Position for the requested index
        let bitCursor: Int = index * bits
        let outerOffset = bitCursor / 64
        let innerOffset = bitCursor % 64

        // 5. Safety Check: Ensure we don't read past the allocated data
        // Note: We might need outerOffset OR outerOffset+1
        let requiredDataIndex = (bitCursor + bits - 1) / 64 // The last data index needed
        precondition(requiredDataIndex < data.count, "Calculated data index \(requiredDataIndex) is out of bounds for data size \(data.count) when accessing index \(index)")


        // 6. Extract the Palette Index from 'data' (Logic adapted from decompress)
        var paletteIndex: UInt64 = 0
        let remainingBitsInCurrentUInt64 = 64 - innerOffset
        let mask = (UInt64(1) << bits) - 1 // Mask to extract exactly 'bits' bits

        if bits <= remainingBitsInCurrentUInt64 {
            // Value fits entirely in the current UInt64
            paletteIndex = (data[outerOffset] >> innerOffset) & mask
        } else {
            // Value spans across two UInt64s
            let bitsInCurrent = remainingBitsInCurrentUInt64
            let bitsInNext = bits - bitsInCurrent

            // Get lower bits from the current UInt64
            let part1 = data[outerOffset] >> innerOffset // No mask needed here yet

            // Get upper bits from the next UInt64 (already checked bounds with requiredDataIndex)
            let maskNext = (UInt64(1) << bitsInNext) - 1
            let part2 = data[outerOffset + 1] & maskNext

            // Combine the parts
            paletteIndex = part1 | (part2 << bitsInCurrent)
            // Apply final mask for robustness (optional if logic is perfect, but safer)
            paletteIndex &= mask
        }

        // 7. Look Up Value in Palette
        let paletteArrayIndex = Int(paletteIndex)
        precondition(paletteArrayIndex >= 0 && paletteArrayIndex < palette.count, "Extracted palette index \(paletteIndex) is out of bounds for palette size \(palette.count) at index \(index).")

        return palette[paletteArrayIndex]
    }
}
