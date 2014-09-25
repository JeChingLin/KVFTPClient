//
//  FTPClient.h
//  WPDforTab
//
//  Created by Kevin Lin on 12/7/17.
//  Copyright (c) 2012年 GIgastone Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

#define USERNAME  @"root"
#define PASSWORD  @"root"

enum {
    kSendBufferSizeOfFTPClient = 32768
};

@protocol KVFTPClientDelegate;
@interface FTPClient : NSObject <NSStreamDelegate>
{
    /** Search Recevice List NetworkStream **/
    NSInputStream *             _s_networkStream;
    NSMutableData *             _s_listData;
    NSMutableArray *            _s_listEntries;           // of NSDictionary as returned by CFFTPCreateParsedResourceListing

    NSInputStream *             _r_networkStream;
    NSMutableData *             _r_listData;
    NSMutableArray *            _r_listEntries;           // of NSDictionary as returned by CFFTPCreateParsedResourceListing
    
    /** Download file NetworkStream **/
    NSInputStream *             _d_networkStream;
    NSString *                  _d_filePath;
    NSOutputStream *            _d_fileStream;
    
    NSOutputStream *            _u_networkStream;
    NSInputStream *             _u_fileStream;
    uint8_t                     _buffer[kSendBufferSizeOfFTPClient];
    size_t                      _bufferOffset;
    size_t                      _bufferLimit;
    
    NSMutableArray *allSearchListDirEntries;
    NSString *searchString;
    NSString *searchPath;
    int currentSearchDirCount;

}
@property(nonatomic,weak) id<KVFTPClientDelegate> delegate;
@property(nonatomic, strong) NSMutableArray *r_dataList;
@property(nonatomic, strong) NSMutableArray *s_dataList;

@property(nonatomic, strong) NSString *FTPAddresIP;
@property(nonatomic, strong) NSString *UserName;
@property(nonatomic, strong) NSString *Password;

@property (nonatomic, assign, readonly) BOOL isCreating;
@property (nonatomic, assign, readonly) BOOL isReceiving;
@property (nonatomic, assign, readonly) BOOL isSearching;
@property (nonatomic, assign, readonly) BOOL isUploading;
@property (nonatomic, assign, readonly) BOOL isDownloading;

+(FTPClient*) currentFTP;
+(BOOL) deleteFileDirectlyWithAddress:(NSString*)address user:(NSString*)user password:(NSString*)password path:(NSString *)ftpPath;

-(id)initWithHostAddress:(NSString *)address UserName:(NSString*)username Password:(NSString*)password;
-(void) receiveDirectoryList:(NSString*) ftpPath;
-(void) uploadFile:(NSString*) localPath uploadTo:(NSString*)ftpPath;
-(void) downloadFile:(NSString*) ftpPath downloadTo:(NSString*) localPath;
-(void) searchFile:(NSString*) ftpPath searchFor:(NSString*) searchStr;
-(void) createFolder:(NSString*) createFolderPath;
-(BOOL) deleteFile:(NSString*) ftpPath;
-(void) initSearch;

typedef void(^FTPDirectoryListReceivedBlock)(NSArray *receivedArray);
@property (copy, nonatomic) FTPDirectoryListReceivedBlock receivedBlock;
-(void)receiveDirectoryList:(NSString *)ftpPath receivedBlock:(FTPDirectoryListReceivedBlock) receivedBlock;

typedef void(^FTPFilesDownloaderProgressBlock)(NSInteger receivedSize);
typedef void(^FTPFilesDownloaderCompletedBlock)();
typedef void(^FTPFilesDownloaderFailedBlock)();
@property (copy, nonatomic) FTPFilesDownloaderProgressBlock downloadProgressBlock;
@property (copy, nonatomic) FTPFilesDownloaderCompletedBlock downloadCompletedBlock;
@property (copy, nonatomic) FTPFilesDownloaderFailedBlock downloadFailedBlock;
-(void)downloadFile:(NSString *)ftpPath downloadTo:(NSString *)localPath progressBlock:(FTPFilesDownloaderProgressBlock) progressBlock completedBlock:(FTPFilesDownloaderCompletedBlock)completedBlock failedBlock:(FTPFilesDownloaderFailedBlock)failedBlock;


typedef void(^FTPFileUploaderProgressBlock)(NSInteger sendSize);
typedef void(^FTPFilesUploaderCompletedBlock)();
typedef void(^FTPFilesUploaderFailedBlock)();
@property (copy, nonatomic) FTPFileUploaderProgressBlock uploadProgressBlock;
@property (copy, nonatomic) FTPFilesUploaderCompletedBlock uploadCompletedBlock;
@property (copy, nonatomic) FTPFilesUploaderFailedBlock uploadFailedBlock;
-(void)uploadFile:(NSString *)localPath uploadTo:(NSString *)ftpPath progressBlock:(FTPFileUploaderProgressBlock) progressBlock completedBlock:(FTPFilesUploaderCompletedBlock)completedBlock failedBlock:(FTPFilesUploaderFailedBlock)failedBlock;

@end

@protocol KVFTPClientDelegate <NSObject>


//FTP Delegate when stream start
@optional
-(void) KVFTPDidStartReceived:(FTPClient*) ftp;
-(void) KVFTPDidStartDownload:(FTPClient*) ftp;
-(void) KVFTPDidStartUpload:(FTPClient*) ftp;
-(void) KVFTPDidStartSearch:(FTPClient*) ftp withPath:(NSString *)path;

//FTP delegate when stream finished
-(void) KVFTPDidFinishReceived: (FTPClient*) ftp;
-(void) KVFTPDidFinishDownload:(FTPClient*) ftp;
-(void) KVFTPDidFinishUpload:(FTPClient*) ftp;
-(void) KVFTPDidFinishSearch:(FTPClient*) ftp;

//FTP delegate when stream error
-(void) KVFTPDidFailedWithReceivedStreamError:(FTPClient*) ftp;
-(void) KVFTPDidFailedWithDownloadStreamError:(FTPClient*) ftp;
-(void) KVFTPDidFailedWithUploadStreamError:(FTPClient*) ftp;
-(void) KVFTPDidFailedWithSearchStreamError:(FTPClient*) ftp;

//FTP delegate when search update
-(void)KVFTPDidSearchUpdated:(FTPClient*) ftp withPath:(NSString*) path;

//FTP delegate byte received info
-(void) KVFTPDidReveivedByte:(FTPClient*) ftp receivedDateByte:(NSInteger) byte;
-(void) KVFTPDidSendByte:(FTPClient*)ftp sendDataByte:(NSInteger) byte;

//FTP delegate cancel
-(void) KVFTPDidCancel:(FTPClient*) ftp;

//FTP delegate CreateFolderFinished
-(void) KVFTPDidFinishCreateFolder:(FTPClient*)ftp;

@end
