pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub inline fn asArray(self: *const Vec2) *const [2]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [2]f32) Vec2 {
        return Vec2{ .x = arr[0], .y = arr[1] };
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn asArray(self: *const Vec3) *const [3]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [3]f32) Vec3 {
        return Vec3{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }
};

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn asArray(self: *const Vec4) *const [4]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [4]f32) Vec4 {
        return Vec4{ .x = arr[0], .y = arr[1], .z = arr[2], .w = arr[3] };
    }
};

pub const IVec2 = extern struct {
    x: i32,
    y: i32,

    pub inline fn asArray(self: *const IVec2) *const [2]i32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [2]i32) IVec2 {
        return IVec2{ .x = arr[0], .y = arr[1] };
    }
};

pub const IVec3 = extern struct {
    x: i32,
    y: i32,
    z: i32,

    pub inline fn asArray(self: *const IVec3) *const [3]i32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [3]i32) IVec3 {
        return IVec3{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }
};

pub const IVec4 = extern struct {
    x: i32,
    y: i32,
    z: i32,
    w: i32,

    pub inline fn asArray(self: *const IVec4) *const [4]i32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [4]i32) IVec4 {
        return IVec4{ .x = arr[0], .y = arr[1], .z = arr[2], .w = arr[3] };
    }
};

pub const UVec2 = extern struct {
    x: u32,
    y: u32,

    pub inline fn asArray(self: *const UVec2) *const [2]u32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [2]u32) UVec2 {
        return UVec2{ .x = arr[0], .y = arr[1] };
    }
};

pub const UVec3 = extern struct {
    x: u32,
    y: u32,
    z: u32,

    pub inline fn asArray(self: *const UVec3) *const [3]u32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [3]u32) UVec3 {
        return UVec3{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }
};

pub const UVec4 = extern struct {
    x: u32,
    y: u32,
    z: u32,
    w: u32,

    pub inline fn asArray(self: *const UVec4) *const [4]u32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [4]u32) UVec4 {
        return UVec4{ .x = arr[0], .y = arr[1], .z = arr[2], .w = arr[3] };
    }
};

// Constructor functions
pub extern fn v2(x: f32, y: f32) Vec2;
pub extern fn v3(x: f32, y: f32, z: f32) Vec3;
pub extern fn v4(x: f32, y: f32, z: f32, w: f32) Vec4;
pub extern fn iv2(x: i32, y: i32) IVec2;
pub extern fn iv3(x: i32, y: i32, z: i32) IVec3;
pub extern fn iv4(x: i32, y: i32, z: i32, w: i32) IVec4;
pub extern fn uv2(x: u32, y: u32) UVec2;
pub extern fn uv3(x: u32, y: u32, z: u32) UVec3;
pub extern fn uv4(x: u32, y: u32, z: u32, w: u32) UVec4;

// Common constants
pub extern fn v2Zero() Vec2;
pub extern fn v3Zero() Vec3;
pub extern fn v4Zero() Vec4;
pub extern fn v2One() Vec2;
pub extern fn v3One() Vec3;
pub extern fn v4One() Vec4;
pub extern fn iv2Zero() IVec2;
pub extern fn iv3Zero() IVec3;
pub extern fn iv4Zero() IVec4;
pub extern fn uv2Zero() UVec2;
pub extern fn uv3Zero() UVec3;
pub extern fn uv4Zero() UVec4;
pub extern fn iv2One() IVec2;
pub extern fn iv3One() IVec3;
pub extern fn iv4One() IVec4;
pub extern fn uv2One() UVec2;
pub extern fn uv3One() UVec3;
pub extern fn uv4One() UVec4;

// Unit vectors
pub extern fn v2X() Vec2;
pub extern fn v2Y() Vec2;
pub extern fn v3X() Vec3;
pub extern fn v3Y() Vec3;
pub extern fn v3Z() Vec3;
pub extern fn v4X() Vec4;
pub extern fn v4Y() Vec4;
pub extern fn v4Z() Vec4;
pub extern fn v4W() Vec4;
pub extern fn iv2X() IVec2;
pub extern fn iv2Y() IVec2;
pub extern fn iv3X() IVec3;
pub extern fn iv3Y() IVec3;
pub extern fn iv3Z() IVec3;
pub extern fn iv4X() IVec4;
pub extern fn iv4Y() IVec4;
pub extern fn iv4Z() IVec4;
pub extern fn iv4W() IVec4;
pub extern fn uv2X() UVec2;
pub extern fn uv2Y() UVec2;
pub extern fn uv3X() UVec3;
pub extern fn uv3Y() UVec3;
pub extern fn uv3Z() UVec3;
pub extern fn uv4X() UVec4;
pub extern fn uv4Y() UVec4;
pub extern fn uv4Z() UVec4;
pub extern fn uv4W() UVec4;

// Basic operations
// Vec
pub extern fn v2Add(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Add(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Add(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Sub(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Sub(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Sub(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Mul(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Mul(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Mul(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Div(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Div(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Div(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Scale(v: Vec2, s: f32) Vec2;
pub extern fn v3Scale(v: Vec3, s: f32) Vec3;
pub extern fn v4Scale(v: Vec4, s: f32) Vec4;
pub extern fn v2Neg(v: Vec2) Vec2;
pub extern fn v3Neg(v: Vec3) Vec3;
pub extern fn v4Neg(v: Vec4) Vec4;
// IVec
pub extern fn iv2Add(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3Add(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4Add(a: IVec4, b: IVec4) IVec4;
pub extern fn iv2Sub(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3Sub(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4Sub(a: IVec4, b: IVec4) IVec4;
pub extern fn iv2Mul(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3Mul(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4Mul(a: IVec4, b: IVec4) IVec4;
pub extern fn iv2Div(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3Div(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4Div(a: IVec4, b: IVec4) IVec4;
pub extern fn iv2Scale(v: IVec2, s: i32) IVec2;
pub extern fn iv3Scale(v: IVec3, s: i32) IVec3;
pub extern fn iv4Scale(v: IVec4, s: i32) IVec4;
pub extern fn iv2Neg(v: IVec2) IVec2;
pub extern fn iv3Neg(v: IVec3) IVec3;
pub extern fn iv4Neg(v: IVec4) IVec4;
// UVec
pub extern fn uv2Add(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3Add(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4Add(a: UVec4, b: UVec4) UVec4;
pub extern fn uv2Sub(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3Sub(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4Sub(a: UVec4, b: UVec4) UVec4;
pub extern fn uv2Mul(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3Mul(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4Mul(a: UVec4, b: UVec4) UVec4;
pub extern fn uv2Div(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3Div(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4Div(a: UVec4, b: UVec4) UVec4;
pub extern fn uv2Scale(v: UVec2, s: u32) UVec2;
pub extern fn uv3Scale(v: UVec3, s: u32) UVec3;
pub extern fn uv4Scale(v: UVec4, s: u32) UVec4;
pub extern fn uv2Neg(v: UVec2) UVec2;
pub extern fn uv3Neg(v: UVec3) UVec3;
pub extern fn uv4Neg(v: UVec4) UVec4;

// Vector operations
// Vec
pub extern fn v2Dot(a: Vec2, b: Vec2) f32;
pub extern fn v3Dot(a: Vec3, b: Vec3) f32;
pub extern fn v4Dot(a: Vec4, b: Vec4) f32;
pub extern fn v3Cross(a: Vec3, b: Vec3) Vec3;
pub extern fn v2Len(v: Vec2) f32;
pub extern fn v3Len(v: Vec3) f32;
pub extern fn v4Len(v: Vec4) f32;
pub extern fn v2Len2(v: Vec2) f32;
pub extern fn v3Len2(v: Vec3) f32;
pub extern fn v4Len2(v: Vec4) f32;
pub extern fn v2Dist(a: Vec2, b: Vec2) f32;
pub extern fn v3Dist(a: Vec3, b: Vec3) f32;
pub extern fn v4Dist(a: Vec4, b: Vec4) f32;
pub extern fn v2Dist2(a: Vec2, b: Vec2) f32;
pub extern fn v3Dist2(a: Vec3, b: Vec3) f32;
pub extern fn v4Dist2(a: Vec4, b: Vec4) f32;
pub extern fn v2Norm(v: Vec2) Vec2;
pub extern fn v3Norm(v: Vec3) Vec3;
pub extern fn v4Norm(v: Vec4) Vec4;
// IVec
pub extern fn iv2Dot(a: IVec2, b: IVec2) i32;
pub extern fn iv3Dot(a: IVec3, b: IVec3) i32;
pub extern fn iv4Dot(a: IVec4, b: IVec4) i32;
pub extern fn iv3Cross(a: IVec3, b: IVec3) IVec3;
pub extern fn iv2Len(v: IVec2) f32;
pub extern fn iv3Len(v: IVec3) f32;
pub extern fn iv4Len(v: IVec4) f32;
pub extern fn iv2Len2(v: IVec2) i32;
pub extern fn iv3Len2(v: IVec3) i32;
pub extern fn iv4Len2(v: IVec4) i32;
pub extern fn iv2Dist(a: IVec2, b: IVec2) f32;
pub extern fn iv3Dist(a: IVec3, b: IVec3) f32;
pub extern fn iv4Dist(a: IVec4, b: IVec4) f32;
pub extern fn iv2Dist2(a: IVec2, b: IVec2) i32;
pub extern fn iv3Dist2(a: IVec3, b: IVec3) i32;
pub extern fn iv4Dist2(a: IVec4, b: IVec4) i32;
pub extern fn iv2Norm(v: IVec2) Vec2;
pub extern fn iv3Norm(v: IVec3) Vec3;
pub extern fn iv4Norm(v: IVec4) Vec4;
// UVec
pub extern fn uv2Dot(a: UVec2, b: UVec2) u32;
pub extern fn uv3Dot(a: UVec3, b: UVec3) u32;
pub extern fn uv4Dot(a: UVec4, b: UVec4) u32;
pub extern fn uv2Len(v: UVec2) f32;
pub extern fn uv3Len(v: UVec3) f32;
pub extern fn uv4Len(v: UVec4) f32;
pub extern fn uv2Len2(v: UVec2) u32;
pub extern fn uv3Len2(v: UVec3) u32;
pub extern fn uv4Len2(v: UVec4) u32;
pub extern fn uv2Dist(a: UVec2, b: UVec2) f32;
pub extern fn uv3Dist(a: UVec3, b: UVec3) f32;
pub extern fn uv4Dist(a: UVec4, b: UVec4) f32;
pub extern fn uv2Dist2(a: UVec2, b: UVec2) u32;
pub extern fn uv3Dist2(a: UVec3, b: UVec3) u32;
pub extern fn uv4Dist2(a: UVec4, b: UVec4) u32;
pub extern fn uv2Norm(v: UVec2) Vec2;
pub extern fn uv3Norm(v: UVec3) Vec3;
pub extern fn uv4Norm(v: UVec4) Vec4;

// Interpolation and comparison
// Vec
pub extern fn v2Lerp(a: Vec2, b: Vec2, t: f32) Vec2;
pub extern fn v3Lerp(a: Vec3, b: Vec3, t: f32) Vec3;
pub extern fn v4Lerp(a: Vec4, b: Vec4, t: f32) Vec4;
pub extern fn v2Eq(a: Vec2, b: Vec2, eps: f32) bool;
pub extern fn v3Eq(a: Vec3, b: Vec3, eps: f32) bool;
pub extern fn v4Eq(a: Vec4, b: Vec4, eps: f32) bool;
// IVec
pub extern fn iv2Lerp(a: IVec2, b: IVec2, t: f32) Vec2;
pub extern fn iv3Lerp(a: IVec3, b: IVec3, t: f32) Vec3;
pub extern fn iv4Lerp(a: IVec4, b: IVec4, t: f32) Vec4;
pub extern fn iv2Eq(a: IVec2, b: IVec2, eps: i32) bool;
pub extern fn iv3Eq(a: IVec3, b: IVec3, eps: i32) bool;
pub extern fn iv4Eq(a: IVec4, b: IVec4, eps: i32) bool;
// UVec
pub extern fn uv2Lerp(a: UVec2, b: UVec2, t: f32) Vec2;
pub extern fn uv3Lerp(a: UVec3, b: UVec3, t: f32) Vec3;
pub extern fn uv4Lerp(a: UVec4, b: UVec4, t: f32) Vec4;
pub extern fn uv2Eq(a: UVec2, b: UVec2, eps: u32) bool;
pub extern fn uv3Eq(a: UVec3, b: UVec3, eps: u32) bool;
pub extern fn uv4Eq(a: UVec4, b: UVec4, eps: u32) bool;

// Splatting
pub extern fn v2Splat(s: f32) Vec2;
pub extern fn v3Splat(s: f32) Vec3;
pub extern fn v4Splat(s: f32) Vec4;
pub extern fn iv2Splat(s: i32) IVec2;
pub extern fn iv3Splat(s: i32) IVec3;
pub extern fn iv4Splat(s: i32) IVec4;
pub extern fn uv2Splat(s: u32) UVec2;
pub extern fn uv3Splat(s: u32) UVec3;
pub extern fn uv4Splat(s: u32) UVec4;

// Clamping
pub extern fn v2Clamp(v: Vec2, minVal: f32, maxVal: f32) Vec2;
pub extern fn v3Clamp(v: Vec3, minVal: f32, maxVal: f32) Vec3;
pub extern fn v4Clamp(v: Vec4, minVal: f32, maxVal: f32) Vec4;
pub extern fn iv2Clamp(v: IVec2, minVal: i32, maxVal: i32) IVec2;
pub extern fn iv3Clamp(v: IVec3, minVal: i32, maxVal: i32) IVec3;
pub extern fn iv4Clamp(v: IVec4, minVal: i32, maxVal: i32) IVec4;
pub extern fn uv2Clamp(v: UVec2, minVal: u32, maxVal: u32) UVec2;
pub extern fn uv3Clamp(v: UVec3, minVal: u32, maxVal: u32) UVec3;
pub extern fn uv4Clamp(v: UVec4, minVal: u32, maxVal: u32) UVec4;

// Absolute Value
pub extern fn v2Abs(v: Vec2) Vec2;
pub extern fn v3Abs(v: Vec3) Vec3;
pub extern fn v4Abs(v: Vec4) Vec4;
pub extern fn iv2Abs(v: IVec2) IVec2;
pub extern fn iv3Abs(v: IVec3) IVec3;
pub extern fn iv4Abs(v: IVec4) IVec4;

// Min/Max Components
pub extern fn v2MinComponent(v: Vec2) f32;
pub extern fn v3MinComponent(v: Vec3) f32;
pub extern fn v4MinComponent(v: Vec4) f32;
pub extern fn iv2MinComponent(v: IVec2) i32;
pub extern fn iv3MinComponent(v: IVec3) i32;
pub extern fn iv4MinComponent(v: IVec4) i32;
pub extern fn uv2MinComponent(v: UVec2) u32;
pub extern fn uv3MinComponent(v: UVec3) u32;
pub extern fn uv4MinComponent(v: UVec4) u32;
pub extern fn v2MaxComponent(v: Vec2) f32;
pub extern fn v3MaxComponent(v: Vec3) f32;
pub extern fn v4MaxComponent(v: Vec4) f32;
pub extern fn iv2MaxComponent(v: IVec2) i32;
pub extern fn iv3MaxComponent(v: IVec3) i32;
pub extern fn iv4MaxComponent(v: IVec4) i32;
pub extern fn uv2MaxComponent(v: UVec2) u32;
pub extern fn uv3MaxComponent(v: UVec3) u32;
pub extern fn uv4MaxComponent(v: UVec4) u32;

// Component-wise Min/Max
pub extern fn v2ComponentMin(a: Vec2, b: Vec2) Vec2;
pub extern fn v3ComponentMin(a: Vec3, b: Vec3) Vec3;
pub extern fn v4ComponentMin(a: Vec4, b: Vec4) Vec4;
pub extern fn iv2ComponentMin(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3ComponentMin(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4ComponentMin(a: IVec4, b: IVec4) IVec4;
pub extern fn uv2ComponentMin(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3ComponentMin(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4ComponentMin(a: UVec4, b: UVec4) UVec4;
pub extern fn v2ComponentMax(a: Vec2, b: Vec2) Vec2;
pub extern fn v3ComponentMax(a: Vec3, b: Vec3) Vec3;
pub extern fn v4ComponentMax(a: Vec4, b: Vec4) Vec4;
pub extern fn iv2ComponentMax(a: IVec2, b: IVec2) IVec2;
pub extern fn iv3ComponentMax(a: IVec3, b: IVec3) IVec3;
pub extern fn iv4ComponentMax(a: IVec4, b: IVec4) IVec4;
pub extern fn uv2ComponentMax(a: UVec2, b: UVec2) UVec2;
pub extern fn uv3ComponentMax(a: UVec3, b: UVec3) UVec3;
pub extern fn uv4ComponentMax(a: UVec4, b: UVec4) UVec4;

// Floor, Ceil, Round (for Vec only)
pub extern fn v2Floor(v: Vec2) Vec2;
pub extern fn v3Floor(v: Vec3) Vec3;
pub extern fn v4Floor(v: Vec4) Vec4;
pub extern fn v2Ceil(v: Vec2) Vec2;
pub extern fn v3Ceil(v: Vec3) Vec3;
pub extern fn v4Ceil(v: Vec4) Vec4;
pub extern fn v2Round(v: Vec2) Vec2;
pub extern fn v3Round(v: Vec3) Vec3;
pub extern fn v4Round(v: Vec4) Vec4;

// Step and Smoothstep (for Vec only)
pub extern fn v2Step(edge: Vec2, v: Vec2) Vec2;
pub extern fn v3Step(edge: Vec3, v: Vec3) Vec3;
pub extern fn v4Step(edge: Vec4, v: Vec4) Vec4;
pub extern fn v2Smoothstep(edge0: Vec2, edge1: Vec2, v: Vec2) Vec2;
pub extern fn v3Smoothstep(edge0: Vec3, edge1: Vec3, v: Vec3) Vec3;
pub extern fn v4Smoothstep(edge0: Vec4, edge1: Vec4, v: Vec4) Vec4;

// Is Zero, Is One, Is Unit (for Vec only)
pub extern fn v2IsZero(v: Vec2, eps: f32) bool;
pub extern fn v3IsZero(v: Vec3, eps: f32) bool;
pub extern fn v4IsZero(v: Vec4, eps: f32) bool;
pub extern fn v2IsOne(v: Vec2, eps: f32) bool;
pub extern fn v3IsOne(v: Vec3, eps: f32) bool;
pub extern fn v4IsOne(v: Vec4, eps: f32) bool;
pub extern fn v2IsUnit(v: Vec2, eps: f32) bool;
pub extern fn v3IsUnit(v: Vec3, eps: f32) bool;
pub extern fn v4IsUnit(v: Vec4, eps: f32) bool;

// Projection and Rejection (for Vec only)
pub extern fn v2Project(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Project(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Project(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Reject(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Reject(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Reject(a: Vec4, b: Vec4) Vec4;

// Reflection and refraction
pub extern fn v2Reflect(v: Vec2, n: Vec2) Vec2;
pub extern fn v3Reflect(v: Vec3, n: Vec3) Vec3;
pub extern fn v3Refract(v: Vec3, n: Vec3, eta: f32) Vec3;

// Type conversions
pub extern fn v3FromV2(v: Vec2, z: f32) Vec3;
pub extern fn v4FromV3(v: Vec3, w: f32) Vec4;
pub extern fn v2FromV3(v: Vec3) Vec2;
pub extern fn v3FromV4(v: Vec4) Vec3;
pub extern fn iv3FromIVec2(v: IVec2, z: i32) IVec3;
pub extern fn iv4FromIVec3(v: IVec3, w: i32) IVec4;
pub extern fn iv2FromIVec3(v: IVec3) IVec2;
pub extern fn iv3FromIVec4(v: IVec4) IVec3;
pub extern fn uv3FromUVec2(v: UVec2, z: u32) UVec3;
pub extern fn uv4FromUVec3(v: UVec3, w: u32) UVec4;
pub extern fn uv2FromUVec3(v: UVec3) UVec2;
pub extern fn uv3FromUVec4(v: UVec4) UVec3;
pub extern fn v2FromIVec2(v: IVec2) Vec2;
pub extern fn v3FromIVec3(v: IVec3) Vec3;
pub extern fn v4FromIVec4(v: IVec4) Vec4;
pub extern fn v2FromUVec2(v: UVec2) Vec2;
pub extern fn v3FromUVec3(v: UVec3) Vec3;
pub extern fn v4FromUVec4(v: UVec4) Vec4;
pub extern fn iVec2FromV2(v: Vec2) IVec2;
pub extern fn iVec3FromV3(v: Vec3) IVec3;
pub extern fn iVec4FromV4(v: Vec4) IVec4;
pub extern fn uVec2FromV2(v: Vec2) UVec2;
pub extern fn uVec3FromV3(v: Vec3) UVec3;
pub extern fn uVec4FromV4(v: Vec4) UVec4;
pub extern fn iVec2FromUVec2(v: UVec2) IVec2;
pub extern fn iVec3FromUVec3(v: UVec3) IVec3;
pub extern fn iVec4FromUVec4(v: UVec4) IVec4;
pub extern fn uVec2FromIVec2(v: IVec2) UVec2;
pub extern fn uVec3FromIVec3(v: IVec3) UVec3;
pub extern fn uVec4FromIVec4(v: IVec4) UVec4;
