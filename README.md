# STFTPNetwork

[![Version](https://img.shields.io/cocoapods/v/STFTPNetwork.svg?style=flat)](http://cocoapods.org/pods/STFTPNetwork)
[![License](https://img.shields.io/cocoapods/l/STFTPNetwork.svg?style=flat)](http://cocoapods.org/pods/STFTPNetwork)
[![Platform](https://img.shields.io/cocoapods/p/STFTPNetwork.svg?style=flat)](http://cocoapods.org/pods/STFTPNetwork)

## A simple FTP network library for iOS.
STFTPNetwork is an FTP network library for iOS.You can use it to connect to the FTP server, manage your files, including query, create, delete, download, upload and other operations.

![STFTPNetworkPreview01](https://github.com/shien7654321/STFTPNetwork/raw/master/Preview/STFTPNetworkPreview01.gif)

## Requirements

- iOS 8.0 or later (For iOS 8.0 before, maybe it can work, but I have not tested.)
- ARC

## Installation

STFTPNetwork is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'STFTPNetwork'
```

## Usage

### Import headers in your source files

In the source files where you need to use the library, import the header file:

```objective-c
#import <STFTPNetwork/STFTPNetwork.h>
```

### Connect to FTP Server

Use the following function to connect to FTP server:

```objective-c
[STFTPNetwork connect:@"ftp://xxxx:xxxx" username:@"xxxx" password:@"xxxx" handler:^(BOOL success) {
    NSLog(@"Connect FTP server success");
}];
```

### Query files

Use the following function to query files:

```objective-c
[STFTPNetwork query:@"ftp://xxxx:xxxx/xxxx" successHandler:^(NSArray *results) {
    NSLog(@"Query files success: %@", results);
} failHandler:^(STFTPErrorCode errorCode) {
    NSLog(@"Query files failed: %ld", (long)errorCode);
}];
```

### New folder

Use the fillowing function to new folder:

```objective-c
[STFTPNetwork create:@"ftp://xxxx:xxxx/xxxx" successHandler:^{
    NSLog(@"New folder success");
} failHandler:^(STFTPErrorCode errorCode) {
    NSLog(@"New folder failed: %ld", (long)errorCode);
}];
```

### Delete file or folder

Use the following function to delete file or folder:

```objective-c
[STFTPNetwork remove:@"ftp://xxxx:xxxx/xxxx" successHandler:^{
    NSLog(@"Delete file success");
} failHandler:^(STFTPErrorCode errorCode) {
    NSLog(@"Delete file failed: %ld", (long)errorCode);
}];
```

### Download file

Use the following function to download file:

```objective-c
[STFTPNetwork download:@"ftp://xxxx:xxxx/xxxx" progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
    NSLog(@"Download progress: %.2f%%", bytesTotal > 0 ? bytesCompleted * 100.0 / bytesTotal : 0);
} successHandler:^(NSData *data) {
    NSLog(@"Download file success: %@", data);
} failHandler:^(STFTPErrorCode errorCode) {
    NSLog(@"Download file failed: %ld", (long)errorCode);
}];
```

### Upload file

Use the following function to upload file:

```objective-c
[STFTPNetwork upload:localFilePath urlString:@"ftp://xxxx:xxxx/xxxx" progressHandler:^(unsigned long long bytesCompleted, unsigned long long bytesTotal) {
    NSLog(@"Upload progress: %.2f%%", bytesTotal > 0 ? bytesCompleted * 100.0 / bytesTotal : 0);
} successHandler:^{
    NSLog(@"Upload file success");
} failHandler:^(STFTPErrorCode errorCode) {
    NSLog(@"Upload file failed: %ld", (long)errorCode);
}];
```

### Disconnect FTP server

Use the following function to disconnect FTP server:

```objective-c
[STFTPNetwork disconnect];
```

## Author

Suta, shien7654321@163.com

## License

[MIT]: http://www.opensource.org/licenses/mit-license.php
[MIT license][MIT].
