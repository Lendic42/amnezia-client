#import "AmneziaCoreBootstrap.h"
#import "AmneziaCoreBridge.h"

#include "amneziaApplication.h"
#include "core/controllers/coreController.h"
#include "core/utils/migrations.h"
#include "secureQSettings.h"
#include "version.h"
#include "vpnConnection.h"

#include <openssl/ssl.h>
#include <libssh/libssh.h>

#include <QCoreApplication>
#include <QThread>
#include <QtPlugin>

Q_IMPORT_PLUGIN(QIOSIntegrationPlugin)

static void anchorOpenSSL()
{
    SSL_CTX_free(SSL_CTX_new(TLS_method()));
}

@implementation AmneziaCoreBootstrap

+ (AmneziaCoreBridge *)createBridge
{
    static AmneziaCoreBridge *bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [self buildBridge];
    });
    return bridge;
}

+ (AmneziaCoreBridge *)buildBridge
{
    static int argc = 1;
    static char *argv[] = { (char *)"AmneziaVPN", nullptr };
    static AmneziaApplication *application = nil;
    static SecureQSettings *settings = nil;
    static QThread *vpnConnectionThread = nil;
    static QSharedPointer<VpnConnection> vpnConnection;
    static CoreController *coreController = nil;

    Migrations migrationsManager;
    migrationsManager.doMigrations();

    application = new AmneziaApplication(argc, argv);
    application->setApplicationName(APPLICATION_NAME);
    application->setOrganizationName(ORGANIZATION_NAME);
    application->setApplicationDisplayName(APPLICATION_NAME);

    anchorOpenSSL();
    ssh_init();
    QObject::connect(application, &QCoreApplication::aboutToQuit, []() {
        ssh_finalize();
    });

    settings = new SecureQSettings(ORGANIZATION_NAME, APPLICATION_NAME);

    vpnConnectionThread = new QThread();
    vpnConnection.reset(new VpnConnection(nullptr, nullptr));
    vpnConnection->moveToThread(vpnConnectionThread);
    vpnConnectionThread->start();

    coreController = new CoreController(vpnConnection, settings, nullptr);
    return [[AmneziaCoreBridge alloc] initWithCoreController:coreController];
}

@end
