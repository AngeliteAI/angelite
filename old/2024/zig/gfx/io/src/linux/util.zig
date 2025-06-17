fn nextPowerOfTwo(comptime T: type, val: T) T {
    const one: T = 1;
    const shift = @bitSizeOf(T) - @clz(val);
    return one << @intCast(shift);
}
