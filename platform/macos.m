#import "platform.h"

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <assert.h>
#import <mach/mach_time.h>
#import <Cocoa/Cocoa.h>


struct platform_data {
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




window_t* window_create(const char* title, int w, int h) {
    if (!NSApp) return nil;

    if (w <= 0) w = 600;
    if (h <= 0) h = 400;
	
    window_t* window;
    surface_t* surface;
	
    window = (window_t*) malloc(sizeof(window_t));
    memset(window, 0, sizeof(window_t));

	surface = (surface_t*) malloc(sizeof(surface_t));
	surface->width = w;
	surface->height = h;
	int buf_size = 4 * w * h;
    unsigned char* buffer = (unsigned char*) malloc(buf_size);
    memset(buffer, 0, buf_size);
	surface->buffer = buffer;
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

    delegate = [[WindowDelegate alloc] initWithWindow:window];

	view = [[[ContentView alloc] initWithWindow:window] autorelease];

	assert(handle != nil);
	assert(delegate != nil);
	assert(view != nil);
    window->data->handle = handle;

    [handle setDelegate:delegate];
	[handle setContentView:view];
    [handle setTitle:[NSString stringWithUTF8String:title];
	[handle setColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    [handle center];
	[handle makeFirstResponder:view];
    [handle makeKeyAndOrderFront:nil];	

    return window;
}

void window_destroy(window_t* window) {
    [window->handle orderOut: nil];
    [[window->handle delegate] release];
    [window->handle close];
	
	free(window->surface->buffer);
	free(window->surface);
    free(window);
    
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

void window_present(window_t* window) {
	[[window->handle contentView] setNeedsDisplay:YES];
}




void poll() {
    while (1) {
        NSEvent* event = [NSApp 
            nextEventMatchingMask:NSEventMaskAny
                        untilDate:nil
                           inMode:NSDefaultRunLoopMode
                          dequeue:YES];

        if (event == nil) break;
        [NSApp sendEvent:event];
    }
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

double time() {
    return platform_cpu_time() - time_init;
}
