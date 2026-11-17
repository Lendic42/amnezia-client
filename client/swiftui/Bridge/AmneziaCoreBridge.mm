#import "AmneziaCoreBridge.h"

#include "ui/controllers/connectionUiController.h"
#include "ui/controllers/serversUiController.h"
#include "ui/controllers/importUiController.h"

#include <QString>

static NSString *NSStringFromQString(const QString &value)
{
    return [NSString stringWithUTF8String:value.toUtf8().constData()];
}

static QString QStringFromNSString(NSString *value)
{
    return QString::fromUtf8([value UTF8String]);
}

@interface AmneziaCoreBridge ()
{
    ConnectionUiController *_connectionController;
    ServersUiController *_serversController;
    ImportUiController *_importController;
    void (^_connectionStateChangedHandler)(void);
    void (^_connectionErrorHandler)(NSInteger);
    void (^_noInstalledContainersHandler)(void);
}
@end

@implementation AmneziaCoreBridge

- (instancetype)initWithConnectionController:(void *)connectionController
                          serversController:(void *)serversController
                           importController:(void *)importController
{
    self = [super init];
    if (self) {
        _connectionController = static_cast<ConnectionUiController *>(connectionController);
        _serversController = static_cast<ServersUiController *>(serversController);
        _importController = static_cast<ImportUiController *>(importController);
        QObject::connect(_connectionController, &ConnectionUiController::connectionStateChanged, [self]() {
            if (self->_connectionStateChangedHandler) {
                self->_connectionStateChangedHandler();
            }
        });
        QObject::connect(_connectionController, &ConnectionUiController::connectionErrorOccurred, [self](ErrorCode errorCode) {
            if (self->_connectionErrorHandler) {
                self->_connectionErrorHandler(static_cast<NSInteger>(errorCode));
            }
        });
        QObject::connect(_connectionController, &ConnectionUiController::noInstalledContainers, [self]() {
            if (self->_noInstalledContainersHandler) {
                self->_noInstalledContainersHandler();
            }
        });
    }
    return self;
}

- (BOOL)isConnected
{
    return _connectionController->isConnected();
}

- (BOOL)isConnectionInProgress
{
    return _connectionController->isConnectionInProgress();
}

- (NSString *)connectionStateText
{
    return NSStringFromQString(_connectionController->connectionStateText());
}

- (void)toggleConnection
{
    _connectionController->toggleConnection();
}

- (void)openConnection
{
    _connectionController->openConnection();
}

- (void)closeConnection
{
    _connectionController->closeConnection();
}

- (NSInteger)getLastConnectionError
{
    return static_cast<NSInteger>(_connectionController->getLastConnectionError());
}

- (NSString *)defaultServerId
{
    return NSStringFromQString(_serversController->getDefaultServerId());
}

- (NSString *)defaultServerName
{
    return NSStringFromQString(_serversController->getDefaultServerName());
}

- (NSString *)defaultServerDefaultContainerName
{
    return NSStringFromQString(_serversController->getDefaultServerDefaultContainerName());
}

- (NSString *)defaultServerDescriptionCollapsed
{
    return NSStringFromQString(_serversController->getDefaultServerDescriptionCollapsed());
}

- (NSString *)defaultServerDescriptionExpanded
{
    return NSStringFromQString(_serversController->getDefaultServerDescriptionExpanded());
}

- (BOOL)isDefaultServerFromApi
{
    return _serversController->isDefaultServerFromApi();
}

- (BOOL)defaultServerHasOutdatedAwgContainer
{
    return _serversController->defaultServerHasOutdatedAwgContainer();
}

- (BOOL)isDefaultServerDefaultContainerHasSplitTunneling
{
    return _serversController->isDefaultServerDefaultContainerHasSplitTunneling();
}

- (NSString *)serverName:(NSString *)serverId
{
    return NSStringFromQString(_serversController->serverName(QStringFromNSString(serverId)));
}

- (NSString *)serverHostName:(NSString *)serverId
{
    return NSStringFromQString(_serversController->serverHostName(QStringFromNSString(serverId)));
}

- (BOOL)isServerFromApi:(NSString *)serverId
{
    return _serversController->isServerFromApi(QStringFromNSString(serverId));
}

- (BOOL)isServerHasWriteAccess:(NSString *)serverId
{
    return _serversController->isServerHasWriteAccess(QStringFromNSString(serverId));
}

- (BOOL)serverHasOutdatedAwgContainer:(NSString *)serverId
{
    return _serversController->serverHasOutdatedAwgContainer(QStringFromNSString(serverId));
}

- (void)setDefaultServer:(NSString *)serverId
{
    _serversController->setDefaultServer(QStringFromNSString(serverId));
}

- (void)setDefaultContainer:(NSString *)serverId containerIndex:(NSInteger)containerIndex
{
    _serversController->setDefaultContainer(QStringFromNSString(serverId), static_cast<int>(containerIndex));
}

- (void)removeServer:(NSString *)serverId
{
    _serversController->removeServer(QStringFromNSString(serverId));
}

- (void)editServerName:(NSString *)serverId name:(NSString *)name
{
    _serversController->editServerName(QStringFromNSString(serverId), QStringFromNSString(name));
}

- (void)toggleAmneziaDns:(BOOL)enabled
{
    _serversController->toggleAmneziaDns(enabled);
}

- (BOOL)extractConfigFromData:(NSString *)data
{
    return _importController->extractConfigFromData(QStringFromNSString(data));
}

- (NSString *)importedConfig
{
    return NSStringFromQString(_importController->getConfig());
}

- (NSString *)importedConfigFileName
{
    return NSStringFromQString(_importController->getConfigFileName());
}

- (NSString *)maliciousWarningText
{
    return NSStringFromQString(_importController->getMaliciousWarningText());
}

- (BOOL)isNativeWireGuardConfig
{
    return _importController->isNativeWireGuardConfig();
}

- (void)processNativeWireGuardConfig
{
    _importController->processNativeWireGuardConfig();
}

- (void)importConfig
{
    _importController->importConfig();
}

- (BOOL)parseQrCodeChunk:(NSString *)code
{
    return _importController->parseQrCodeChunk(QStringFromNSString(code));
}

- (double)qrCodeScanProgressBarValue
{
    return _importController->getQrCodeScanProgressBarValue();
}

- (NSString *)qrCodeScanProgressString
{
    return NSStringFromQString(_importController->getQrCodeScanProgressString());
}

- (void)setConnectionStateChangedHandler:(void (^)(void))handler
{
    _connectionStateChangedHandler = [handler copy];
}

- (void)setConnectionErrorHandler:(void (^)(NSInteger))handler
{
    _connectionErrorHandler = [handler copy];
}

- (void)setNoInstalledContainersHandler:(void (^)(void))handler
{
    _noInstalledContainersHandler = [handler copy];
}

@end
