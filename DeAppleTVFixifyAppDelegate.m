//
//  DeAppleTVFixifyAppDelegate.m
//  DeAppleTVFixify
//
//  Created by Patrick Quinn-Graham on 09-06-28.
//  Copyright 2009 Patrick Quinn-Graham. All rights reserved.
//

#if !__LP64__
#import <QuickTime/QuickTime.h>
#endif

#import <QTKit/QTKit.h>
#import "NBInvocationQueue.h"
#import "DeAppleTVFixifyAppDelegate.h"


@implementation DeAppleTVFixifyAppDelegate

@synthesize window, fileName, active, status, start, moviesToProcess, tableView;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"Hi");
	// Insert code here to initialize your application 
	queue = [[NBInvocationQueue alloc] init];
	[NSThread detachNewThreadSelector:@selector(runQueueThread) toTarget:queue withObject:nil];
	
	[QTMovie enterQTKitOnThread];
	[[queue performThreadedWithTarget:self] qtKitStart];
	
	currentMovie = 0;
	self.moviesToProcess = [NSMutableArray arrayWithCapacity:10];
	inFlight = NO;
    
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleOpenContentsEvent:replyEvent:) forEventClass:kCoreEventClass andEventID:kAEOpenContents];
}

- (void) application:(NSApplication *)sender openFiles:(NSArray *)filenames {
    for( NSString* filename in filenames ) {
        NSLog(@"TODO, do somemthing with %@", [NSURL fileURLWithPath:filename]);
        [moviesToProcess addObject:[NSURL fileURLWithPath:filename]];
        [tableView reloadData];
        if(!inFlight) {
            inFlight = YES;
            [active startAnimation:self];
            [self nextMovie:nil];
        }

    }
}

- (void)handleOpenContentsEvent:(NSAppleEventDescriptor *)event replyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSLog(@"HandleOpenContentsEvent: %@", event);
}

-(void)qtKitStart {
	[QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
}

-(void)qtKitEnd {
	[QTMovie exitQTKitOnThread];
}

-(IBAction)pickFile:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setPrompt:@"Choose Files"];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"mov"]];
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if(result == NSOKButton) {
			[moviesToProcess addObjectsFromArray:[openPanel URLs]];
			[tableView reloadData];
			if(!inFlight) {
				inFlight = YES;
				[active startAnimation:self];
				[self nextMovie:nil];
			}
		}
	}];
}

-(void)nextMovie:(id)senderMovie {
	
	if(senderMovie) {
		NSLog(@"calling -attachToCurrentThread, on main thread...");
		[senderMovie attachToCurrentThread];
		[senderMovie release];
	}
	
	if(currentMovie >= [moviesToProcess count]) {
		[tableView reloadData];
		[active stopAnimation:self];
		inFlight = NO;
		return; // done.
	}
	
	NSURL *movieUrl = [moviesToProcess objectAtIndex:currentMovie];
	NSError *err = nil;
	
	QTMovie *mMovie = [[QTMovie alloc] initWithURL:movieUrl error:&err];
	if(err != nil) {
		NSLog(@"Failed to create qtmovie: %@", err);
		[mMovie release];
		currentMovie++;
		[self nextMovie:nil];
		return;
	}
	
	NSString *s = [NSString stringWithFormat:@"File %d of %d", (currentMovie + 1), [moviesToProcess count]];
	[fileName setTitleWithMnemonic:s];
	
	NSLog(@"calling -detachFromCurrentThread, on main thread...");
	BOOL r = [mMovie detachFromCurrentThread];
	NSLog(@"... %@", r ? @"YES" : @"NO");
	[[queue performThreadedWithTarget:self] processMovieBackground:mMovie];
	
	currentMovie++;
	[tableView reloadData];
}

-(void)processMovieBackground:(QTMovie*)movie {
	
	NSLog(@"calling -attachToCurrentThread, on background thread...");
	[movie attachToCurrentThread];	
	[movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieEditableAttribute];
	
	NSArray *audioTracks = [movie tracksOfMediaType:QTMediaTypeSound];
	if([audioTracks count] == 2) {
		for(QTTrack *at in audioTracks) {
			QTTimeRange rng;
			[[at attributeForKey:QTTrackRangeAttribute] getValue:&rng];
			NSString *format = [at attributeForKey:QTTrackFormatSummaryAttribute];
			if([[format substringToIndex:3] isEqualToString:@"AAC"] && rng.duration.timeValue / rng.duration.timeScale) {
				[movie removeTrack:at];
			}
		}
	}
	
	NSArray *videoTracks = [movie tracksOfMediaType:QTMediaTypeVideo];
	if([videoTracks count] == 2) {
		for(QTTrack *vt in videoTracks) {
			NSString *format = [vt
								attributeForKey:QTTrackFormatSummaryAttribute];
			if([format isEqualToString:@"H.264, 100 x 100, Millions"]) {
				[movie removeTrack:vt];
			}
		}
	}
	
	[movie updateMovieFile];
	NSLog(@"calling -detachFromCurrentThread, on background thread...");

	[movie detachFromCurrentThread];
	[self performSelectorOnMainThread:@selector(nextMovie:) withObject:movie waitUntilDone:NO];
}

-(void)dealloc {
	[moviesToProcess release];
	[[queue performThreadedWithTarget:self] qtKitEnd];
	[queue release];
	[QTMovie exitQTKitOnThread];
	[super dealloc];
}

#pragma mark -
#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	return [moviesToProcess count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if([[aTableColumn identifier] isEqualToString:@"urlToShow"]) {
		
		NSString *url = [(NSURL*)[moviesToProcess objectAtIndex:rowIndex] path];
		return url;
		
	}
	
	if(rowIndex < (currentMovie - 1) || (rowIndex == (currentMovie - 1) && !inFlight))
		return @"Done.";
	if(rowIndex == (currentMovie - 1))
		return @"In Progress...";
	return @"";
}

@end
