//
//  DeAppleTVFixifyAppDelegate.h
//  DeAppleTVFixify
//
//  Created by Patrick Quinn-Graham on 09-06-28.
//  Copyright 2009 Patrick Quinn-Graham. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DeAppleTVFixifyAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
	
	NSTextField *fileName;
	NSProgressIndicator *active;
	NSTextField *status;
	NSButton *start;
	
	NSTableView *tableView;
	
	NBInvocationQueue *queue;
	
	NSMutableArray *moviesToProcess;
	NSInteger currentMovie;
	
	BOOL inFlight;
	
}

@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet NSTextField *fileName;
@property (assign) IBOutlet NSProgressIndicator *active;
@property (assign) IBOutlet NSTextField *status;
@property (assign) IBOutlet NSButton *start;
@property (assign) IBOutlet NSTableView *tableView;

@property (nonatomic, retain) NSArray *moviesToProcess;

-(IBAction)pickFile:(id)sender;

-(void)qtKitStart;
-(void)qtKitEnd;

-(void)nextMovie:(id)senderMovie;

-(void)processMovieBackground:(QTMovie*)movie;

@end
