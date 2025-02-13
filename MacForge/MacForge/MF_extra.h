//
//  MF_extra.h
//  Dark Boot
//
//  Created by Wolfgang Baird on 5/8/20.
//

@import AppKit;
@import CocoaMarkdown;
@import AppCenterAnalytics;

@interface MF_sidebarButton : NSView

@property IBOutlet NSImageView*     buttonImage;
@property IBOutlet NSButton*        buttonClickArea;
@property IBOutlet NSTextField*     buttonLabel;
@property IBOutlet NSView*          linkedView;

@end

@interface MF_extra: NSObject

@property NSUInteger                macOS;
@property IBOutlet NSArray          *preferenceViews;
@property IBOutlet NSArray          *sidebarTopButtons;
@property IBOutlet NSArray          *sidebarBotButtons;
@property IBOutlet NSView           *mainView;
@property IBOutlet NSWindow         *mainWindow;
@property IBOutlet NSWindow         *prefWindow;
@property IBOutlet NSTextView       *changeLog;

- (void)setupSidebar;
- (IBAction)selectView:(id)sender;
- (IBAction)selectPreference:(id)sender;
- (IBAction)selectAboutInfo:(id)sender;
- (void)setMainViewSubView:(NSView*)subview;
- (void)systemDarkModeChange:(NSNotification *)notif;

@end
