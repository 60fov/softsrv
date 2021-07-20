#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <assert.h>
#import <mach/mach_time.h>
#import <Cocoa/Cocoa.h>

typedef struct window window_t;
typedef struct surface surface_t;

struct surface {
	int width;
	int height;
	unsigned char* buffer;
};
struct window {
    int should_close;
	surface_t* surface;

    NSWindow* handle;
};

static double time_init = 0;
static double time_freq = -1;
static NSAutoreleasePool* pool;

@interface WindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation WindowDelegate {
    window_t* _window;
}

- (instancetype) initWithWindow: (window_t*) window {
    self = [super init];
    _window = window;
    return self;
}

- (BOOL) windowShouldClose: (NSWindow*) sender {
    _window->should_close = 1;
    return NO;
}
@end

@interface ContentView : NSView
@end

@implementation ContentView {
	window_t* _window;
}

- (instancetype) initWithWindow: (window_t*) window {
    self = [super init];
    _window = window;
    return self;
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

- (void) drawRect: (NSRect) dirtyRect {
	surface_t* surf = _window->surface;
	unsigned char* buff = surf->buffer;
	int pc = surf->width * surf->height;
	for(int i = 0; i < pc; i++) {
		double c = (double) i / (double) pc * 255;
	}
	NSBitmapImageRep* rep = [[[NSBitmapImageRep alloc] 
		initWithBitmapDataPlanes:&buff
					  pixelsWide:surf->width
					  pixelsHigh:surf->height
				   bitsPerSample:8
				 samplesPerPixel:3
						hasAlpha:NO
						isPlanar:NO
				  colorSpaceName:NSCalibratedRGBColorSpace
					 bytesPerRow:surf->width*4
					bitsPerPixel:32] autorelease];

	NSImage* image = [[[NSImage alloc] init] autorelease];
	assert(image != nil);
	[image addRepresentation:rep];
	[image drawInRect:dirtyRect];
}
@end



double platform_cpu_time() {
    return mach_absolute_time() * time_freq;
}

double platform_freq() {
    return time_freq;
}

double platform_time() {
    return platform_cpu_time() - time_init;
}

void platform_start() {
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    time_freq = (double)info.numer / (double)info.denom / 1e9;
    time_init = platform_cpu_time();
    
	if (pool != nil) [pool drain];
    pool = [[NSAutoreleasePool alloc] init];

    [NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp finishLaunching];
}

void platform_end() {
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

void poll() {
    while (1) {
        NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                            untilDate:nil
                                               inMode:NSDefaultRunLoopMode
                                              dequeue:YES];
        if (event == nil) break;
        [NSApp sendEvent:event];
    }
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

window_t* window_create(int width, int height) {
	assert(NSApp && width > 0 && height > 0);
    window_t* window;
    surface_t* surface;
	
    window = (window_t*) malloc(sizeof(window_t));
	memset(window, 0, sizeof(window_t));

	surface = (surface_t*) malloc(sizeof(surface_t));
	surface->width = width;
	surface->height = height;
	int buf_size = 4 * width * height;
	surface->buffer = (unsigned char*) malloc(buf_size);
	memset(surface->buffer, 255, buf_size); 
	window->surface = surface;
	
    NSWindow* handle;
    WindowDelegate* delegate;
	ContentView* view;
    NSRect rect = NSMakeRect(0, 0, width, height);
    NSUInteger style =  NSWindowStyleMaskTitled |
                        NSWindowStyleMaskMiniaturizable |
                        NSWindowStyleMaskClosable;

    handle = [[NSWindow alloc] initWithContentRect:rect
                                         styleMask:style
                                           backing:NSBackingStoreBuffered
                                             defer:NO];

	assert(handle != nil);
    // [handle setTitle:[NSString stringWithUTF8String:title];
	[handle setColorSpace:[NSColorSpace genericRGBColorSpace]];
    window->handle = handle;
	
    delegate = [[WindowDelegate alloc] initWithWindow:window];
	assert(delegate != nil);
    [handle setDelegate:delegate];

	view = [[[ContentView alloc] initWithWindow:window] autorelease];
	assert(view != nil);
	[handle setContentView:view];
	[handle makeFirstResponder:view];

    [handle center];
    [handle makeKeyAndOrderFront:nil];
    return window;
}

void window_destroy(window_t* window) {
    [window->handle orderOut: nil];
    [[window->handle delegate] release];
    [window->handle close];
	
	free(window->surface->buffer);
	free(window->surface);
    
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

void window_present(window_t* window) {
	[[window->handle contentView] setNeedsDisplay:YES];
}

int window_should_close(window_t* window) {
    return window->should_close;
}

surface_t* window_surface(window_t* window) {
	return window->surface;
}

/*
int main(int argc, char** argv) {
    platform_start();
    
    window_t* window = window_create(600, 400);

    while(!window->should_close) {
        poll();
    }

    platform_end();
}
*/
