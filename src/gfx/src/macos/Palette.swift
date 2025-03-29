import Math

public struct Palette {
  public var palette: [Int] = []
  public var count: Int
  public var data: [Int] = []

  init(single: Int, count: Int) {
    self.palette = [single]
    self.count = count
    self.data = []
  }

  init(uncompressed: [Int]) {
    count = uncompressed.count;
    var seen = Set<Int>()
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

      if outerOffset >= Int(palette.count) {
        break
      }

      let mask = Int(1) << Int(bits) - Int(1)
      let innerValue = value & mask

      let remainingBitsInCurrentInt = 64 - innerOffset

      if bits <= remainingBitsInCurrentInt {
        data[Int(outerOffset)] |= (innerValue << innerOffset)
      } else {
        let bitsInCurrent = remainingBitsInCurrentInt
        let bitsInNext = bits - bitsInCurrent

        data[Int(outerOffset)] |= (innerValue & ((1 << bitsInCurrent) - 1)) << innerOffset

        if outerOffset + 1 < Int(palette.count) {
          data[Int(outerOffset) + 1] |= (innerValue >> bitsInCurrent)
        } else {
            fatalError("out of bounds of palette")
        }
      }

      bitCursor += bits
    }
  }

  public func decompress() -> [Int] {
    if palette.isEmpty {
        return [] // Handle empty palette case to avoid log2 of 0
    }
    var bits = Int(ceil(x: log2(Float(palette.count))))
    var decompressedData: [Int] = []
    var bitCursor = 0

    let totalBitsInCompressedData = data.count * 64
    let maxValuesPossible = totalBitsInCompressedData / Int(bits)

    for _ in 0..<maxValuesPossible {
        let outerOffset = bitCursor / 64
        let innerOffset = bitCursor % 64

        var paletteIndex: Int = 0

        let remainingBitsInCurrentInt = 64 - innerOffset

        if bits <= remainingBitsInCurrentInt {
            if outerOffset < data.count {
                paletteIndex = (data[outerOffset] >> innerOffset) & ((1 << Int(bits)) - 1)
            } else {
                break // Out of data bounds, stop decompression
            }
        } else {
            let bitsInCurrent = remainingBitsInCurrentInt
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
    public subscript(index: Int) -> Int {
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
        var paletteIndex: Int = 0
        let remainingBitsInCurrentInt = 64 - innerOffset
        let mask = (Int(1) << bits) - 1 // Mask to extract exactly 'bits' bits

        if bits <= remainingBitsInCurrentInt {
            // Value fits entirely in the current Int
            paletteIndex = (data[outerOffset] >> innerOffset) & mask
        } else {
            // Value spans across two Ints
            let bitsInCurrent = remainingBitsInCurrentInt
            let bitsInNext = bits - bitsInCurrent

            // Get lower bits from the current Int
            let part1 = data[outerOffset] >> innerOffset // No mask needed here yet

            // Get upper bits from the next Int (already checked bounds with requiredDataIndex)
            let maskNext = (Int(1) << bitsInNext) - 1
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

public struct PaletteId: Hashable {
  public var id: Int
  public init(id: Int) {
    self.id = id
  }
}

public struct PaletteManager {
  public var gpuAllocator: GpuAllocator;
  public var nextPaletteId: PaletteId = PaletteId(id: 0);
  public var allocations: [PaletteId : HeapAllocation] = [:]

  public init(gpuAllocator: GpuAllocator) {
    self.gpuAllocator = gpuAllocator

  }

  public mutating func allocate(palette: Palette) -> PaletteId {
    let u64Size = Int(8);
    let allocation = self.gpuAllocator.allocate(size: u64Size * Int(palette.data.count + palette.palette.count), type: .palette)!

    let paletteId = nextPaletteId
    nextPaletteId.id += 1

    self.allocations[paletteId] = allocation

    return paletteId;
  }
}