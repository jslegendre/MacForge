//
//  MF_discoverView.m
//  MacForge
//
//  Created by Wolfgang Baird on 5/22/20.
//  Copyright © 2020 MacEnhance. All rights reserved.
//

#import "AppDelegate.h"
#import "MF_bundleTinyItem.h"
#import "MF_discoverView.h"

extern AppDelegate *myDelegate;

@implementation MF_discoverView {
    int                 columns;
    MF_repoData         *pluginData;
    NSMutableArray      *smallArray;
    NSArray             *tableContents;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)generateTableContents {
    NSMutableDictionary *dict = MF_repoData.sharedInstance.repoPluginsDic; //dictionary to be sorted

    NSArray *sortedKeys = [dict keysSortedByValueUsingComparator: ^(id obj1, id obj2) {
        //get the key value.
        NSString *s1 = [obj1 valueForKey:@"webPublishDate"];
        NSString *s2 = [obj2 valueForKey:@"webPublishDate"];

        //Convert NSString to NSDate:
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        //Set the AM and PM symbols
//        [dateFormatter setAMSymbol:@"AM"];
//        [dateFormatter setPMSymbol:@"PM"];
       //Specify only 1 M for month, 1 d for day and 1 h for hour
       [dateFormatter setDateFormat:@"MMM dd, yyyy"];
       NSDate *d1 = [dateFormatter dateFromString:s1];
       NSDate *d2 = [dateFormatter dateFromString:s2];

        if ([d1 compare:d2] == NSOrderedAscending)
            return (NSComparisonResult)NSOrderedAscending;
        if ([d1 compare:d2] == NSOrderedDescending)
            return (NSComparisonResult)NSOrderedDescending;
        return (NSComparisonResult)NSOrderedSame;
    }];
//    NSArray *sortedValues = [[dict allValues] sortedArrayUsingSelector:@selector(compare:)];
    
    NSArray         *reversedArray = [[sortedKeys reverseObjectEnumerator] allObjects];
    NSString        *currentDateStr = @"";
    NSMutableArray  *sortedArray = NSMutableArray.new;
    NSMutableArray  *groupCluster = NSMutableArray.new;
    
    // Sort are array into usable table data
    for (NSString *key in reversedArray) {
        MF_Plugin *plug = [MF_repoData.sharedInstance.repoPluginsDic valueForKey:key];
        NSString *pluginUpdateStr = plug.webPublishDate;
        
        // New group
        if (![currentDateStr isEqualToString:pluginUpdateStr] && pluginUpdateStr.length) {
            
            // Set new header string
            currentDateStr = pluginUpdateStr;
            
            // Sort group by name
            if (groupCluster.count > columns) {
                NSArray *pluginSubArray = [groupCluster subarrayWithRange:NSMakeRange(columns, groupCluster.count - columns)];
                NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:@"webName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
                pluginSubArray = [[pluginSubArray sortedArrayUsingDescriptors:@[sorter]] copy];
                groupCluster = [[groupCluster subarrayWithRange:NSMakeRange(0, columns)] arrayByAddingObjectsFromArray:pluginSubArray].mutableCopy;
            }
            
            // Pad out current cluster
            while (groupCluster.count % columns != 0)
                [groupCluster addObject:NSObject.new];
                
            // Add cluster to tableContents
            for (NSObject *o in groupCluster)
                [sortedArray addObject:o];
            
            // Null out cludter
            groupCluster = NSMutableArray.new;
            
            // Add header group
            [groupCluster addObject:pluginUpdateStr];
            for (int i = 0; i < columns - 1; i++)
                [groupCluster addObject:NSObject.new];
            
        }
        [groupCluster addObject:plug];
    }
    
    tableContents = sortedArray.copy;
//    NSLog(@"%@", tableContents);
        
//    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
//    [dateFormatter setDateFormat:@"MMM dd, yyyy"];
//    NSDate *dateFromString = [dateFormatter dateFromString:dateString];
                                        
    // Sort table by name
//    NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:@"webName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
//    dank = [[dank sortedArrayUsingDescriptors:@[sorter]] copy];
}

- (void)viewWillDraw {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        columns = 4;
        smallArray = NSMutableArray.new;
        
        // create a table view and a scroll view
        NSScrollView * tableContainer = [[NSScrollView alloc] initWithFrame:self.frame];
        tableContainer.drawsBackground = false;
        
        _tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
        _tv.delegate = self;
        _tv.dataSource = self;
        _tv.gridColor = NSColor.clearColor;
        _tv.backgroundColor = NSColor.clearColor;
        _tv.headerView = nil;
        _tv.floatsGroupRows = true;
        
        // embed the table view in the scroll view, and add the scroll view to our window.
        [tableContainer setDocumentView:_tv];
        [tableContainer setHasVerticalScroller:YES];
        [self addSubview:tableContainer];
        
        dispatch_queue_t backgroundQueue = dispatch_queue_create("com.w0lf.MacForge", 0);
        dispatch_async(backgroundQueue, ^{
            if (!MF_repoData.sharedInstance.hasFetched) {
                [MF_repoData.sharedInstance fetch_repo:@"https://github.com/MacEnhance/MacForgeRepo/raw/master/repo"];
                [self generateTableContents];
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
    if ([tableContents[row * columns] isKindOfClass:NSString.class])
        return 40;
    return 77;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    [self generateTableContents];
    return ceil(tableContents.count/columns);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([[tableView rowViewAtRow:row makeIfNecessary:NO] isGroupRowStyle]) {
        NSObject *obj = tableContents[row * columns];

        NSTableCellView *result = NSTableCellView.new;
        [result setFrame:CGRectMake(0, 0, 1382, 40)];

        NSTextField *t = [[NSTextField alloc] initWithFrame:CGRectMake(0, 0, 1382, 40)];
        [t setEditable:false];
        [t setFont:[NSFont systemFontOfSize:24]];
        [t setStringValue:(NSString*)obj];

        [result addSubview:t];

        return result;
    } else {
        NSUInteger index = (row * columns + [[tableView tableColumns] indexOfObject:tableColumn]);
        
        if (index < tableContents.count) {
            if ([[[tableContents objectAtIndex:index] class] isEqualTo:MF_Plugin.class]) {
                            
                NSTableCellView *result;
                MF_bundleTinyItem *cont = [[MF_bundleTinyItem alloc] initWithNibName:0 bundle:nil];
                [smallArray addObject:cont];
                result = [[NSTableCellView alloc] initWithFrame:cont.view.frame];
                MF_Plugin *p = [[MF_Plugin alloc] init];
                [result addSubview:cont.view];
                p = [tableContents objectAtIndex:index];
                [cont setupWithPlugin:p];
                
                return result;
            }
        }
    }
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    if ([tableContents[row * columns] isKindOfClass:NSString.class])
        return true;
    return false;
}

@end
