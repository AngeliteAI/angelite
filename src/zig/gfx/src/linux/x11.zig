const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h"); // For XStoreName, etc.
});

// Re-exporting types and functions without "X" prefix
pub const Display = c.Display;
pub const Window = c.Window;
pub const Event = c.XEvent;
pub const pending = c.XPending;
pub const nextEvent = c.XNextEvent;
pub const OpenDisplay = c.XOpenDisplay; // Re-exporting XOpenDisplay as OpenDisplay
pub const DefaultScreen = c.XDefaultScreen; // Re-exporting XDefaultScreen as DefaultScreen
pub const DisplayWidth  = c.XDisplayWidth;
pub const DisplayHeight = c.XDisplayHeight;
pub const RootWindow = c.XRootWindow;     // Re-exporting XRootWindow as RootWindow
pub const CreateSimpleWindow = c.XCreateSimpleWindow; // Re-exporting XCreateSimpleWindow as CreateSimpleWindow
pub const BlackPixel = c.XBlackPixel;     // Re-exporting XBlackPixel as BlackPixel
pub const WhitePixel = c.XWhitePixel;     // Re-exporting XWhitePixel as WhitePixel
pub const MapWindow = c.XMapWindow;       // Re-exporting XMapWindow as MapWindow
pub const Flush = c.XFlush;             // Re-exporting XFlush as Flush
pub const CloseDisplay = c.XCloseDisplay;   // Re-exporting XCloseDisplay as CloseDisplay
pub const DestroyWindow = c.XDestroyWindow; // Re-exporting XDestroyWindow as DestroyWindow
pub const ExposureMask = c.ExposureMask;    // Re-exporting ExposureMask as ExposureMask
pub const SelectInput = c.XSelectInput;   // Re-exporting XSelectInput as SelectInput
pub const StoreName = c.XStoreName;       // Re-exporting XStoreName as StoreName
pub const ResizeWindow = c.XResizeWindow;   // Re-exporting XResizeWindow as ResizeWindow
pub const GetWindowAttributes = c.XGetWindowAttributes; // Re-exporting XGetWindowAttributes as GetWindowAttributes
pub const WindowAttributes = c.XWindowAttributes; // Re-exporting XWindowAttributes as WindowAttributes
