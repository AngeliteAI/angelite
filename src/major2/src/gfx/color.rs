use std::ops::{Add, Div, Mul, Sub};

/// Color struct representing RGBA color values
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Color {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl Color {
    /// Create a new color with r, g, b, a components
    pub fn new(r: f32, g: f32, b: f32, a: f32) -> Self {
        Self { r, g, b, a }
    }

    /// Create a new color with r, g, b components and alpha = 1.0
    pub fn rgb(r: f32, g: f32, b: f32) -> Self {
        Self { r, g, b, a: 1.0 }
    }

    /// Create a new color from 0-255 range values
    pub fn from_rgba8(r: u8, g: u8, b: u8, a: u8) -> Self {
        Self {
            r: r as f32 / 255.0,
            g: g as f32 / 255.0,
            b: b as f32 / 255.0,
            a: a as f32 / 255.0,
        }
    }

    /// Create a new color from 0-255 range RGB values with alpha = 1.0
    pub fn from_rgb8(r: u8, g: u8, b: u8) -> Self {
        Self::from_rgba8(r, g, b, 255)
    }

    /// Create a color from a hexadecimal value (#RRGGBB or #RRGGBBAA)
    pub fn from_hex(hex: &str) -> Result<Self, &'static str> {
        let hex = hex.trim_start_matches('#');

        match hex.len() {
            6 => {
                // Format: RRGGBB
                if let (Ok(r), Ok(g), Ok(b)) = (
                    u8::from_str_radix(&hex[0..2], 16),
                    u8::from_str_radix(&hex[2..4], 16),
                    u8::from_str_radix(&hex[4..6], 16),
                ) {
                    Ok(Self::from_rgb8(r, g, b))
                } else {
                    Err("Invalid hex color format")
                }
            }
            8 => {
                // Format: RRGGBBAA
                if let (Ok(r), Ok(g), Ok(b), Ok(a)) = (
                    u8::from_str_radix(&hex[0..2], 16),
                    u8::from_str_radix(&hex[2..4], 16),
                    u8::from_str_radix(&hex[4..6], 16),
                    u8::from_str_radix(&hex[6..8], 16),
                ) {
                    Ok(Self::from_rgba8(r, g, b, a))
                } else {
                    Err("Invalid hex color format")
                }
            }
            _ => Err("Invalid hex color length"),
        }
    }

    /// Convert the color to a 4-element array [r, g, b, a]
    pub fn to_array(&self) -> [f32; 4] {
        [self.r, self.g, self.b, self.a]
    }

    /// Linear interpolation between two colors
    pub fn lerp(&self, other: &Self, t: f32) -> Self {
        let t = t.clamp(0.0, 1.0);
        Self {
            r: self.r + (other.r - self.r) * t,
            g: self.g + (other.g - self.g) * t,
            b: self.b + (other.b - self.b) * t,
            a: self.a + (other.a - self.a) * t,
        }
    }

    /// Create a white color
    pub fn white() -> Self {
        Self::rgb(1.0, 1.0, 1.0)
    }

    /// Create a black color
    pub fn black() -> Self {
        Self::rgb(0.0, 0.0, 0.0)
    }

    /// Create a red color
    pub fn red() -> Self {
        Self::rgb(1.0, 0.0, 0.0)
    }

    /// Create a green color
    pub fn green() -> Self {
        Self::rgb(0.0, 1.0, 0.0)
    }

    /// Create a blue color
    pub fn blue() -> Self {
        Self::rgb(0.0, 0.0, 1.0)
    }

    /// Create a yellow color
    pub fn yellow() -> Self {
        Self::rgb(1.0, 1.0, 0.0)
    }

    /// Create a cyan color
    pub fn cyan() -> Self {
        Self::rgb(0.0, 1.0, 1.0)
    }

    /// Create a magenta color
    pub fn magenta() -> Self {
        Self::rgb(1.0, 0.0, 1.0)
    }

    /// Create a transparent color
    pub fn transparent() -> Self {
        Self::new(0.0, 0.0, 0.0, 0.0)
    }
}

impl Default for Color {
    fn default() -> Self {
        Self::white()
    }
}

// Operator implementations for Color

impl Add for Color {
    type Output = Self;

    fn add(self, other: Self) -> Self {
        Self {
            r: self.r + other.r,
            g: self.g + other.g,
            b: self.b + other.b,
            a: self.a + other.a,
        }
    }
}

impl Sub for Color {
    type Output = Self;

    fn sub(self, other: Self) -> Self {
        Self {
            r: self.r - other.r,
            g: self.g - other.g,
            b: self.b - other.b,
            a: self.a - other.a,
        }
    }
}

impl Mul for Color {
    type Output = Self;

    fn mul(self, other: Self) -> Self {
        Self {
            r: self.r * other.r,
            g: self.g * other.g,
            b: self.b * other.b,
            a: self.a * other.a,
        }
    }
}

impl Mul<f32> for Color {
    type Output = Self;

    fn mul(self, scalar: f32) -> Self {
        Self {
            r: self.r * scalar,
            g: self.g * scalar,
            b: self.b * scalar,
            a: self.a * scalar,
        }
    }
}

impl Div<f32> for Color {
    type Output = Self;

    fn div(self, scalar: f32) -> Self {
        Self {
            r: self.r / scalar,
            g: self.g / scalar,
            b: self.b / scalar,
            a: self.a / scalar,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_color_creation() {
        let c1 = Color::new(0.5, 0.6, 0.7, 0.8);
        assert_eq!(c1.r, 0.5);
        assert_eq!(c1.g, 0.6);
        assert_eq!(c1.b, 0.7);
        assert_eq!(c1.a, 0.8);

        let c2 = Color::rgb(0.1, 0.2, 0.3);
        assert_eq!(c2.r, 0.1);
        assert_eq!(c2.g, 0.2);
        assert_eq!(c2.b, 0.3);
        assert_eq!(c2.a, 1.0);
    }

    #[test]
    fn test_color_from_rgb8() {
        let c = Color::from_rgb8(128, 64, 255);
        assert!((c.r - 0.5).abs() < 0.01);
        assert!((c.g - 0.25).abs() < 0.01);
        assert!((c.b - 1.0).abs() < 0.01);
        assert_eq!(c.a, 1.0);
    }

    #[test]
    fn test_color_from_hex() {
        let c1 = Color::from_hex("#FF8800").unwrap();
        assert!((c1.r - 1.0).abs() < 0.01);
        assert!((c1.g - 0.533).abs() < 0.01);
        assert!((c1.b - 0.0).abs() < 0.01);
        assert_eq!(c1.a, 1.0);

        let c2 = Color::from_hex("#FF8800AA").unwrap();
        assert!((c2.r - 1.0).abs() < 0.01);
        assert!((c2.g - 0.533).abs() < 0.01);
        assert!((c2.b - 0.0).abs() < 0.01);
        assert!((c2.a - 0.667).abs() < 0.01);
    }

    #[test]
    fn test_color_operators() {
        let c1 = Color::rgb(0.2, 0.3, 0.4);
        let c2 = Color::rgb(0.1, 0.2, 0.3);

        let sum = c1 + c2;
        assert!((sum.r - 0.3).abs() < 0.01);
        assert!((sum.g - 0.5).abs() < 0.01);
        assert!((sum.b - 0.7).abs() < 0.01);

        let scaled = c1 * 2.0;
        assert!((scaled.r - 0.4).abs() < 0.01);
        assert!((scaled.g - 0.6).abs() < 0.01);
        assert!((scaled.b - 0.8).abs() < 0.01);
    }
}
