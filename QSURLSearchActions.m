#import "QSURLSearchActions.h"
#import "QSWebSearchController.h"

# define kURLSearchForAction @"QSURLSearchForAction"
# define kURLSearchForAndReturnAction @"QSURLSearchForAndReturnAction"
# define kURLFindWithAction @"QSURLFindWithAction"

@implementation QSURLSearchActions
- (NSString *) defaultWebClient{
	
	NSURL *appURL = nil; 
	OSStatus err; 
	err = LSGetApplicationForURL((CFURLRef)[NSURL URLWithString: @"http:"],kLSRolesAll, NULL, (CFURLRef *)&appURL); 
	if (err != noErr) NSLog(@"error %ld", (long)err);
	// else NSLog(@"%@", appURL); 
	
	return [appURL path];
	
}

- (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject{
	// if it's a 'find with...' action, only return search URLs
	if ([action isEqualToString:kURLFindWithAction]) {
        // change to scoredArrayForType: when quicksilver/Quicksilver#1162 is merged
        return [QSLib scoredArrayForString:nil inSet:[QSLib arrayForType:QSSearchURLType] mnemonicsOnly:YES];
	}
	// if it's a 'search for...' action, return a text bot for text
	else if ([action isEqualToString:kURLSearchForAction] || [action isEqualToString:kURLSearchForAndReturnAction]){
		NSString *webSearchString=[[NSPasteboard pasteboardWithName:NSFindPboard] stringForType:NSStringPboardType];
		return [NSArray arrayWithObject: [QSObject textProxyObjectWithDefaultValue:(webSearchString?webSearchString:@"")]]; //[QSLibarrayForType:NSFilenamesPboardType];
		// return [NSArray arrayWithObject:[QSTextEntryProxy sharedInstance]]; //[QSLibarrayForType:NSFilenamesPboardType];
	}
	
	return nil;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject{
	NSString *urlString=[[dObject arrayForType:QSSearchURLType] lastObject];
	
	NSMutableArray *newActions=[NSMutableArray arrayWithCapacity:1];
    NSString *query = nil;
	if (urlString){
		NSURL *url=[NSURL URLWithString:[urlString URLEncoding]];
		query =[url absoluteString];
	}
    if (query) {
        [newActions addObject:kURLSearchForAction];
        [newActions addObject:kURLSearchForAndReturnAction];
    }
	else if ([dObject containsType:QSTextType] && ![dObject containsType:QSFilePathType]) {
		[newActions addObject:kURLFindWithAction];
	}
	
	return newActions;
}


- (QSObject *)doURLSearchAction:(QSObject *)dObject{
	// get an NSURL
	[[QSWebSearchController sharedInstance] searchURL:[dObject objectForType:QSSearchURLType]];
	return nil;
}

- (QSObject *)doURLSearchForAction:(QSObject *)dObject withString:(QSObject *)iObject{
	
	for(NSString * urlString in [dObject arrayForType:QSSearchURLType]){
        for (QSObject *obj in [iObject splitObjects]) {
            NSString *string = [obj stringValue];
            if (![string length]) {
                NSBeep();
                NSLog(@"web search attempted with no search terms");
                continue;
            }
            [[QSWebSearchController sharedInstance] searchURL:urlString forString:string];
        }
	}
	return nil;
}
- (QSObject *)doURLSearchForAndReturnAction:(QSObject *)dObject withString:(QSObject *)iObject{
	for(NSString * urlString in [dObject arrayForType:QSSearchURLType]){
		NSString *string=[iObject stringValue];
		
		NSString *query=[[QSWebSearchController sharedInstance] resolvedURL:urlString forString:string];
		BOOL post=NO;
		NSURL *url = [NSURL URLWithString:query];
		if ([[url scheme]isEqualToString:@"qssp-http"]){
			[[QSWebSearchController sharedInstance] openPOSTURL:[NSURL URLWithString:[query stringByReplacingOccurrencesOfString:@"qssp-http" withString:@"http"]]];
		//	return;
		} else if ([[url scheme]isEqualToString:@"http-post"]){
			NSBeep();
			post=YES;
			query=[query stringByReplacingOccurrencesOfString:@"http-post" withString:@"http"];
		//	return;
		} else if ([[url scheme]isEqualToString:@"qss-http"]){
			query=[query stringByReplacingOccurrencesOfString:@"qss-http" withString:@"http"];
		} else if ([[url scheme]isEqualToString:@"qss-https"]) {
			query=[query stringByReplacingOccurrencesOfString:@"qss-https" withString:@"https"];
		}else{
	}
		
		
		id <QSParser> parser=[QSReg instanceForKey:@"html" inTable:@"QSURLTypeParsers"];
		//NSLog(@" %@ %@",type,parser);
		
		[QSTasks updateTask:@"DownloadPage" status:@"Downloading Page" progress:0];
		NSMutableArray *children = [[parser objectsFromURL:[NSURL URLWithString:query] withSettings:nil] mutableCopy];
		[QSTasks removeTask:@"DownloadPage"];
		
		[[QSReg preferredCommandInterface] showArray:children];
	}

	return nil;
}
@end