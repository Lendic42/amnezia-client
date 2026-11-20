#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AmneziaCoreBridge : NSObject

- (instancetype)initWithCoreController:(void *)coreController NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isConnected;
- (BOOL)isConnectionInProgress;
- (NSString *)connectionStateText;
- (void)toggleConnection;
- (void)openConnection;
- (void)closeConnection;
- (NSInteger)getLastConnectionError;
- (NSString *)errorMessageForCode:(NSInteger)errorCode;

- (NSInteger)getServersCount;
- (NSString *)serverIdAtIndex:(NSInteger)index;
- (NSString *)serverJson:(NSString *)serverId;

- (NSString *)defaultServerId;
- (NSString *)defaultServerName;
- (NSString *)defaultServerDefaultContainerName;
- (NSString *)defaultServerDescriptionCollapsed;
- (NSString *)defaultServerDescriptionExpanded;
- (BOOL)isDefaultServerFromApi;
- (BOOL)defaultServerHasOutdatedAwgContainer;
- (BOOL)isDefaultServerDefaultContainerHasSplitTunneling;
- (NSString *)serverName:(NSString *)serverId;
- (NSString *)nextAvailableServerName;
- (NSString *)serverHostName:(NSString *)serverId;
- (BOOL)isServerFromApi:(NSString *)serverId;
- (BOOL)isServerHasWriteAccess:(NSString *)serverId;
- (BOOL)serverHasOutdatedAwgContainer:(NSString *)serverId;
- (BOOL)isServerSubscriptionExpired:(NSString *)serverId;
- (BOOL)isServerSubscriptionExpiringSoon:(NSString *)serverId;
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
- (void)startDecodingQr;
- (BOOL)parseQrCodeChunk:(NSString *)code;
- (double)qrCodeScanProgressBarValue;
- (NSString *)qrCodeScanProgressString;

- (NSInteger)validateAndUpdateConfig:(NSString *)serverId;

- (NSString *)connectionConfig:(NSString *)serverId containerIndex:(NSInteger)containerIndex clientName:(NSString *)clientName;
- (NSString *)wireGuardConfig:(NSString *)serverId clientName:(NSString *)clientName;
- (NSString *)awgConfig:(NSString *)serverId containerIndex:(NSInteger)containerIndex clientName:(NSString *)clientName;
- (NSString *)openVpnConfig:(NSString *)serverId clientName:(NSString *)clientName;
- (NSString *)xrayConfig:(NSString *)serverId clientName:(NSString *)clientName;
- (NSString *)fullAccessConfig:(NSString *)serverId;
- (NSString *)prepareVpnKeyExport:(NSString *)serverId;
- (NSArray<NSString *> *)vpnKeyQrCodes;
- (NSArray<NSString *> *)exportQrCodes;
- (NSInteger)getLastExportError;

- (void)setConnectionStateChangedHandler:(void (^)(void))handler;
- (void)setConnectionErrorHandler:(void (^)(NSInteger errorCode))handler;
- (void)setNoInstalledContainersHandler:(void (^)(void))handler;
- (void)setImportFinishedHandler:(void (^)(void))handler;
- (void)setImportErrorHandler:(void (^)(NSInteger errorCode, BOOL goToPageHome))handler;
- (void)setQrDecodingFinishedHandler:(void (^)(void))handler;
- (void)setExportErrorHandler:(void (^)(NSInteger errorCode))handler;

@end

NS_ASSUME_NONNULL_END
