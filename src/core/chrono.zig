const std = @import("std");

pub const RateLimiter = struct {
    ms: i64,
    now: i64,
    last: i64,
    accum: i64,

    pub fn init(rate: i64) RateLimiter {
        return RateLimiter{
            .ms = @divTrunc(std.time.us_per_s, rate),
            .now = std.time.microTimestamp(),
            .last = std.time.microTimestamp(),
            .accum = 0,
        };
    }

    /// update the time accumulator since last update call
    fn update(self: *RateLimiter) void {
        self.now = std.time.microTimestamp();
        self.accum += self.now - self.last;
        self.last = self.now;
    }

    /// asserts that the accumulator is safe to decrement
    ///
    /// should only call if you know stepping is safe (see `shouldStep`)
    pub fn step(self: *RateLimiter) void {
        std.debug.assert(self.accum >= self.ms);
        self.accum -= self.ms;
    }

    /// is it time to do the thing?
    pub fn shouldStep(self: RateLimiter) bool {
        return self.accum >= self.ms;
    }

    /// returns the number of steps that would have passed since last flush call
    pub fn stepAll(self: *RateLimiter) u32 {
        self.update();

        var step_count: u32 = 0;
        // TODO death spiral if update func takes longer than ms
        // while (self.accum >= self.ms) {
        //     step_count += 1;
        //     self.accum -= self.ms;
        // }
        while (self.shouldStep()) {
            self.step();
            step_count += 1;
        }
        return step_count;
    }

    /// same as `stepAll` but calls `func` every step
    pub fn call(self: *RateLimiter, func: *const fn (i64, ?*anyopaque) void, ctx: ?*anyopaque) void {
        self.update();

        // TODO death spiral if update func takes longer than ms
        while (self.shouldStep()) {
            self.step();
            func(self.ms, ctx);
        }
    }
};

// const Freq = struct {
//     us: i64,
//     now: i64,
//     last: i64,
//     accum: i64,

//     pub fn init(rate: i64) Freq {
//         return Freq{
//             .us = @divTrunc(std.time.us_per_s, rate),
//             .now = std.time.microTimestamp(),
//             .last = std.time.microTimestamp(),
//             .accum = 0,
//         };
//     }

//     pub fn call(self: *Freq, func: *const fn (i64) void) void {
//         self.now = std.time.microTimestamp();
//         self.accum += self.now - self.last;
//         self.last = self.now;

//         // TODO death spiral if update func takes longer than ms
//         while (self.accum >= self.us) {
//             func(self.us);
//             self.accum -= self.us;
//         }
//     }

//     pub fn poll(self: *Freq) bool {
//         self.now = std.time.microTimestamp();
//         self.accum += self.now - self.last;
//         self.last = self.now;
//         if (self.accum >= self.us) {
//             self.accum -= self.us;
//             return true;
//         }
//         return false;
//     }
// };
