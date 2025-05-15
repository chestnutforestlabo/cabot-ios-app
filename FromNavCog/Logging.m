/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/


#import "Logging.h"

void NavNSLog(NSString* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    if (!isatty(STDERR_FILENO))
    {
        fprintf(stdout, "%s\n", [msg UTF8String]);
    }
    va_start(args, fmt);
    NSLogv(fmt, args);
    va_end(args);
}
void NavNSLogv(NSString* fmt, va_list args) {
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    if (!isatty(STDERR_FILENO))
    {
        fprintf(stdout, "%s\n", [msg UTF8String]);
    }
    NSLogv(fmt, args);
}

@implementation Logging

static int stderrSave = 0;
static NSString *logFilePath = nil;
static NSDate *logFileDate;
static BOOL isSensorLogging = true;

+ (NSString*)startLog:(BOOL)_isSensorLogging {
    if (stderrSave != 0) {
        return nil;
    }
    isSensorLogging = _isSensorLogging;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];

    static NSDateFormatter *formatter;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:[NSString stringWithFormat:@"'%@-'yyyy-MM-dd-HH-mm-ss'.log'", appName]];
        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
    }
    logFileDate = [NSDate date];
    NSString *fileName = [formatter stringFromDate:logFileDate];
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    logFilePath = [dir stringByAppendingPathComponent:fileName];
    NSLog(@"Start log to %@", logFilePath);
    
    stderrSave = dup(STDERR_FILENO);
    freopen([logFilePath UTF8String],"a+",stderr);
    return logFilePath;
}

+(NSString *)logFilePath
{
    return logFilePath;
}

+(void)stopLog {
    if(stderrSave == 0) {
        return;
    }
    if (stderrSave > 0) {
        fflush(stderr);
        dup2(stderrSave, STDERR_FILENO);
        close(stderrSave);
    }
    stderrSave = 0;
    NSLog(@"Stop log");
}

+(BOOL)isLogging {
    return stderrSave != 0;
}

+(BOOL)isSensorLogging {
    return isSensorLogging;
}

+ (void)logType:(NSString *)type withParam:(NSDictionary *)param
{
    NSString *paramStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:param
                                                                                        options:0 error:nil]
                                               encoding:NSUTF8StringEncoding];
    long timestamp = (long)([[NSDate date] timeIntervalSince1970]*1000);
    NSLog(@"%@,%ld,%@", type, timestamp, paramStr);
}

+(void)checkLogDate {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy/MM/dd";
    fmt.timeZone = [NSTimeZone systemTimeZone];
    NSString *fileDate = [fmt stringFromDate:logFileDate];
    NSString *currentDate = [fmt stringFromDate:[NSDate date]];
    if (![fileDate isEqualToString:currentDate]) {
        NSLog(@"Current log file closed");
        [self stopLog];
        [self startLog:TRUE];
        NSLog(@"New log file opened");
    }
}

@end
