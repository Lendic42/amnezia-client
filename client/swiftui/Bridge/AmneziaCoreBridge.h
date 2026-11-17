#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AmneziaCoreBridge : NSObject

- (instancetype)initWithConnectionController:(void *)connectionController
                          serversController:(void *)serversController
                           importController:(void *)importController NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isConnected;
- (BOOL)isConnectionInProgress;
- (NSString *)connectionStateText;
- (void)toggleConnection;
- (void)openConnection;
- (void)closeConnection;
- (NSInteger)getLastConnectionError;

- (NSString *)defaultServerId;
- (NSString *)defaultServerName;
- (NSString *)defaultServerDefaultContainerName;
- (NSString *)defaultServerDescriptionCollapsed;
- (NSString *)defaultServerDescriptionExpanded;
- (BOOL)isDefaultServerFromApi;
- (BOOL)defaultServerHasOutdatedAwgContainer;
- (BOOL)isDefaultServerDefaultContainerHasSplitTunneling;
- (NSString *)serverName:(NSString *)serverId;
- (NSString *)serverHostName:(NSString *)serverId;
- (BOOL)isServerFromApi:(NSString *)serverId;
- (BOOL)isServerHasWriteAccess:(NSString *)serverId;
- (BOOL)serverHasOutdatedAwgContainer:(NSString *)serverId;
- (void)setDefaultServer:(NSString *)serverId;
- (void)setDefaultContainer:(NSString *)serverId containerIndex:(NSInteger)containerIndex;
- (void)removeServer:(NSString *)serverId;
- (void)editServerName:(NSString *)serverId name:(NSString *)name;
- (void)toggleAmneziaDns:(BOOL)enabled;

- (BOOL)extractConfigFromData:(NSString *)data;
- (NSString *)importedConfig;
- (NSString *)importedConfigFileName;
- (NSString *)maliciousWarningText;
- (BOOL)isNativeWireGuardConfig;
- (void)processNativeWireGuardConfig;
- (void)importConfig;
- (BOOL)parseQrCodeChunk:(NSString *)code;
- (double)qrCodeScanProgressBarValue;
- (NSString *)qrCodeScanProgressString;

- (void)setConnectionStateChangedHandler:(void (^)(void))handler;
- (void)setConnectionErrorHandler:(void (^)(NSInteger errorCode))handler;
- (void)setNoInstalledContainersHandler:(void (^)(void))handler;

@end

NS_ASSUME_NONNULL_END
