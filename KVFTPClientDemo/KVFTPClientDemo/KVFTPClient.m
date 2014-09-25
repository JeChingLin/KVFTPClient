//
//  FTPClient.m
//  WPDforTab
//
//  Created by Kevin Lin on 12/7/17.
//  Copyright (c) 2012年 GIgastone Co., Ltd. All rights reserved.
//

#import "KVFTPClient.h"

@interface FTPClient()
// Properties that don't need to be seen by the outside world.


@property (nonatomic, strong, readwrite)  NSOutputStream *   createFolderNetworkStream;
@property (nonatomic, strong, readwrite) NSString *c_fileName;
@property (nonatomic, strong, readwrite)  NSInputStream *   s_networkStream;
@property (nonatomic, strong, readwrite)   NSMutableData *   s_listData;
@property (nonatomic, strong, readwrite)   NSMutableArray *  s_listEntries;
@property (nonatomic, strong, readwrite)  NSInputStream *   r_networkStream;
@property (nonatomic, strong, readwrite)   NSMutableData *   r_listData;
@property (nonatomic, strong, readwrite)  NSMutableArray *  r_listEntries;


@property (nonatomic, strong, readwrite) NSInputStream *   d_networkStream;
@property (nonatomic, copy,   readwrite) NSString *        d_filePath;
@property (nonatomic, strong, readwrite) NSOutputStream *  d_fileStream;

@property (nonatomic, strong, readwrite) NSOutputStream *  u_networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *   u_fileStream;
@property (nonatomic, assign, readonly ) uint8_t *         buffer;
@property (nonatomic, assign, readwrite) size_t            bufferOffset;
@property (nonatomic, assign, readwrite) size_t            bufferLimit;

- (void)_updateStatus:(NSString *)statusString;
@end

@implementation FTPClient
@synthesize r_dataList= _r_dataList;
@synthesize s_dataList = _s_dataList;
@synthesize FTPAddresIP = _FTPAddresIP;
@synthesize UserName = _UserName;
@synthesize Password = _Password;
@synthesize delegate;


+(FTPClient*)currentFTP
{
    static id sharedDefaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDefaults = [[self alloc] init];
    });
    return sharedDefaults;
}

-(id)initWithHostAddress:(NSString *)address UserName:(NSString*)username Password:(NSString*)password
 {
    if (self=[super init]) {
        self.FTPAddresIP = address;
        self.UserName = username;
        self.Password = password;
        self.r_listEntries = [NSMutableArray array];
    }
    return self;
}

-(void) initSearch
{
    self.s_listEntries = [NSMutableArray array];
    allSearchListDirEntries = [NSMutableArray array];
    currentSearchDirCount =0;
}

+(BOOL) deleteFileDirectlyWithAddress:(NSString*)address user:(NSString*)user password:(NSString*)password path:(NSString *)ftpPath{
    NSURL * url;
	SInt32 status = 0;
	NSString *ftpUsername=[@"ftp://" stringByAppendingString:user];
	NSString *userNameDots=[ftpUsername stringByAppendingString: @":"];
	NSString *dotsPassword=[userNameDots stringByAppendingString:password];
	NSString *passwordAt=[dotsPassword stringByAppendingString: @"@"];
	NSString *atUrl=[passwordAt stringByAppendingString: address];
	NSString *urlSlash=[atUrl stringByAppendingString: @""];
	url = [[NSURL alloc] initWithString:[[urlSlash stringByAppendingString:ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	CFURLRef urlRef;
	urlRef = (__bridge CFURLRef) url;
	return CFURLDestroyResource(urlRef, &status);
}

-(BOOL) deleteFile:(NSString*) ftpPath
{
    NSURL * url;
	SInt32 status = 0;
	NSString *ftpUsername=[@"ftp://" stringByAppendingString:self.UserName];
	NSString *userNameDots=[ftpUsername stringByAppendingString: @":"];
	NSString *dotsPassword=[userNameDots stringByAppendingString:self.Password];
	NSString *passwordAt=[dotsPassword stringByAppendingString: @"@"];
	NSString *atUrl=[passwordAt stringByAppendingString: self.FTPAddresIP];
	NSString *urlSlash=[atUrl stringByAppendingString: @""];
	url = [[NSURL alloc] initWithString:[[urlSlash stringByAppendingString:ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	CFURLRef urlRef; 
	urlRef = (__bridge CFURLRef) url;
    BOOL deleted;
    
    if (CFURLDestroyResource(urlRef, &status)) {
        deleted = YES;
    }
    else{
        deleted = NO;
    }
	return deleted;

}

- (NSURL *)smartURLForString:(NSString *)str
{
    NSURL *     result;
    NSString *  trimmedStr;
    NSRange     schemeMarkerRange;
    NSString *  scheme;
    
    assert(str != nil);
	
    result = nil;
    
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && (trimmedStr.length != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            result = [NSURL URLWithString:[NSString stringWithFormat:@"ftp://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"ftp"  options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedStr];
            } else {
                // It looks like this is some unsupported URL scheme.
            }
        }
    }
    
    return result;
}


- (void)_updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    NSLog(@"%@", statusString);
}

@synthesize r_networkStream = _r_networkStream;
@synthesize r_listData        = _r_listData;
@synthesize r_listEntries     = _r_listEntries;

-(BOOL)isReceiving{
    return (self.r_networkStream !=nil);
}
- (void)_addListEntries:(NSArray *)newEntries
{
    if(self.r_listEntries == nil)return;
    [self.r_listEntries removeAllObjects];
    [self.r_listEntries addObjectsFromArray:newEntries];
    [self.r_dataList addObjectsFromArray:self.r_listEntries];
}

-(void) receiveDirectoryList:(NSString*) ftpPath{
    [self _stopReceiveWithStatus:nil];
    BOOL                success;
    NSURL *             url;
    CFReadStreamRef     ftpStream;
    
    assert(_r_networkStream == nil);      // don't tap receive twice in a row!
    
    // First get and check the URL.
    
    if(ftpPath != nil)
    {
		url = [self smartURLForString:[[NSString stringWithFormat:@"ftp://%@:%@@%@%@", self.UserName,self.Password,self.FTPAddresIP, ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] ;
	}
    else
    {
        url = [self smartURLForString:[self.FTPAddresIP stringByAppendingString:@""]];
    }
    success = (url != nil);
    NSLog(@"url : %@", url);
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        [self _updateStatus:@"Invalid URL"];
    } else {
        // Create the mutable data into which we will receive the listing.
        
        self.r_listData = [NSMutableData data];
        assert(self.r_listData != nil);
        
        // Open a CFFTPStream for the URL.
        
        ftpStream = CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url);
        assert(ftpStream != NULL);
        
        self.r_networkStream = (__bridge NSInputStream *) ftpStream;
        success = [self.r_networkStream setProperty:(__bridge id) kCFBooleanFalse
                                             forKey:(__bridge NSString *) kCFStreamPropertyFTPAttemptPersistentConnection
                   ];
        assert(success);
        
         self.r_networkStream.delegate = self;
        [ self.r_networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [ self.r_networkStream open];
    
        // Have to release ftpStream to balance out the create.  self.networkStream 
        // has retained this for our persistent use.
        CFRelease(ftpStream);
        
        // Tell the UI we're receiving.
        self.r_dataList = [NSMutableArray array];
        if ([delegate respondsToSelector:@selector(KVFTPDidStartReceived:)]) {
            [delegate KVFTPDidStartReceived:self];
        }
    }
}

-(void)receiveDirectoryList:(NSString *)ftpPath receivedBlock:(FTPDirectoryListReceivedBlock)receivedBlock
{
    self.receivedBlock = receivedBlock;
    [self receiveDirectoryList:ftpPath];
}

-(void)_stopReceiveWithStatus:(NSString *)statusString
{
    if (self.r_networkStream != nil) {
        [self.r_networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.r_networkStream.delegate = nil;
        [self.r_networkStream close];
        self.r_networkStream = nil;
    }
    self.r_listData = nil;
    if ([statusString isEqualToString:@"Cancelled"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidCancel:)]) {
            [delegate KVFTPDidCancel:self];
        }
        return;
    }
    
    if ([statusString isEqualToString:@"Stream open error"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFailedWithReceivedStreamError:)]) {
          [delegate KVFTPDidFailedWithReceivedStreamError:self];
        }
        return;
    }
    
    if ([statusString isEqualToString:@"ReceivedFinished"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFinishReceived:)]) {
            [delegate KVFTPDidFinishReceived:self];
        }
        if (self.receivedBlock) {
            self.receivedBlock(self.r_dataList);
            self.receivedBlock = NULL;
        }
        return;
    }
  
}

// This is the code that actually does the networking.
@synthesize u_networkStream = _u_networkStream;
@synthesize u_fileStream    = _u_fileStream;
@synthesize bufferOffset  = _bufferOffset;
@synthesize bufferLimit   = _bufferLimit;

// Because buffer is declared as an array, you have to use a custom getter.  
// A synthesised getter doesn't compile.

- (uint8_t *)buffer
{
    return self->_buffer;
}

-(BOOL) isUploading
{
    return (self.u_networkStream !=nil);
}

-(void) uploadFile:(NSString*) localPath uploadTo:(NSString*)ftpPath{
    [self _stopUploadWithStatus:nil];
    BOOL                    success;
    NSURL                *url;
    CFWriteStreamRef        ftpStream;
    
    assert(self.u_networkStream == nil);      // don't tap send twice in a row!
    assert(self.u_fileStream == nil);         // ditto
    // First get and check the URL.
    
    url = [self smartURLForString:[[NSString stringWithFormat:@"ftp://%@:%@@%@%@", self.UserName,self.Password,self.FTPAddresIP, ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    success = (url != nil);
    if (success) {
        // Add the last part of the file name to the end of the URL to form the final 
        // URL that we're going to put to.
        url = CFBridgingRelease(
                                CFURLCreateCopyAppendingPathComponent(NULL, (__bridge CFURLRef) url, (__bridge CFStringRef) [localPath lastPathComponent], false)
                                );
        success = (url != nil);
    }
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    if ( ! success) {
        NSLog(@"Invalid URL");
    } else {
        NSLog(@"upload URL : %@", url);
        // Open a stream for the file we're going to send.  We do not open this stream; 
        // NSURLConnection will do it for us.
        
        self.u_fileStream = [NSInputStream inputStreamWithFileAtPath:localPath];
        assert(self.u_fileStream != nil);
        
        [self.u_fileStream open];
//        NSLog(@"fileStream open");
        // Open a CFFTPStream for the URL.
        CFURLRef cfURL = (__bridge CFURLRef)url;
        
        ftpStream = CFWriteStreamCreateWithFTPURL(NULL, cfURL);
        assert(ftpStream != NULL);
        
        self.u_networkStream = (__bridge NSOutputStream *) ftpStream;
        
#pragma unused (success) //Adding this to appease the static analyzer.
        success = [self.u_networkStream setProperty:self.UserName forKey:(id)kCFStreamPropertyFTPUserName];
        assert(success);
        success = [self.u_networkStream setProperty:self.Password forKey:(id)kCFStreamPropertyFTPPassword];
        assert(success);
        success = [self.u_networkStream setProperty:(__bridge id) kCFBooleanFalse
                                             forKey:(__bridge NSString *) kCFStreamPropertyFTPAttemptPersistentConnection
                   ];
        assert(success);
        
        self.u_networkStream.delegate = self;
        [self.u_networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.u_networkStream open];
        
        // Have to release ftpStream to balance out the create.  self.networkStream 
        // has retained this for our persistent use.
//        CFRelease(cfURL);
        CFRelease(ftpStream);
        
        // Tell the UI we're sending.
        if ([delegate respondsToSelector:@selector(KVFTPDidStartUpload:)]) {
            [delegate KVFTPDidStartUpload:self];
        }
    } 
}

-(void)uploadFile:(NSString *)localPath uploadTo:(NSString *)ftpPath progressBlock:(FTPFileUploaderProgressBlock) progressBlock completedBlock:(FTPFilesUploaderCompletedBlock)completedBlock failedBlock:(FTPFilesUploaderFailedBlock)failedBlock
{
    self.uploadProgressBlock = progressBlock;
    self.uploadCompletedBlock = completedBlock;
    self.uploadFailedBlock = failedBlock;
    [self uploadFile:localPath uploadTo:ftpPath];
}

-(void)_stopUploadWithStatus:(NSString *)statusString
{
    if (self.u_networkStream != nil) {
        [self.u_networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.u_networkStream.delegate = nil;
        [self.u_networkStream close];
        self.u_networkStream = nil;
    }
    if (self.u_fileStream != nil) {
        [self.u_fileStream close];
        self.u_fileStream = nil;
    }
    
    if ([statusString isEqualToString:@"StreamOpenError"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFailedWithUploadStreamError:)]) {
            [delegate KVFTPDidFailedWithUploadStreamError:self];
        }
        if (self.uploadFailedBlock) {
            self.uploadFailedBlock();
            self.uploadFailedBlock = NULL;
        }
        return;
    }
    
    if ([statusString isEqualToString:@"Cancel"]){
        if ([delegate respondsToSelector:@selector(KVFTPDidCancel:)]) {
            [delegate KVFTPDidCancel:self];
        }
        return;
    }
    
    if ([statusString isEqualToString:@"Upload Finished"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFinishUpload:)]) {
            [delegate KVFTPDidFinishUpload:self];
        }
        if (self.uploadCompletedBlock) {
            self.uploadCompletedBlock();
            self.uploadCompletedBlock = NULL;
        }
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock = NULL;
        }
        return;
    }
}

@synthesize d_networkStream = _d_networkStream;
@synthesize d_filePath = _d_filePath;
@synthesize d_fileStream = _d_fileStream;
-(BOOL) isDownloading
{
    return (self.d_networkStream != nil);
}
-(void) downloadFile:(NSString*) ftpPath downloadTo:(NSString*) localPath{
    [self _stopDownloadWithStatus:nil];
    BOOL                success;
    NSURL *             url;
    CFReadStreamRef     ftpStream;
    
    assert(self.d_networkStream == nil);      // don't tap receive twice in a row!
    assert(self.d_fileStream == nil);         // ditto
    
    // First get and check the URL.
    url = [self smartURLForString:[[NSString stringWithFormat:@"ftp://%@:%@@%@%@", self.UserName,self.Password,self.FTPAddresIP, ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]] ;
    success = (url != nil);
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    NSLog(@"download URL : %@", url);
    if ( ! success) {
        NSLog(@"Invalid URL");
    } else {
        // Open a stream for the file we're going to receive into.
        self.d_filePath = localPath;
        assert(self.d_filePath != nil);
//        NSLog(@"filePath : %@", self.d_filePath);
        self.d_fileStream = [NSOutputStream outputStreamToFileAtPath:self.d_filePath append:NO];
        assert(self.d_fileStream != nil);
        [self.d_fileStream open];
        // Open a CFFTPStream for the URL.
        
        ftpStream = CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url);
        assert(ftpStream != NULL);
        
        self.d_networkStream = (__bridge NSInputStream *) ftpStream;
        success = [self.d_networkStream setProperty:(__bridge id) kCFBooleanFalse
                                             forKey:(__bridge NSString *) kCFStreamPropertyFTPAttemptPersistentConnection
                   ];
        assert(success);
        
        self.d_networkStream.delegate = self;
        [self.d_networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.d_networkStream open];
        
        
        // Have to release ftpStream to balance out the create.  self.networkStream 
        // has retained this for our persistent use.
        
//        CFRelease(ftpStream);
        // Tell the UI we're receiving.
        if ([delegate respondsToSelector:@selector(KVFTPDidStartDownload:)]) {
            [delegate KVFTPDidStartDownload:self];
        }
    }
}

-(void)downloadFile:(NSString *)ftpPath downloadTo:(NSString *)localPath progressBlock:(FTPFilesDownloaderProgressBlock) progressBlock completedBlock:(FTPFilesDownloaderCompletedBlock)completedBlock failedBlock:(FTPFilesDownloaderFailedBlock)failedBlock
{
    self.downloadProgressBlock = progressBlock;
    self.downloadCompletedBlock = completedBlock;
    self.downloadFailedBlock = failedBlock;
    [self downloadFile:ftpPath downloadTo:localPath];
}

- (void)_stopDownloadWithStatus:(NSString *)statusString
// Shuts down the connection and displays the result (statusString == nil) 
// or the error status (otherwise).
{
    if (self.d_networkStream != nil) {
        [self.d_networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.d_networkStream.delegate = nil;
        [self.d_networkStream close];
        self.d_networkStream = nil;
    }
    if (self.d_fileStream != nil) {
        [self.d_fileStream close];
        self.d_fileStream = nil;
    }
    
    if ([statusString isEqualToString:@"Stream open error"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFailedWithDownloadStreamError:)]) {
            [delegate KVFTPDidFailedWithDownloadStreamError:self];
        }
        if (self.downloadFailedBlock) {
            self.downloadFailedBlock();
            self.downloadFailedBlock = NULL;
        }
        return;
    }
    
    if ([statusString isEqualToString:@"Cancel"]){
        if ([delegate respondsToSelector:@selector(KVFTPDidCancel:)]) {
            [delegate KVFTPDidCancel:self];
        }
        return;
    }
    self.d_filePath = nil;
    if ([statusString isEqualToString:@"Network read error"]) {
        if (self.downloadFailedBlock) {
            self.downloadFailedBlock();
            self.downloadFailedBlock = NULL;
        }
        return;
    }
    
    if ([statusString isEqualToString:@"File write error"]) {
        if (self.downloadFailedBlock) {
            self.downloadFailedBlock();
            self.downloadFailedBlock = NULL;
        }
        return;
    }
    if ([statusString isEqualToString:@"Download Finished"]) {
        if (self.downloadCompletedBlock) {
            self.downloadCompletedBlock();
            self.downloadCompletedBlock = NULL;
        }
        
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock = NULL;
        }
        if ([delegate respondsToSelector:@selector(KVFTPDidFinishDownload:)]) {
            [delegate KVFTPDidFinishDownload:self];
        }
        return;
    }
}

@synthesize s_networkStream = _s_networkStream;
@synthesize s_listData = _s_listData;
@synthesize s_listEntries = _s_listEntries;
-(BOOL)isSearching
{
    return (self.s_networkStream != nil);
}
- (void)_addListSearchEntries:(NSArray *)newEntries
{
    assert(self.s_listEntries != nil);
    [self.s_listEntries removeAllObjects];
    [self.s_listEntries addObjectsFromArray:newEntries];
    self.s_dataList = [NSMutableArray array];

    for(int i =0 ; i< [self.s_listEntries count]; i++)
    {
        NSString *fileName = [[self.s_listEntries objectAtIndex:i] objectForKey:(id)kCFFTPResourceName];
        NSNumber *fileType = [[self.s_listEntries objectAtIndex:i] objectForKey:(id)kCFFTPResourceType];
        NSRange rangeDot = NSMakeRange(0, 1);
        if ([[fileName substringWithRange:rangeDot]isEqualToString:@"."]) {
            continue;}
        if([fileType intValue] == 4 || [fileType intValue]==10) // is directory
        {
            [allSearchListDirEntries addObject:[NSString stringWithFormat:@"%@%@/",searchPath,fileName]];
        }
        [self.s_dataList addObject:[self.s_listEntries objectAtIndex:i]];
    }

    if ([delegate respondsToSelector:@selector(KVFTPDidSearchUpdated:withPath:)]) {
        [delegate KVFTPDidSearchUpdated:self withPath:searchPath];
    }
    
}
-(void) searchFile:(NSString*) ftpPath searchFor:(NSString*) _searchStr{
    searchString = _searchStr;
    searchPath = ftpPath;

    BOOL                success;
    NSURL  *url;
    CFReadStreamRef     ftpStream;
    assert(self.s_networkStream == nil);      // don't tap receive twice in a row!
    
    // First get and check the URL.
    if(ftpPath != nil)
    {
		url = [self smartURLForString:[[NSString stringWithFormat:@"ftp://%@:%@@%@%@", self.UserName,self.Password,self.FTPAddresIP, ftpPath]stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
    else
    {
        url = [self smartURLForString:[self.FTPAddresIP stringByAppendingString:@""]];
    }
    success = (url != nil);
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
    
    if ( ! success) {
        [self _updateStatus:@"Invalid URL"];
    } else {
        // Create the mutable data into which we will receive the listing.
        self.s_listData = [NSMutableData data];
        assert(self.s_listData != nil);
        // Open a CFFTPStream for the URL.
        
        ftpStream = CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) url);
        assert(ftpStream != NULL);
        
        
        self.s_networkStream = (__bridge NSInputStream *) ftpStream;
        success = [self.s_networkStream setProperty:(__bridge id) kCFBooleanFalse
                                             forKey:(__bridge NSString *) kCFStreamPropertyFTPAttemptPersistentConnection
                   ];
        assert(success);
        self.s_networkStream.delegate = self;
        [self.s_networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.s_networkStream open];
        
        CFRelease(ftpStream);
        // Tell the UI we're receiving.
        if ([delegate respondsToSelector:@selector(KVFTPDidStartSearch:withPath:)]) {
            [delegate KVFTPDidStartSearch:self withPath:searchPath];
        }
    }
}
-(void)_stopSearchWithStatus:(NSString *)statusString
{
    if (self.s_networkStream != nil) {
        [self.s_networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.s_networkStream.delegate = nil;
        [self.s_networkStream close];
        self.s_networkStream = nil;
    }
    
    if ([statusString isEqualToString:@"Stream open error"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFailedWithSearchStreamError:)]) {
            [delegate KVFTPDidFailedWithSearchStreamError:self];
        }
        return;
    }
    
    if ([statusString isEqualToString:@"Cancel"]){
        if ([delegate respondsToSelector:@selector(KVFTPDidCancel:)]) {
            [delegate KVFTPDidCancel:self];
        }
        return;
    }
    
    if ([allSearchListDirEntries count]==currentSearchDirCount) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFinishSearch:)]) {
            [delegate KVFTPDidFinishSearch:self];
        }
        return;
    }
//    NSLog(@"searchFile : %@", [allSearchListDirEntries objectAtIndex:currentSearchDirCount]);
    [self searchFile:[allSearchListDirEntries objectAtIndex:currentSearchDirCount] searchFor:searchString];
    currentSearchDirCount++;
}


@synthesize createFolderNetworkStream = _createFolderNetworkStream;
-(BOOL)isCreating
{
    return (self.createFolderNetworkStream != nil);
}
-(void) createFolder:(NSString*) createFolderPath{
    
    BOOL                success;
    CFURLRef           url;
    CFWriteStreamRef     ftpStream;
    
    assert(self.createFolderNetworkStream == nil);      // don't tap receive twice in a row!
    
    // First get and check the URL.
    //    url = [[Utils sharedUtils] smartURLForString:[FTP_URL stringByAppendingFormat:@"/USBdisk/"]];
    url = (__bridge CFURLRef)[self smartURLForString:self.FTPAddresIP];
    success = (url != nil);
    if (success) {
        // Add the directory name to the end of the URL to form the final URL 
        // that we're going to create.  CFURLCreateCopyAppendingPathComponent will 
        // percent encode (as UTF-8) any wacking characters, which is the right thing 
        // to do in the absence of application-specific knowledge about the encoding 
        // expected by the server.
        
        url =CFURLCreateCopyAppendingPathComponent(NULL,  url, (__bridge CFStringRef) createFolderPath, true);
        self.c_fileName = [createFolderPath lastPathComponent];
        success = (url != nil);
    }
    
    // If the URL is bogus, let the user know.  Otherwise kick off the connection.
	
    if ( ! success) {
        NSLog(@"Invalid URL");
    } else {
		
        // Open a CFFTPStream for the URL.
        ftpStream = CFWriteStreamCreateWithFTPURL(NULL, url);
        assert(ftpStream != NULL);
        self.createFolderNetworkStream = (__bridge NSOutputStream *) ftpStream;
		success = [self.createFolderNetworkStream setProperty:self.UserName forKey:(id)kCFStreamPropertyFTPUserName];
		assert(success);
		success = [self.createFolderNetworkStream setProperty:self.Password forKey:(id)kCFStreamPropertyFTPPassword];
		assert(success);
        success = [self.createFolderNetworkStream setProperty:(__bridge id) kCFBooleanFalse
                                             forKey:(__bridge NSString *) kCFStreamPropertyFTPAttemptPersistentConnection
                   ];
        assert(success);
        
        
        self.createFolderNetworkStream.delegate = self;
        [self.createFolderNetworkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.createFolderNetworkStream open];
        // Have to release ftpStream to balance out the create.  self.networkStream 
        // has retained this for our persistent use.
        CFRelease(ftpStream);
        CFRelease(url);
    }
}

- (void)_stopCreateWithStatus:(NSString *)statusString
// Shuts down the connection and displays the result (statusString == nil) 
// or the error status (otherwise).
{
    if (statusString) {
        NSLog(@"%@",statusString);
    }
    if (self.createFolderNetworkStream != nil) {
        [self.createFolderNetworkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.createFolderNetworkStream.delegate = nil;
        [self.createFolderNetworkStream close];
        self.createFolderNetworkStream = nil;
    }
    
    if ([statusString isEqualToString:@"Create folder Finished"]) {
        if ([delegate respondsToSelector:@selector(KVFTPDidFinishCreateFolder:)]) {
            [delegate KVFTPDidFinishCreateFolder:self];
        }
    }

   
}


#pragma mark ================================ Recevied Data Method
- (NSDictionary *)_entryByReencodingNameInEntry:(NSDictionary *)entry encoding:(NSStringEncoding)newEncoding
// CFFTPCreateParsedResourceListing always interprets the file name as MacRoman, 
// which is clearly bogus <rdar://problem/7420589>.  This code attempts to fix 
// that by converting the Unicode name back to MacRoman (to get the original bytes; 
// this works because there's a lossless round trip between MacRoman and Unicode) 
// and then reconverting those bytes to Unicode using the encoding provided. 
{
    NSDictionary *  result;
    NSString *      name;
    NSData *        nameData;
    NSString *      newName;
    
    newName = nil;
    
    // Try to get the name, convert it back to MacRoman, and then reconvert it 
    // with the preferred encoding.
    
    name = [entry objectForKey:(id) kCFFTPResourceName];
    if (name != nil) {
        assert([name isKindOfClass:[NSString class]]);
        
        nameData = [name dataUsingEncoding:NSMacOSRomanStringEncoding];
        if (nameData != nil) {
            newName = [[NSString alloc] initWithData:nameData encoding:newEncoding];
        }
    }
    
    // If the above failed, just return the entry unmodified.  If it succeeded, 
    // make a copy of the entry and replace the name with the new name that we 
    // calculated.
    if (newName == nil) {
        //        assert(NO);                 // in the debug builds, if this fails, we should investigate why
        result = (NSDictionary *) entry;
    } else {
        NSMutableDictionary *   newEntry;
        
        newEntry = [entry mutableCopy];
        assert(newEntry != nil);
        
        [newEntry setObject:newName forKey:(id) kCFFTPResourceName];
        result = newEntry;
    }
    
    return result;
}

-(void)_parseSearchListData{
    NSMutableArray *    newEntries;
    NSUInteger          offset;
    
    // We accumulate the new entries into an array to avoid a) adding items to the 
    // table one-by-one, and b) repeatedly shuffling the listData buffer around.
    
    newEntries = [NSMutableArray array];
    assert(newEntries != nil);
    
    offset = 0;
    do {
        CFIndex         bytesConsumed;
        CFDictionaryRef thisEntry;
        
        thisEntry = NULL;
        
        assert(offset <= self.s_listData.length);
        bytesConsumed = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *) self.s_listData.bytes)[offset], self.s_listData.length - offset, &thisEntry);
        if (bytesConsumed > 0) {
            
            // It is possible for CFFTPCreateParsedResourceListing to return a 
            // positive number but not create a parse dictionary.  For example, 
            // if the end of the listing text contains stuff that can't be parsed, 
            // CFFTPCreateParsedResourceListing returns a positive number (to tell 
            // the caller that it has consumed the data), but doesn't create a parse 
            // dictionary (because it couldn't make sense of the data).  So, it's 
            // important that we check for NULL.
            
            if (thisEntry != NULL) {
                NSDictionary *  entryToAdd;
                
                // Try to interpret the name as UTF-8, which makes things work properly 
                // with many UNIX-like systems, including the Mac OS X built-in FTP 
                // server.  If you have some idea what type of text your target system 
                // is going to return, you could tweak this encoding.  For example, 
                // if you know that the target system is running Windows, then 
                // NSWindowsCP1252StringEncoding would be a good choice here.
                // 
                // Alternatively you could let the user choose the encoding up 
                // front, or reencode the listing after they've seen it and decided 
                // it's wrong.
                //
                // Ain't FTP a wonderful protocol!
                entryToAdd = [self _entryByReencodingNameInEntry:(__bridge NSDictionary *) thisEntry encoding:NSUTF8StringEncoding];
                [newEntries addObject:entryToAdd];
            }
            
            // We consume the bytes regardless of whether we get an entry.
            
            offset += bytesConsumed;
        }
        
        if (thisEntry != NULL) {
            CFRelease(thisEntry);
        }
        
        if (bytesConsumed == 0) {
            // We haven't yet got enough data to parse an entry.  Wait for more data 
            // to arrive.
            break;
        } else if (bytesConsumed < 0) {
            // We totally failed to parse the listing.  Fail.
            [self _stopSearchWithStatus:@"Listing parse failed"];
            break;
        }
    } while (YES);
    
    if (newEntries.count != 0) {
        [self _addListSearchEntries:newEntries];
    }
    if (offset != 0) {
        [self.s_listData replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
    }
}
- (void)_parseListData
{
    NSMutableArray *    newEntries;
    NSUInteger          offset;
    
    // We accumulate the new entries into an array to avoid a) adding items to the 
    // table one-by-one, and b) repeatedly shuffling the listData buffer around.
    
    newEntries = [NSMutableArray array];
    assert(newEntries != nil);
    
    offset = 0;
    do {
        CFIndex         bytesConsumed;
        CFDictionaryRef thisEntry;
        
        thisEntry = NULL;
        
        assert(offset <= self.r_listData.length);
        bytesConsumed = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *) self.r_listData.bytes)[offset], self.r_listData.length - offset, &thisEntry);
        if (bytesConsumed > 0) {
            
            // It is possible for CFFTPCreateParsedResourceListing to return a 
            // positive number but not create a parse dictionary.  For example, 
            // if the end of the listing text contains stuff that can't be parsed, 
            // CFFTPCreateParsedResourceListing returns a positive number (to tell 
            // the caller that it has consumed the data), but doesn't create a parse 
            // dictionary (because it couldn't make sense of the data).  So, it's 
            // important that we check for NULL.
            
            if (thisEntry != NULL) {
                NSDictionary *  entryToAdd;
                
                // Try to interpret the name as UTF-8, which makes things work properly 
                // with many UNIX-like systems, including the Mac OS X built-in FTP 
                // server.  If you have some idea what type of text your target system 
                // is going to return, you could tweak this encoding.  For example, 
                // if you know that the target system is running Windows, then 
                // NSWindowsCP1252StringEncoding would be a good choice here.
                // 
                // Alternatively you could let the user choose the encoding up 
                // front, or reencode the listing after they've seen it and decided 
                // it's wrong.
                //
                // Ain't FTP a wonderful protocol!
                
                entryToAdd = [self _entryByReencodingNameInEntry:(__bridge NSDictionary *) thisEntry encoding:NSUTF8StringEncoding];
                [newEntries addObject:entryToAdd];
            }
            
            // We consume the bytes regardless of whether we get an entry.
            offset += bytesConsumed;
        }
        
        if (thisEntry != NULL) {
            CFRelease(thisEntry);
        }
        
        if (bytesConsumed == 0) {
            // We haven't yet got enough data to parse an entry.  Wait for more data 
            // to arrive.
            break;
        } else if (bytesConsumed < 0) {
            // We totally failed to parse the listing.  Fail.
            [self _stopReceiveWithStatus:@"Listing parse failed"];
            break;
        }
    } while (YES);
    
    if (newEntries.count != 0) {
        [self _addListEntries:newEntries];
    }
    if (offset != 0) {
        [self.r_listData replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
    }
}
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
#pragma unused(aStream)
    //=====vvv===== networkStream =====vvv=====
    if (aStream == self.r_networkStream) {
        assert(aStream == self.r_networkStream);
        switch (eventCode) {
            case NSStreamEventOpenCompleted: {
                [self _updateStatus:@"Opened connection"];
            } break;
            case NSStreamEventHasBytesAvailable: {
                NSInteger       bytesRead;
                uint8_t         buffer[32768];
                
                //                [self _updateStatus:@"Receiving"];
                // Pull some data off the network.
                
                bytesRead = [self.r_networkStream read:buffer maxLength:sizeof(buffer)];
                if (bytesRead == -1) {
                    [self _stopReceiveWithStatus:@"Network read error"];
                } else if (bytesRead == 0) {
                    [self _stopReceiveWithStatus:@"ReceivedFinished"];
                } else {
                    assert(self.r_listData != nil);
                    // Append the data to our listing buffer.
                    [self.r_listData appendBytes:buffer length:bytesRead];
                    // Check the listing buffer for any complete entries and update 
                    // the UI if we find any.
                    [self _parseListData];
                }
            } break;
            case NSStreamEventHasSpaceAvailable: {
                assert(NO);     // should never happen for the output stream
            } break;
            case NSStreamEventErrorOccurred: {
                [self _stopReceiveWithStatus:@"Stream open error"];
            } break;
            case NSStreamEventEndEncountered: {
                // ignore
            } break;
            default: {
                assert(NO);
            } break;
        }
    }
    //=====^^^===== networkStream =====^^^=====
    if (aStream == self.s_networkStream) {
        assert(aStream == self.s_networkStream);
        switch (eventCode) {
            case NSStreamEventOpenCompleted: {
                [self _updateStatus:@"Opened connection"];
            } break;
            case NSStreamEventHasBytesAvailable: {
                NSInteger       bytesRead;
                uint8_t         buffer[32768];
                
                //                [self _updateStatus:@"Receiving"];
                // Pull some data off the network.
                
                bytesRead = [self.s_networkStream read:buffer maxLength:sizeof(buffer)];
                if (bytesRead == -1) {
                    [self _stopSearchWithStatus:@"Network read error"];
                } else if (bytesRead == 0) {
                    [self _stopSearchWithStatus:nil];
                } else {
                    assert(self.s_listData != nil);
                    // Append the data to our listing buffer.
                    [self.s_listData appendBytes:buffer length:bytesRead];
                    // Check the listing buffer for any complete entries and update 
                    // the UI if we find any.
                    [self _parseSearchListData];
                }
            } break;
            case NSStreamEventHasSpaceAvailable: {
                assert(NO);     // should never happen for the output stream
            } break;
            case NSStreamEventErrorOccurred: {
                [self _stopSearchWithStatus:@"Stream open error"];
            } break;
            case NSStreamEventEndEncountered: {
                // ignore
            } break;
            default: {
                assert(NO);
            } break;
        }
    }
    
    if (aStream == self.createFolderNetworkStream) 
    {
        assert(aStream == self.createFolderNetworkStream);
        switch (eventCode) {
            case NSStreamEventOpenCompleted: {
                [self _updateStatus:@"Opened connection"];
                // Despite what it says in the documentation <rdar://problem/7163693>, 
                // you should wait for the NSStreamEventEndEncountered event to see 
                // if the directory was created successfully.  If you shut the stream 
                // down now, you miss any errors coming back from the server in response 
                // to the MKD command.
                //
                // [self _stopCreateWithStatus:nil];
            } break;
            case NSStreamEventHasBytesAvailable: {
                assert(NO);     // should never happen for the output stream
            } break;
            case NSStreamEventHasSpaceAvailable: {
                assert(NO);
            } break;
            case NSStreamEventErrorOccurred: {
                CFStreamError   err;
                
                // -streamError does not return a useful error domain value, so we 
                // get the old school CFStreamError and check it.
                
                err = CFWriteStreamGetError( (__bridge CFWriteStreamRef) self.createFolderNetworkStream );
                if (err.domain == kCFStreamErrorDomainFTP) {
                    [self _stopCreateWithStatus:[NSString stringWithFormat:@"FTP error %d : '%@' create failed or exists.", (int) err.error, self.c_fileName]];
                } else {
                    [self _stopCreateWithStatus:@"Stream open error"];
                }
            } break;
            case NSStreamEventEndEncountered: {
                [self _stopCreateWithStatus:@"Create folder Finished"];
            } break;
            default: {
                assert(NO);
            } break;
        }
    }
    
    if(aStream == self.d_networkStream)
    {
        switch (eventCode) {
            case NSStreamEventOpenCompleted: {
                [self _updateStatus:@"Opened connection"];
            } break;
            case NSStreamEventHasBytesAvailable: {
                NSInteger       bytesRead;
                uint8_t         buffer[32768];
                //                [self _updateStatus:@"Receiving"];
                
                // Pull some data off the network.
                
                bytesRead = [self.d_networkStream read:buffer maxLength:sizeof(buffer)];
                if (bytesRead == -1) {
                    [self _stopDownloadWithStatus:@"Network read error"];
                } else if (bytesRead == 0) {
                    [self _stopDownloadWithStatus:@"Download Finished"];
                } else {
                    if ([delegate respondsToSelector:@selector(KVFTPDidReveivedByte:receivedDateByte:)]) {
                        [delegate KVFTPDidReveivedByte:self receivedDateByte:bytesRead];
                    }
                    if (self.downloadProgressBlock) {
                        self.downloadProgressBlock(bytesRead);
                    }
//                    NSLog(@"byteRead - %d  - %d/%d - %@", bytesRead, currentLength ,expectedLength,downloadLabel.text);
                    NSInteger   bytesWritten;
                    NSInteger   bytesWrittenSoFar;
                    // Write to the file.
                    bytesWrittenSoFar = 0;
                    do {
                        bytesWritten = [self.d_fileStream write:&buffer[bytesWrittenSoFar] maxLength:bytesRead - bytesWrittenSoFar];
                        assert(bytesWritten != 0);
                        if (bytesWritten == -1) {
                            [self _stopDownloadWithStatus:@"File write error"];
                            break;
                        } else {
                            bytesWrittenSoFar += bytesWritten;
                        }
                    } while (bytesWrittenSoFar != bytesRead);
                }
            } break;
            case NSStreamEventHasSpaceAvailable: {
                assert(NO);     // should never happen for the output stream
            } break;
            case NSStreamEventErrorOccurred: {
                [self _stopDownloadWithStatus:@"Stream open error"];
            } break;
            case NSStreamEventEndEncountered: {
                NSLog(@"NSStreamEventEndEncountered");
                // ignore
            } break;
            default: {
                assert(NO);
            } break;
        }
        
    }
    
    if (aStream == self.u_networkStream) {
        assert(aStream == self.u_networkStream);
        
        switch (eventCode) {
            case NSStreamEventOpenCompleted: {
                [self _updateStatus:@"Opened connection"];
                //                NSLog(@"Opened connection");
            } break;
            case NSStreamEventHasBytesAvailable: {
                assert(NO);     // should never happen for the output stream
            } break;
            case NSStreamEventHasSpaceAvailable: {
                //                [self _updateStatus:@"Sending"];
                // If we don't have any data buffered, go read the next chunk of data.
                
                if (self.bufferOffset == self.bufferLimit) {
                    NSInteger   bytesRead;
                    bytesRead = [self.u_fileStream read:self.buffer maxLength:32768];
                    if ([delegate respondsToSelector:@selector(KVFTPDidSendByte:sendDataByte:)]) {
                        [delegate KVFTPDidSendByte:self sendDataByte:bytesRead];
                    }
                    if (self.uploadProgressBlock) {
                        self.uploadProgressBlock(bytesRead);
                    }
                    if (bytesRead == -1) {
                        [self _stopUploadWithStatus:@"File read error"];
                    } else if (bytesRead == 0) {
                        [self _stopUploadWithStatus:@"Upload Finished"];
                    } else {
                        self.bufferOffset = 0;
                        self.bufferLimit  = bytesRead;
                    }
                }
                
                // If we're not out of data completely, send the next chunk.
                if (self.bufferOffset != self.bufferLimit) {
                    NSInteger   bytesWritten;
                    bytesWritten = [self.u_networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                    assert(bytesWritten != 0);
                    if (bytesWritten == -1) {
                        NSLog(@"Network write error");
                        [self _stopUploadWithStatus:@"Network write error"];
                    } else {
                        self.bufferOffset += bytesWritten;
                    }
                }
            } break;
            case NSStreamEventErrorOccurred: {
                NSLog(@"Stream open error");
                [self _stopUploadWithStatus:@"StreamOpenError"];
            } break;
            case NSStreamEventEndEncountered: {
                // ignore
            } break;
            default: {
                assert(NO);
            } break;
        }
    }
}
@end
