//
//  DKAppDelegate.m
//  MachInjectSample
//
//  Created by Erwan Barrier on 04/12/12.
//  Copyright (c) 2012 Erwan Barrier. All rights reserved.
//

#import "DKAppDelegate.h"
#import "DKInstaller.h"
#import "DKInjectorProxy.h"

#import "SIMBL.h"
#import "PluginManager.h"
#import <Carbon/Carbon.h>

#include <syslog.h>

@implementation DKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSError *error;
    
    // Make sure helpers are installed
    if ([DKInstaller isInstalled] == NO && [DKInstaller install:&error] == NO) {
        assert(error != nil);
        NSLog(@"Couldn't install MachInjectSample (domain: %@ code: %@)", error.domain, [NSNumber numberWithInteger:error.code]);
        //        NSAlert *alert = [NSAlert alertWithError:error];
        //        [alert runModal];
    }
    
    // Check for args so we can run as a command line tool
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if (args.count > 1) {
        Boolean cmd = false;
        NSInteger index;
        // Inject into a bundle
        if ([args containsObject:@"-i"]) {
            cmd = true;
            index = [args indexOfObject:@"-i"] + 1;
            if (args.count > index) {
                NSString *bundleID = [args objectAtIndex:index];
                if (bundleID.length > 0)
                    [DKAppDelegate injectOneProc:bundleID];
            }
        }
        
        if ([args containsObject:@"-u"]) {
            cmd = true;
            [[PluginManager sharedInstance] checkforPluginUpdatesAndInstall:nil];
        }
        
        if (cmd) [NSApp terminate:nil];
    }
    
    [self setupApplication];
}

- (void)setupApplication {
    [self setupMenuItem];
    
    // Watch for app launches using CarbonEventHandler, this catches apps like the Dock and com.apple.appkit.xpc.openAndSavePanelService
    // Which are not logged with NSWorkspaceDidLaunchApplicationNotification
    [DKAppDelegate watchForApplications];
    
    // Try injecting into all runnning process in NSWorkspace.sharedWorkspace
    [DKAppDelegate injectAllProc];
}

- (void)updatesPlugins {
    [[PluginManager sharedInstance] checkforPluginUpdates:nil];
}

- (void)updateMacPlus {
    
}

- (void)setupMenuItem {
    NSMenu *stackMenu = [[NSMenu alloc] initWithTitle:@"MacPlus"];
    NSMenuItem *soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Preferences..." action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open at Login" action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    [stackMenu addItem:NSMenuItem.separatorItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open MacPlus..." action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Update Plugins..." action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    [stackMenu addItem:NSMenuItem.separatorItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Check for Updates..." action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"About MacPlus" action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    soMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:nil keyEquivalent:@""];
    [stackMenu addItem:soMenuItem];
    
    _statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusBar setMenu:stackMenu];
    [_statusBar setTitle:[stackMenu title]];
}

/*
 Watch for application launches using NSWorkspace
 Not currently used
*/
+ (void)startWatching {
    NSNotificationCenter *notificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    [notificationCenter addObserverForName:NSWorkspaceDidLaunchApplicationNotification
                                    object:nil
                                     queue:nil
                                usingBlock:^(NSNotification * _Nonnull note) {
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                        NSRunningApplication *app = [note.userInfo valueForKey:NSWorkspaceApplicationKey];
                                        [DKAppDelegate injectBundle:app];
                                    });
                                }];
}

// Check if a bundle should be injected into specified running application
+ (Boolean)shouldInject:(NSRunningApplication*)runningApp {
    // Don't inject into ourself
    if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:runningApp.bundleIdentifier]) return false;
    
    // Hardcoded blacklist
    if ([@[] containsObject:runningApp.bundleIdentifier]) return false;
    
    // Don't inject if somehow the executable doesn't seem to exist
    if (!runningApp.executableURL.path.length) return false;
    
    // If you change the log level externally, there is pretty much no way
    // to know when the changed. Just reading from the defaults doesn't validate
    // against the backing file very ofter, or so it seems.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults synchronize];
    
    // Log some info about the app
    NSString* appName = runningApp.localizedName;
    SIMBLLogInfo(@"%@ started", appName);
    SIMBLLogDebug(@"app start notification: %@", runningApp);
    
    // Check to see if there are plugins to load
    if ([SIMBL shouldInstallPluginsIntoApplication:[NSBundle bundleWithURL:runningApp.bundleURL]] == NO) return false;
    
    // User Blacklist
    NSString* appIdentifier = runningApp.bundleIdentifier;
    NSArray* blacklistedIdentifiers = [defaults stringArrayForKey:@"SIMBLApplicationIdentifierBlacklist"];
    if (blacklistedIdentifiers != nil && [blacklistedIdentifiers containsObject:appIdentifier]) {
        SIMBLLogNotice(@"ignoring injection attempt for blacklisted application %@ (%@)", appName, appIdentifier);
        return false;
    }
    
    // Abort you're running something other than macOS 10.X.X
    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion != 10) {
        SIMBLLogNotice(@"something fishy - OS X version %ld", [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion);
        return false;
    }
    
    // System item Inject
    if (runningApp.executableURL.path.pathComponents > 0)
        if ([runningApp.executableURL.path.pathComponents[1] isEqualToString:@"System"]) SIMBLLogDebug(@"injecting into system process");
    
    return true;
}

// Try injecting all valid bundles into an running application
+ (void)injectBundle:(NSRunningApplication*)runningApp {
    // Check if there is anything valid to inject
    if ([DKAppDelegate shouldInject:runningApp]) {
        pid_t pid = [runningApp processIdentifier];
        // Try injecting each valid plugin into the application
        for (NSString *bundlePath in [SIMBL pluginsToLoadList:[NSBundle bundleWithPath:runningApp.bundleURL.path]]) {
            NSError *error;
            if ([DKInjectorProxy injectPID:pid :bundlePath :&error] == false) {
                assert(error != nil);
                SIMBLLogNotice(@"Couldn't inject App (domain: %@ code: %@)", error.domain, [NSNumber numberWithInteger:error.code]);
            }
        }
    }
}

// Try injecting all valid bundles into an application based on bundle ID
+ (void)injectOneProc:(NSString*)bundleID {
    // List of all runnning applications with specific bundle ID
    NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
    
    // Try to inject each item with all valid bundles
    for (NSRunningApplication *runningApp in apps)
        [DKAppDelegate injectBundle:runningApp];
}

// Try injecting one specific bundle into all running applications
+ (void)injectOneBundle:(NSString*)bundlePath {
    // List of all runnning applications
    for (NSRunningApplication *runningApp in NSWorkspace.sharedWorkspace.runningApplications) {
        // Check if the specified bundle should load into the application
        if ([DKAppDelegate shouldInject:runningApp]) {
            pid_t pid = [runningApp processIdentifier];
            NSError *error;
            // Inject the bundle
            if ([DKInjectorProxy injectPID:pid :bundlePath :&error] == false) {
                assert(error != nil);
                SIMBLLogNotice(@"Couldn't inject App (domain: %@ code: %@)", error.domain, [NSNumber numberWithInteger:error.code]);
            }
        }
    }
}

// Try injecting all valid bundles into all running applications
+ (void)injectAllProc {
    for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)
        [DKAppDelegate injectBundle:app];
}

// Set up a watcher to automatically load plugins if they're manually placed in one of the valid plugin folders
+ (void)watchForPlugins {
    
}

// Setup Carbon Event handler to watch for application launches
+ (void)watchForApplications {
    static EventHandlerRef sCarbonEventsRef = NULL;
    static const EventTypeSpec kEvents[] = {
        { kEventClassApplication, kEventAppLaunched },
        { kEventClassApplication, kEventAppTerminated }
    };
    if (sCarbonEventsRef == NULL) {
        (void) InstallEventHandler(GetApplicationEventTarget(), (EventHandlerUPP) CarbonEventHandler, GetEventTypeCount(kEvents),
                                   kEvents, (__bridge void *)(self), &sCarbonEventsRef);
    }
}

// Inject into launched applications
static OSStatus CarbonEventHandler(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void* inUserData) {
    pid_t pid;
    (void) GetEventParameter(inEvent, kEventParamProcessID, typeKernelProcessID, NULL, sizeof(pid), NULL, &pid);
    switch ( GetEventKind(inEvent) ) {
        case kEventAppLaunched:
            // App lauched!
            [DKAppDelegate injectBundle:[NSRunningApplication runningApplicationWithProcessIdentifier:pid]];
            break;
        case kEventAppTerminated:
            // App terminated!
            break;
        default:
            assert(false);
    }
    return noErr;
}

@end
