#import <stdlib.h>
#import <stdio.h>
#import <mach/mach_time.h>
#import <Cocoa/Cocoa.h>

struct platform_win {
    NSWindow* handle;
};

typedef struct platform_win win_t;

struct window {
    int should_close;

    win_t data;
};

typedef struct window window_t;

static double time_init = 0;
static double time_freq = -1;
NSAutoreleasePool* pool;

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
    
    pool = [[NSAutoreleasePool alloc] init];

    [NSApplication sharedApplication];
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
    window_t* window;
    
    window = (window_t*) malloc(sizeof(window_t));

    NSWindow* handle;
    WindowDelegate* delegate;
    NSRect rect = NSMakeRect(0, 0, width, height);
    NSUInteger style =  NSWindowStyleMaskTitled |
                        NSWindowStyleMaskMiniaturizable |
                        NSWindowStyleMaskClosable;

    handle = [[NSWindow alloc] initWithContentRect:rect
                                         styleMask:style
                                           backing:NSBackingStoreBuffered
                                             defer:NO];

    // [handle setTitle:[NSString stringWithUTF8String:title];

    delegate = [[WindowDelegate alloc] initWithWindow:window];
    [handle setDelegate:delegate];
    [handle center];
    [handle makeKeyAndOrderFront:nil];

    window->data.handle = handle;
    return window;
}

void window_destroy(window_t* window) {
    [window->data.handle orderOut: nil];
    [[window->data.handle delegate] release];
    [window->data.handle close];
    
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
}

int window_should_close(window_t* window) {
    return window->should_close;
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
