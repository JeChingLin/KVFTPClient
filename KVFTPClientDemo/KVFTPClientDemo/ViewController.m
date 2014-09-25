//
//  ViewController.m
//  KVFTPClientDemo
//
//  Created by Gigastone iMac on 2014/9/25.
//  Copyright (c) 2014年 Gigastone Corporation. All rights reserved.
//

#import "ViewController.h"
#import "KVFTPClient.h"

#define SANDBOX [(NSArray*)NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0]

#define HostAddress @"192.168.1.2"
#define USERNAME @"root"
#define PASSWORD @"root"

@interface ViewController ()<KVFTPClientDelegate,UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, weak) IBOutlet UIButton *delegateReceivedBtn;
@property(nonatomic, weak) IBOutlet UIButton *delegateDownloadBtn;
@property(nonatomic, weak) IBOutlet UIButton *delegateUploadBtn;
@property(nonatomic, weak) IBOutlet UIButton *blockReceivedBtn;
@property(nonatomic, weak) IBOutlet UIButton *blockDownloadBtn;
@property(nonatomic, weak) IBOutlet UIButton *blockUploadBtn;
@property(nonatomic, strong) IBOutlet UITableView *tableView;
@property(nonatomic, strong) NSArray *receivedList;
-(IBAction)delegateReceivedAction:(id)sender;
-(IBAction)delegateDownloadAction:(id)sender;
-(IBAction)delegateUploadAction:(id)sender;
-(IBAction)blockReceivedAction:(id)sender;
-(IBAction)blockDownloadAction:(id)sender;
-(IBAction)blockUploadAction:(id)sender;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)delegateReceivedAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = self;
    [ftp receiveDirectoryList:@"/"];
}
-(IBAction)delegateDownloadAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = self;
    [ftp downloadFile:@"/ftp/SDdisk/123.mp3" downloadTo:[SANDBOX stringByAppendingPathComponent:@"123.mp3"]];
}
-(IBAction)delegateUploadAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = self;
    [ftp uploadFile:[SANDBOX stringByAppendingPathComponent:@"123.mp3"] uploadTo:@"/ftp/SDdisk"];
}
-(IBAction)blockReceivedAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = nil;
    [ftp receiveDirectoryList:@"/" receivedBlock:^(NSArray *receivedList){
        NSLog(@"receivedList : %@", receivedList);
        self.receivedList = receivedList;
        [self.tableView reloadData];
    }];
}
-(IBAction)blockDownloadAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = nil;
    [ftp downloadFile:@"/ftp/SDdisk/123.mp3" downloadTo:[SANDBOX stringByAppendingPathComponent:@"123.mp3"] progressBlock:^(NSInteger receivedSize){
        NSLog(@"block : %ld", (long)receivedSize);
    } completedBlock:^(void){
        NSLog(@"download complete.");
    } failedBlock:^(void){
        NSLog(@"download failed.");
    }];
}

-(IBAction)blockUploadAction:(id)sender
{
    FTPClient *ftp = [[FTPClient currentFTP]initWithHostAddress:HostAddress UserName:USERNAME Password:PASSWORD];
    ftp.delegate = nil;
    [ftp uploadFile:[SANDBOX stringByAppendingPathComponent:@"123.mp3"] uploadTo:@"/ftp/SDdisk" progressBlock:^(NSInteger sendSize){
        NSLog(@"send size : %ld", (long)sendSize);
    } completedBlock:^(void){
        NSLog(@"upload complete.");
    } failedBlock:^(void){
        NSLog(@"upload failed");
    }];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.receivedList count];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    
    cell.textLabel.text = [[self.receivedList objectAtIndex:indexPath.row] objectForKey:(id)kCFFTPResourceName];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [[self.receivedList objectAtIndex:indexPath.row]objectForKey:(id)kCFFTPResourceSize]];
    return cell;
}

#pragma mark KVFTPClientDelegate Received
-(void)KVFTPDidStartReceived:(FTPClient *)ftp{
}

-(void)KVFTPDidFinishReceived:(FTPClient *)ftp{
    NSLog(@"%@", ftp.r_dataList);
    self.receivedList = ftp.r_dataList;
    
    [self.tableView reloadData];
}


#pragma mark KVFTPClientDelegate Download
-(void)KVFTPDidStartDownload:(FTPClient *)ftp
{
    NSLog(@"%s", __FUNCTION__);
}

-(void)KVFTPDidReveivedByte:(FTPClient *)ftp receivedDateByte:(NSInteger)byte
{
    NSLog(@"download bytes : %ld", (long)byte);
}

-(void)KVFTPDidFinishDownload:(FTPClient *)ftp
{
    NSLog(@"%s", __FUNCTION__);
}


#pragma mark KVFTPClientDelegate Upload
-(void)KVFTPDidStartUpload:(FTPClient *)ftp
{
    NSLog(@"%s", __FUNCTION__);
}

-(void)KVFTPDidSendByte:(FTPClient *)ftp sendDataByte:(NSInteger)byte
{
    NSLog(@"upload bytes : %ld", (long)byte);
}

-(void)KVFTPDidFinishUpload:(FTPClient *)ftp
{
    NSLog(@"%s", __FUNCTION__);
}


@end
