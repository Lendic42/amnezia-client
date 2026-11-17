#import "AmneziaCoreBridge.h"

#include "core/controllers/coreController.h"
#include "core/controllers/api/subscriptionController.h"
#include "core/repositories/secureServersRepository.h"
#include "core/utils/errorCodes.h"
#include "core/utils/errorStrings.h"
#include "ui/controllers/api/subscriptionUiController.h"
#include "ui/controllers/connectionUiController.h"
#include "ui/controllers/importUiController.h"
#include "ui/controllers/selfhosted/exportUiController.h"
#include "ui/controllers/serversUiController.h"

#include <QJsonDocument>
#include <QJsonObject>
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
    SubscriptionUiController *_subscriptionController;
    ExportUiController *_exportController;
    SubscriptionController *_subscriptionCoreController;
    SecureServersRepository *_serversRepository;
    NSInteger _lastExportError;
    void (^_connectionStateChangedHandler)(void);
    void (^_connectionErrorHandler)(NSInteger);
    void (^_noInstalledContainersHandler)(void);
    void (^_importFinishedHandler)(void);
    void (^_importErrorHandler)(NSInteger, BOOL);
    void (^_qrDecodingFinishedHandler)(void);
    void (^_exportErrorHandler)(NSInteger);
}
@end

@implementation AmneziaCoreBridge

- (instancetype)initWithCoreController:(void *)coreController
{
    self = [super init];
    if (self) {
        CoreController *controller = static_cast<CoreController *>(coreController);
        _connectionController = controller->connectionUiController();
        _serversController = controller->serversUiController();
        _importController = controller->importUiController();
        _subscriptionController = controller->subscriptionUiController();
        _exportController = controller->exportUiController();
        _subscriptionCoreController = controller->subscriptionController();
        _serversRepository = controller->serversRepository();
        _lastExportError = 0;
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
        QObject::connect(_importController, &ImportUiController::importFinished, [self]() {
            if (self->_importFinishedHandler) {
                self->_importFinishedHandler();
            }
        });
        QObject::connect(_importController, &ImportUiController::importErrorOccurred, [self](ErrorCode errorCode, bool goToPageHome) {
            if (self->_importErrorHandler) {
                self->_importErrorHandler(static_cast<NSInteger>(errorCode), goToPageHome);
            }
        });
        QObject::connect(_importController, &ImportUiController::qrDecodingFinished, [self]() {
            if (self->_qrDecodingFinishedHandler) {
                self->_qrDecodingFinishedHandler();
            }
        });
        QObject::connect(_exportController, qOverload<ErrorCode>(&ExportUiController::exportErrorOccurred), [self](ErrorCode errorCode) {
            self->_lastExportError = static_cast<NSInteger>(errorCode);
            if (self->_exportErrorHandler) {
                self->_exportErrorHandler(static_cast<NSInteger>(errorCode));
            }
        });
        QObject::connect(_subscriptionController, &SubscriptionUiController::errorOccurred, [self](ErrorCode errorCode) {
            self->_lastExportError = static_cast<NSInteger>(errorCode);
            if (self->_exportErrorHandler) {
                self->_exportErrorHandler(static_cast<NSInteger>(errorCode));
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

- (NSString *)errorMessageForCode:(NSInteger)errorCode
{
    return NSStringFromQString(errorString(static_cast<ErrorCode>(errorCode)));
}

- (NSInteger)getServersCount
{
    return _serversController->getServersCount();
}

- (NSString *)serverIdAtIndex:(NSInteger)index
{
    return NSStringFromQString(_serversController->getServerId(static_cast<int>(index)));
}

- (NSString *)serverJson:(NSString *)serverId
{
    std::optional<QJsonObject> json = _serversRepository->serverJsonById(QStringFromNSString(serverId));
    if (!json.has_value()) {
        return @"";
    }
    return [NSString stringWithUTF8String:QJsonDocument(json.value()).toJson(QJsonDocument::Compact).constData()];
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

- (BOOL)isServerSubscriptionExpired:(NSString *)serverId
{
    return _serversController->isServerSubscriptionExpired(QStringFromNSString(serverId));
}

- (BOOL)isServerSubscriptionExpiringSoon:(NSString *)serverId
{
    return _serversController->isServerSubscriptionExpiringSoon(QStringFromNSString(serverId));
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

- (void)startDecodingQr
{
    _importController->startDecodingQr();
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

- (NSInteger)validateAndUpdateConfig:(NSString *)serverId
{
    QString id = QStringFromNSString(serverId);
    bool hasInstalledContainers = _serversController->serverHasInstalledContainers(id);
    return static_cast<NSInteger>(_subscriptionCoreController->validateAndUpdateConfig(id, hasInstalledContainers));
}

- (NSString *)connectionConfig:(NSString *)serverId containerIndex:(NSInteger)containerIndex clientName:(NSString *)clientName
{
    _lastExportError = 0;
    _exportController->generateConnectionConfig(QStringFromNSString(serverId), static_cast<int>(containerIndex), QStringFromNSString(clientName));
    return NSStringFromQString(_exportController->getConfig());
}

- (NSString *)wireGuardConfig:(NSString *)serverId clientName:(NSString *)clientName
{
    _lastExportError = 0;
    _exportController->generateWireGuardConfig(QStringFromNSString(serverId), QStringFromNSString(clientName));
    return NSStringFromQString(_exportController->getNativeConfigString());
}

- (NSString *)awgConfig:(NSString *)serverId containerIndex:(NSInteger)containerIndex clientName:(NSString *)clientName
{
    _lastExportError = 0;
    _exportController->generateAwgConfig(QStringFromNSString(serverId), static_cast<int>(containerIndex), QStringFromNSString(clientName));
    return NSStringFromQString(_exportController->getNativeConfigString());
}

- (NSString *)openVpnConfig:(NSString *)serverId clientName:(NSString *)clientName
{
    _lastExportError = 0;
    _exportController->generateOpenVpnConfig(QStringFromNSString(serverId), QStringFromNSString(clientName));
    return NSStringFromQString(_exportController->getNativeConfigString());
}

- (NSString *)xrayConfig:(NSString *)serverId clientName:(NSString *)clientName
{
    _lastExportError = 0;
    _exportController->generateXrayConfig(QStringFromNSString(serverId), QStringFromNSString(clientName));
    return NSStringFromQString(_exportController->getNativeConfigString());
}

- (NSString *)fullAccessConfig:(NSString *)serverId
{
    _lastExportError = 0;
    _exportController->generateFullAccessConfig(QStringFromNSString(serverId));
    return NSStringFromQString(_exportController->getConfig());
}

- (NSString *)prepareVpnKeyExport:(NSString *)serverId
{
    _lastExportError = 0;
    _subscriptionController->prepareVpnKeyExport(QStringFromNSString(serverId));
    return NSStringFromQString(_subscriptionController->property("vpnKey").toString());
}

- (NSInteger)getLastExportError
{
    return _lastExportError;
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

- (void)setImportFinishedHandler:(void (^)(void))handler
{
    _importFinishedHandler = [handler copy];
}

- (void)setImportErrorHandler:(void (^)(NSInteger, BOOL))handler
{
    _importErrorHandler = [handler copy];
}

- (void)setQrDecodingFinishedHandler:(void (^)(void))handler
{
    _qrDecodingFinishedHandler = [handler copy];
}

- (void)setExportErrorHandler:(void (^)(NSInteger))handler
{
    _exportErrorHandler = [handler copy];
}

@end
