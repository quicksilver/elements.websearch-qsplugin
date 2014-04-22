#import "QSWebSearchController.h"



@implementation QSWebSearchController
+ (id)sharedInstance {
    static id _sharedInstance;
    if (!_sharedInstance) {
		_sharedInstance = [[[self class] allocWithZone:[self zone]] init];
	}
    return _sharedInstance;  
}

- (id)init {
    self = [super init]; // initWithWindowNibName:@"WebSearch"]; 
    if (self) {
		[[self window] setLevel:NSFloatingWindowLevel];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [[self window]setHidesOnDeactivate:NO];
	//    [webSearchWindow setFrameTopLeftPoint:[mainWindow frame].origin];
}

- (void)searchURL:(NSURL *)searchURL {
	//    NSLog(@"SEARCH: %@",searchURL);
    [self setWebSearch:searchURL];
    //performingWebSearch=YES;
    [self showSearchView:self];
	[[self window] makeKeyAndOrderFront:self];
}

//kQSStringEncoding
- (NSString *)resolvedURL:(NSString *)searchURL forString:(NSString *)string
{
	if (![string length]) {
		// empty search
        return searchURL;
	}
	
	// escape URL, but not # or %
	NSString *query = [searchURL URLEncoding];
	
	// replace 'LINE SEPARATOR' 0x2028 with 'LINE FEED (LF)' 0x0a
	string = [string stringByReplacingOccurrencesOfString:[NSString stringWithUTF8String:"\u2028"] withString:@"\n"];
		
	// Escape everything in the query string
    NSString *searchTerm = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
																			   (CFStringRef) string,
																			   NULL,
																			   (CFStringRef) @"!*'();:@&=+$,/?%#[]",
																			   kCFStringEncodingUTF8);
	
	// Query key set in QSDefines.h - QS Code (typically ***)
    query = [query stringByReplacingOccurrencesOfString:QUERY_KEY withString:searchTerm];
	[searchTerm release];
	return query;
}

- (void)searchURL:(NSString *)searchURL forString:(NSString *)string
{
    NSPasteboard *findPboard=[NSPasteboard pasteboardWithName:NSFindPboard];
    [findPboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [findPboard setString:string forType:NSStringPboardType];
    NSWorkspace *workspace=[NSWorkspace sharedWorkspace];
	
	NSString *query = [self resolvedURL:searchURL forString:string];
	NSURL *url = [NSURL URLWithString:query];
	if ([[url scheme]isEqualToString:@"qss-http"]){
		query = [query stringByReplacingOccurrencesOfString:@"qss-http" withString:@"http"];
		[workspace openURL:[NSURL URLWithString:query]];
	}
	else if ([[url scheme] isEqualToString:@"qss-https"]) {
		query = [query stringByReplacingOccurrencesOfString:@"qss-https" withString:@"https"];
		[workspace openURL:[NSURL URLWithString:query]];
	}
	else if ([[NSArray arrayWithObjects:@"qssp-http",@"http-post", nil] containsObject:[url scheme]]){
		[self openPOSTURL:[NSURL URLWithString:[query stringByReplacingOccurrencesOfString:[url scheme] withString:@"http"]]];
		return;
	}
	else if ([[NSArray arrayWithObjects:@"qssp-https",@"https-post",nil] containsObject:[url scheme]]) {
		[self openPOSTURL:[NSURL URLWithString:[query stringByReplacingOccurrencesOfString:[url scheme] withString:@"https"]]];
		return;
	}
	else{
		NSURL *queryURL=[NSURL URLWithString:query];
		[workspace openURL:queryURL];
	}
}

- (void)openPOSTURL:(NSURL *)searchURL{
    NSMutableString *form=[NSMutableString stringWithCapacity:100];
    
    [form appendString:@"<html><head><title>Quicksilver Search Submitter</title></head><body onLoad=\"document.qsform.submit()\">"];
    [form appendFormat:@"<form name=\"qsform\" action=\"%@\" method=\"POST\">",[[[searchURL absoluteString]componentsSeparatedByString:@"?"]objectAtIndex:0]];
    NSString *component;
    NSEnumerator *queryEnumerator=[[[searchURL query]componentsSeparatedByString:@"&"]objectEnumerator];
    @try {
        while (component = [queryEnumerator nextObject]){
            NSArray *nameAndValue=[component componentsSeparatedByString:@"="];
            [form appendFormat:@"<input type=\"hidden\" name=\"%@\" value=\"%@\" />",
             [[[nameAndValue objectAtIndex:0] URLDecoding ] stringByReplacingOccurrencesOfString:@"+" withString:@" "],
             [[[nameAndValue objectAtIndex:1] URLDecoding ] stringByReplacingOccurrencesOfString:@"+" withString:@" "]];
        }
    }
    @catch (NSException *exception) {
        QSShowAppNotifWithAttributes(@"QSWebSearchPlugin", NSLocalizedStringFromTableInBundle(@"Post URL Error",nil,[NSBundle bundleForClass:[self class]],@"Title for error on creating POST search"),NSLocalizedStringFromTableInBundle(@"Could not parse POST URL. See Console.app for more info.", nil, [NSBundle bundleForClass:[self class]], @"message for error on creating POST search"));
        NSLog(@"%@",exception);
        return;
    }

    [form appendString:@"</form></body></html>"];
    NSString *postFile=[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"QSPOST-%@.html",[NSString uniqueString]]]; 

    [form writeToFile:postFile atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [[NSWorkspace sharedWorkspace] openFile:postFile];
    int64_t delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *err= nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:postFile error:&err]) {
            NSLog(@"Error removing %@, %@",postFile, err);
        }
    });

}

- (IBAction)submitWebSearch:(id)sender {
    if ([[webSearchField stringValue]length]){
		[self searchURL:webSearch forString:[webSearchField stringValue]];
		[self setWebSearch:nil];
		[[self window] orderOut:self];
    }
}

- (IBAction) showSearchView:sender {
    NSPasteboard *findPboard=[NSPasteboard pasteboardWithName:NSFindPboard];
    NSString *webSearchString=[findPboard stringForType:NSStringPboardType];
    if (webSearchString) [webSearchField setStringValue:webSearchString];
    [[self window] orderFront:self];
}

- (void)windowDidResignKey:(NSNotification *)aNotification {
	[[self window] orderOut:self];
}

- (id)webSearch {
	return [[webSearch retain] autorelease];
}

- (void)setWebSearch:(id)newWebSearch {
    [webSearch release];
    webSearch = [newWebSearch retain];
}

@end