pub const Value = union(enum) {
    //equivalent to nil or void
    unit,
    //integer
    scalar: u64,
    //floating point
    real: f32,
    //byte
    byte: u8,
    //bool
    boolean: bool,
    //your typical string
    string: []const u8,
    //pointer (a scalar that represents a place in memory)
    pointer: *Value,
    //function (a pointer that can be translated into a function and called)
    function: *Value,
    //array (a number followed by a list of values)
    array: *Value,
    //mathematical vector (figuratively represented as an array of numbers)
    vector: *Value,
    //map (figuratively represented as an array of tuples)
    map: *Value,
    //tuple (figuratively represented as an array)
    tuple: *?Value,
};
