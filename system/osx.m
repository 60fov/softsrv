#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <assert.h>
#import <mach/mach_time.h>
#import <Cocoa/Cocoa.h>

#import "system.h"


typedef struct OsxData {
    NSWindow* handle;
} OsxData;



static double time_init = 0;
static double time_freq = -1;
static NSAutoreleasePool* pool;

window_t m_window;
int m_quit;

@interface WindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation WindowDelegate {
}

- (BOOL) windowShouldClose: (NSWindow*) sender {
    m_quit = 1;
    return NO;
}
@end

@interface ContentView : NSView
@end

@implementation ContentView {
}

- (BOOL) acceptsFirstResponder {
	return YES;
}

- (void) drawRect: (NSRect) dirtyRect {
	unsigned char* buff = m_window.buffer;
	NSBitmapImageRep* rep = [[[NSBitmapImageRep alloc] 
		initWithBitmapDataPlanes:&buff
					  pixelsWide:m_window.width
					  pixelsHigh:m_window.height
				   bitsPerSample:8
				 samplesPerPixel:3
						hasAlpha:NO
						isPlanar:NO
				  colorSpaceName:NSCalibratedRGBColorSpace
					 bytesPerRow:m_window.width*4
					bitsPerPixel:32] autorelease];

	NSImage* image = [[[NSImage alloc] init] autorelease];
	[image addRepresentation:rep];
	[image drawInRect:dirtyRect];
}
@end



double system_cpu_time(void) {
    return mach_absolute_time() * time_freq;
}

double system_freq(void) {
    return time_freq;
}

double system_time(void) {
    return system_cpu_time() - time_init;
}


void system_init(const char* title, int w, int h) {
    // init time system
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    time_freq = (double)info.numer / (double)info.denom / 1e9;
    time_init = system_cpu_time();
    
    // init memory system
	if (pool != nil) [pool drain];
    pool = [[NSAutoreleasePool alloc] init];

    // init app
    [NSApplication sharedApplication];
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	[NSApp activateIgnoringOtherApps:YES];
    [NSApp finishLaunching];

    // init window
    if (w <= 0) w = 600;
    if (h <= 0) h = 400;
	
    m_quit = 0;
	m_window.width = w;
	m_window.height = h;
	int buf_size = w*h*4;

	m_window.pdata = malloc(sizeof(OsxData));
	memset(m_window.pdata, 0, sizeof(OsxData));

    m_window.buffer = (unsigned char*) malloc(buf_size);
    memset(m_window.buffer, 0, buf_size);

    NSWindow* handle;
    WindowDelegate* delegate;
	ContentView* view;
    NSRect rect = NSMakeRect(0, 0, w, h);
    NSUInteger style =  NSWindowStyleMaskTitled |
                        NSWindowStyleMaskMiniaturizable |
                        NSWindowStyleMaskClosable;

    handle = [[NSWindow alloc] initWithContentRect:rect
                                         styleMask:style
                                           backing:NSBackingStoreBuffered
                                             defer:NO];

    delegate = [[WindowDelegate alloc] init];

	view = [[[ContentView alloc] init] autorelease];

	assert(handle != nil);
	assert(delegate != nil);
	assert(view != nil);
    ((OsxData*)m_window.pdata)->handle = handle;

    [handle setDelegate:delegate];
	[handle setContentView:view];
    [handle setTitle:[NSString stringWithUTF8String:title]];
	[handle setColorSpace:[NSColorSpace genericRGBColorSpace]];
    
    [handle center];
	[handle makeFirstResponder:view];
    [handle makeKeyAndOrderFront:nil];
}

void system_destroy(void) {
	NSWindow* handle = ((OsxData*)m_window.pdata)->handle;
    [handle orderOut: nil];
    [[handle delegate] release];
    [handle close];
	
	free(m_window.buffer);
	free(m_window.pdata);
    
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}


void system_present(void) {
	[[((OsxData*)m_window.pdata)->handle contentView] setNeedsDisplay:YES];
}


void system_poll(void) {
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

