//
//  MF_webPlguinTableController.m
//  MacForge
//
//  Created by Wolfgang Baird on 5/21/20.
//  Copyright © 2020 MacEnhance. All rights reserved.
//

#import "AppDelegate.h"
#import "MF_featuredView.h"
#import "MF_featuredItemController.h"

extern AppDelegate *myDelegate;

int columns = 3;

@implementation MF_featuredView {
    MF_Plugin           *plug;
    MF_PluginManager    *sharedMethods;
    MF_repoData         *pluginData;
    NSMutableDictionary *featuredRepo;
    NSArray             *bundles;
    NSMutableArray      *smallArray;
}

- (void)viewWillDraw {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        smallArray = NSMutableArray.new;
        
        // Create a table view
        _tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 700, 500)];
        _tv.delegate = self;
        _tv.dataSource = self;
        _tv.gridColor = NSColor.clearColor;
        _tv.backgroundColor = NSColor.clearColor;
        _tv.headerView = nil;
        
        // Create a scroll view and embed the table view in the scroll view, and add the scroll view to our window.
        NSScrollView * tableContainer = [[NSScrollView alloc] initWithFrame:self.frame];
        tableContainer.documentView = _tv;
        tableContainer.drawsBackground = false;
        tableContainer.hasVerticalScroller = true;
        tableContainer.hasHorizontalScroller = false;
        tableContainer.horizontalScrollElasticity = NSScrollElasticityNone;
        [self addSubview:tableContainer];
        
        dispatch_queue_t backgroundQueue = dispatch_queue_create("com.w0lf.MacForge", 0);
        dispatch_async(backgroundQueue, ^{
            if (!MF_repoData.sharedInstance.hasFetched) {
                [MF_repoData.sharedInstance fetch_repo:@"https://github.com/MacEnhance/MacForgeRepo/raw/master/repo"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tv reloadData];
                });
            }
        });
        
        // create columns for our table
        for (int i = 0; i < columns; i++) {
            NSString *identify = [NSString stringWithFormat:@"Col%d", i];
            NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:identify];
            [column setWidth:self.frame.size.width/columns];
            [_tv addTableColumn:column];
        }
    });
    
    [_tv sizeToFit];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    MF_featuredItemController *cont = [[MF_featuredItemController alloc] initWithNibName:0 bundle:nil];
    return cont.view.frame.size.height;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSArray *filter = [MF_repoData.sharedInstance fetch_featured:@"https://github.com/MacEnhance/MacForgeRepo/raw/master/repo"].copy;
    bundles = [MF_repoData.sharedInstance.repoPluginsDic.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"bundleID in %@", filter]];
    return ceil(bundles.count/columns);
}

- (NSView *)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self tableView:tableView viewForTableColumn:tableColumn row:row];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    MF_featuredItemController *cont = [[MF_featuredItemController alloc] initWithNibName:0 bundle:nil];
    [smallArray addObject:cont];
    NSTableCellView *result = [[NSTableCellView alloc] initWithFrame:cont.view.frame];
    MF_Plugin *p = [[MF_Plugin alloc] init];
    NSUInteger index = (row * columns + [[tableView tableColumns] indexOfObject:tableColumn]);
    if (index < bundles.count) {
        p = [bundles objectAtIndex:index];
        [cont setupWithPlugin:p];
    }
    [result addSubview:cont.view];
    return result;
}

@end
