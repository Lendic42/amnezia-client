# AmneziaVPN iOS — SwiftUI 1:1 port inventory

Source of truth: `client/ui/qml/` at upstream dev `5aff2ce` (188 QML files,
17 754 lines in `Pages2/`). This file tracks the port screen by screen. Nothing
is redesigned, nothing is dropped from the final scope: Stage 1 is the first
shippable slice, the rest lands in the stages below in the same order the app
itself exposes them.

## Stages

- **Stage 1** — first green CI build. Self-hosted / native import path
  end-to-end (key, file, QR), Home, Servers, Settings. Runs on the local
  Swift store (`LocalCore`) behind the `AmneziaCore` protocol; the real
  Obj-C++ bridge (`Bridge/AmneziaCoreBridge.h/.mm`, against the actual
  `*UiController` headers) joins when Qt lands in CI.
- **Stage 2 — Premium** — gateway API + StoreKit: subscription purchase,
  trial, renewal, countries, devices, native configs, news, captcha,
  subscription-expired flows. Needs `SubscriptionUiController` + gateway.
- **Stage 3 — Server management** — SSH install flows and server-side
  actions (scan server, update packages, reboot server, clear server
  from Amnezia software, install new protocols). Needs
  `InstallController` + `SelfHostedAdmin`.
- **Stage 4 — Protocol settings** — per-protocol server/client settings
  pages. Needs `InstallController.updateProtocols` + configurators.
- **Stage 5 — Services** — DNS, SOCKS5, SFTP, MTProxy, Telemt, TProxy,
  Tor website, MTProto settings. Needs the service config models.
- **Stage 6 — Misc** — backup/restore format, logging
  refinements, update flow, dev menu, Share users tab + full-access
  sharing (needs SSH), SelectLanguageDrawer + translations pipeline,
  passphrase sheet, About "Check for updates" (gateway `v1/app_update`).

Rule applied in Stage 1: a row is shipped only when its destination page is
ported in Stage 1. Omitted rows are listed under their page below, not
silently dropped. Platform-hidden rows (`visible` false on iOS in QML) are
marked N/A, not queued.

## Global shell (main2.qml + PageStart)

| Element | QML | Stage | Notes |
|---|---|---|---|
| Window, dark bg `#101012` | main2.qml | 1 | SwiftUI `@main`, `.preferredColorScheme(.dark)` |
| Tab bar Home / Share / Settings / Add | PageStart.qml | 1 | 44pt icon-only buttons, 18pt spacing, bg `#1F1F23`, top border `borderSoft`; Share hidden without a write-access server; Settings dot badge when Premium + unread news + notifications on |
| Snackbar (notification + error) | SnackbarType | 1 | Toast, 3s notification, closable persistent error |
| Busy overlay | LoadingOverlayType | — | No async Qt operations in Stage 1; connection progress is the rotating arc on the Connect button. A full-screen busy overlay lands with the first async flow (Stage 2/3) |
| Question drawer | QuestionDrawer | 1 | Native SwiftUI alert / confirmation dialog, exact QML texts |
| Passphrase sheet | main2.qml | 6 | OpenVPN encrypted private keys |
| Captcha dialog | CaptchaDialogType | 2 | Premium purchase captcha |
| Subscription expired drawer | SubscriptionExpiredDrawer | 2 | Premium expiry event |

## Pages — Stage 1 (ported 1:1)

| Page | QML lines | What is ported |
|---|---|---|
| PageStart | 372 | Tabs, navigation stack, all `PageController` routings used by Stage 1 |
| PageHome | 531 | Connect button (190pt ring, rotating arc while connecting), Logging enabled button, split tunneling status button + drawer, collapsed server bar with drag, expanded drawer with server summary + servers list, containers sheet ("VPN protocol"), protocol button for API servers (selection drawer is Stage 2). PromoBanner hidden in Stage 1: `isAdVisible` is false with no gateway data (Stage 2). Dev gateway button hidden: dev gateway env is off in Stage 1 |
| PageSettingsServersList | 89 | Server rows: name, services + host/description subtitle, outdated-AWG warning icon, chevron; tap opens ServerInfo (API servers route to ApiServerInfo in Stage 2) |
| PageSettingsServerInfo | 171 | Header (name, description, rename drawer max 30 chars), tabs Protocols / Services / Management (availableTabs logic: Protocols when installed VPN protocols exist, Services when installed services exist, Management always). Protocols tab: installed VPN containers, radio selection sets the default container. Services tab: installed services list; each service's settings page is Stage 5, tapping shows a "coming in a later build" note |
| PageSettingsServerData | 269 | Management tab; all six rows with the exact QML texts and confirms. "Remove server from application" works locally (blocked during an active connection). Scan / update packages / reboot / clear server show a "coming in a later build" note: they need SSH (Stage 3). "Reset API config" is Stage 2 |
| PageSetupWizardStart | 57 | Logo 153x131 + "Let's get started" |
| PageSetupWizardConfigSource | 439 | Key field + Continue, "File with connection settings", "QR code", more-drawer (Enable logs, Export client logs, support tag). Omitted in Stage 1: "VPN by Amnezia" (Stage 2), "Self-hosted VPN" (Stage 3), "Restore from backup" (Stage 6), "Restore purchases" (Stage 2), "I have nothing" / "Site Amnezia" (N/A on iOS) |
| PageSetupWizardTextKey | 80 | "Connection key", key field with Insert (paste), Continue |
| PageSetupWizardQrReader | 109 | Camera frame, progress bar + "Scanned %1 of %2.", chunked-QR reassembly (magic 1984) |
| PageSetupWizardViewConfig | 199 | "New connection", file name row, Show/Collapse content, WireGuard obfuscation checkbox (native WG configs), malicious-warning banner, trust warning, Connect |
| PageShare | 300+ | "Share VPN Access", tabs Connection / Users. Connection tab: server selector, format picker (Amnezia app / OpenVPN / WireGuard / AmneziaWG / XRay native), QR codes (chunked, 850 bytes, ECC LOW) + key text with copy, Save config per format. Amnezia format and WireGuard/AmneziaWG native `.conf` export work in Stage 1 (from the stored config JSON, credentials stripped, effective DNS applied); OpenVPN/XRay native export is queued. Users tab and "Share full access" are Stage 3/6 (need SSH) |
| PageSettings | 166 | Servers, Connection, Application, Backup, About rows; Dev console row appears when dev mode is on (10 taps on the version in About). Backup and Dev console destinations are queued (Stage 6), tapping shows a "coming in a later build" note. Omitted in Stage 1: News & Notifications (Stage 2, Premium only), Close application (N/A, desktop) |
| PageSettingsConnection | 136 | Use AmneziaDNS switch, DNS servers row, Site-based split tunneling row. App-based split tunneling N/A on iOS, KillSwitch N/A on mobile |
| PageSettingsDns | 153 | Primary/Secondary DNS fields (IP validation), Restore default (1.1.1.1 / 1.0.0.1) with confirm, Save, "Default server does not support custom DNS" notice for API servers |
| PageSettingsApplication | 299 | Allow screenshots (mobile), Check for updates automatically, Language row (picker is Stage 6, tapping shows a note), Logging row, Reset settings row with confirm (blocked during an active connection). Auto start / Auto connect / Start minimized N/A (desktop), Enable notifications N/A (Android), News Notification hidden (Premium only, Stage 2) |
| PageSettingsAbout | 235 | Logo, "Support Amnezia", contacts (Telegram group, Hub bot, support@amnezia.org, GitHub, Website), version + 10-tap dev mode + Copy version, Privacy Policy. "Check for updates" queued (gateway API, Stage 2/6) |
| PageSettingsSplitTunneling | 318 | Enable switch, Via VPN / Directly segmented control, sites list (url + first IP, trash + confirm), add field with DNS resolution, more menu (import add/replace, export, clear), remove confirm; disabled with notice while connected. Site lists are stored per route mode, matching the core |
| PageSettingsLogging | 235 | Record logs toggle (14-day auto-disable), app/tunnel log viewers, Save all logs (.zip), Clear all logs with confirm |
| PageSettingsLogViewer | 242 | Application / Tunnel tabs, Refresh, Copy, Save (.log) |

## Pages — queued

### Stage 2 — Premium (gateway API + StoreKit)

PageSetupWizardApiServicesList, PageSetupWizardApiFreeInfo,
PageSetupWizardApiPremiumInfo (plans, trial, upgrade/downgrade confirms),
PageSetupWizardApiTrialEmail, PageSettingsApiAvailableCountries (country list,
favorites, "Subscription expired / expiring soon", Renew subscription),
PageSettingsApiServerInfo (Subscription Status, Valid Until, Active
Connections, Renew subscription, Local proxy row, Subscription Key,
Configuration Files, Active Devices, Support, Reload API config, Unlink this
device, Remove from application), PageSettingsApiSubscriptionKey (key + QR),
PageSettingsApiDevices, PageSettingsApiInstructions, PageSettingsApiSupport,
PageSettingsApiNativeConfigs, PageSettingsNewsNotifications,
PageSettingsNewsDetail. Premium states that must appear in Stage 1 screens
in the same places (already wired to the same conditions): protocol selection
on Home for API servers, subscription expired/expiring subtitles in server
rows, PromoBanner (`isAdVisible`), Settings tab dot badge, News row in
Settings, "Renew subscription" entry points. They stay hidden in Stage 1
because no API server can exist in the local store yet.

### Stage 3 — Server management (InstallController, SSH)

PageSetupWizardCredentials, PageSetupWizardEasy, PageSetupWizardProtocols,
PageSetupWizardProtocolSettings, PageSetupWizardInstalling,
PageDeinstalling, installing new protocols from the containers sheet and
the Protocols tab, and the server-side actions of PageSettingsServerData
(scan server, update packages, reboot server, clear server from Amnezia
software), Share users tab + full-access sharing.

### Stage 4 — Protocol settings

PageProtocolAwgSettings, PageProtocolAwgClientSettings,
PageProtocolWireGuardSettings, PageProtocolWireGuardClientSettings,
PageProtocolOpenVpnSettings, PageProtocolXraySettings,
PageProtocolXrayTransportSettings, PageProtocolXraySecuritySettings,
PageProtocolXrayFlowSettings, PageProtocolXraySnapshots,
PageProtocolXrayXPaddingSettings, PageProtocolXrayXPaddingBytesSettings,
PageProtocolXrayXmuxSettings, PageProtocolRaw.

### Stage 5 — Services

PageServiceDnsSettings, PageServiceMtProxySettings,
PageServiceMtProtoSettingsBase, PageServiceSftpSettings,
PageServiceSocksProxySettings, PageServiceTProxySettings,
PageServiceTelemtSettings, PageServiceTorWebsiteSettings.

### Stage 6 — Misc

PageSettingsBackup, PageUpdate, PageDevMenu, SelectLanguageDrawer +
translations pipeline, passphrase sheet, About "Check for updates"
(gateway `v1/app_update`), OpenVPN/XRay native export formats in Share.

## Components (35 files)

Stage 1 ports the components its pages use, as Swift views in
`App/Views/`: ConnectButton, HomeServerSummary, HomeInfoButton,
HomeSplitTunnelingDrawer, HomeContainersListView, ServersListView,
RenameServerDrawer, AddSitePanel, QrCodeCard (Share QR pager), the
question/confirm dialogs (native SwiftUI alerts with the exact QML
texts), the snackbar (3s toast), the busy state (connection progress
arc). Not ported as separate components in Stage 1: PromoBanner (Stage
2, hidden with no gateway data), LoadingOverlayType (no async Qt
operations in Stage 1), ShareClientInfoSheet (Stage 3/6).
Queued with their pages: CountriesEmptyState, CountryListItem,
CountryListStickyHeader, CountrySearchRow, CountrySectionHeader,
CountryUseCaseChips, SortCountriesDrawer, SubscriptionExpiredDrawer,
UpdateSupportDrawer, InstalledAppsDrawer, CascadeSettings,
TransportProtoSelector, BenefitRow, BenefitsPanel, CopyableValueRow,
AwgTextField, FavoriteButton, GamepadLoader (Android), TermsAndPrivacyText,
SelectLanguageDrawer (Stage 6).

## Design system (Controls2, 60 files + 8 TextTypes)

Ported as Swift controls in Stage 1 (same metrics, same tokens from
`Modules/Style/AmneziaStyle.qml`): ButtonType (Primary/Secondary/
Destructive; Large 48 / Medium 40 / Small 36; radius 16/14/12),
ListItemType (56pt rows, 24pt icons, separator `borderSoft`),
NavigationBarType (56pt bar, H3 18/600 centered title, back arrow),
TextFieldType (48pt, radius 16), SwitchType (50x30 track, 20pt knob,
accentLight when on), SegmentedControlType, RadioItemType,
SnackbarType (3s toast), ConnectButton (190pt ring, rotating 160° arc
while in progress), sheet grabber + top radius 16 on bottom sheets,
tab bar (44pt icon-only buttons, 18pt spacing, bg `#1F1F23`, top
border `borderSoft`), warning NotificationType banner.
Text types used: Display 36/500, H1 30/700, H2 24/500, H3 18/400,
Body 16/400, Button 16/600, Small 14/400, Caption 12. Font family
"PT Root UI VF" where the design system names it; system font
elsewhere. The remaining Controls2 types are folded into the views
that use them (native SwiftUI alerts/sheets/pickers) or queued with
their pages: CaptchaDialogType, ChangelogSectionType,
ContextMenuType, DropDownType, InputButtonType, ListGroupType, MinMaxRowType,
PopupMenuType, PurchaseOptionType, RadioListType,
RecommendationBadgeType, ScrollBarType, SelectableListItemType,
SelectionGlowType, SpinnerType, LoaderRingType, StackViewType,
TabsType, TextAreaType, BackdropBlurType, BasicCardType, DialogButtonType,
CheckBoxType, SearchFieldType, EmptyStateType, StatusBadgeType, DotBadgeType.

## Bridge surface (C++ core, untouched)

`ConnectionUiController`: isConnected, isConnectionInProgress,
connectionStateText, toggleConnection, openConnection, closeConnection,
getLastConnectionError, signals connectionStateChanged,
connectionErrorOccurred, noInstalledContainers.
`ServersUiController`: defaultServerId/Name/DefaultContainerName,
descriptions, isDefaultServerFromApi, hasServersFromGatewayApi,
processedServerId/processedContainerIndex, setDefaultServer,
setDefaultContainer, removeServer, editServerName, toggleAmneziaDns.
`ImportUiController`: extractConfigFromData/File/Qr, parseQrCodeChunk,
getQrCodeScanProgressBarValue/String, processNativeWireGuardConfig,
importConfig, importFinished / importErrorOccurred.
`SettingsUiController`: primaryDns/secondaryDns, toggleAmneziaDns,
isLoggingEnabled, isScreenshotsEnabled, autoUpdateCheck, news
notifications, clearSettings.
Stage 1 implements this surface in Swift (`AmneziaCore` protocol +
`LocalCore`); the Obj-C++ bridge files expose the same surface against
the real controllers and are wired in when Qt builds in CI.

## Key formats (from core, unchanged)

- `vpn://`: strip prefix, base64url decode (no padding), `qUncompress`
  when it decompresses, JSON. Top level: `containers`,
  `defaultContainer`, optional `apiConfig`.
- Container entry: `container` name (`amnezia-wireguard`,
  `amnezia-openvpn`, …) + object under the same key holding `last_config`
  (JSON string of the protocol client config).
- AWG client config keys: `hostName`, `port`, `client_ip`,
  `client_priv_key`, `client_pub_key`, `server_pub_key`, `psk_key`,
  `allowed_ips`, `persistent_keep_alive`, `mtu`, `Jc`, `Jmin`, `Jmax`,
  `S1`–`S4`, `H1`–`H4`, `I1`–`I5`, `HeaderProtectionKey`,
  `ContentPaddingAddition`, `RekeyAfterTime`, `RekeyTimeout`,
  `RejectAfterTime`, `KeepaliveTimeout`, `MaxHandshakeAttempts`,
  `RandomTrailers`, `DisableCookies`.
- Tunnel `providerConfiguration["wireguard"]` is WGConfig JSON with the
  CodingKeys in `platforms/ios/WGConfig.swift` (`H1`…`Jc`, `client_ip`,
  `client_priv_key`, `server_pub_key`, `psk_key`, `allowed_ips`,
  `splitTunnelType`, `splitTunnelSites`, `dns1`, `dns2`, `mtu`,
  `hostName`, `port`); DNS defaults are Cloudflare 1.1.1.1 / 1.0.0.1.
- QR chunks: base64url of a stream — qint16 magic `1984`, quint8 chunk
  count, quint8 chunk id, QByteArray payload; reassembled payload is the
  qCompressed config bytes (a single QR carries the raw `vpn://` key or
  plain JSON). Export chunks are 850 bytes, ECC LOW, matching
  `qrCodeUtils::generateQrCodeImageSeries`.
- Tunnel extension is WireGuard-only in Stage 1 (OpenVPNAdapter,
  HevSocks5Tunnel and the Xray runtime come from the private Conan remote
  and cannot build in the fork CI); OpenVPN/Xray/vless/vmess/trojan/ss
  configs are rejected at import in Stage 1 with a clear
  "not supported in this build yet" message. The tunnel reads
  `providerConfiguration["wireguard"]` as WGConfig JSON and applies the
  upstream split-tunnel logic (`splitTunnelType` 1 = replace AllowedIPs,
  2 = excludeIPs).
- DNS used by the tunnel: the server's own `dns1`/`dns2` when valid IPv4,
  else Amnezia DNS `172.29.172.254` when AmneziaDNS is enabled and the
  server has the DNS container installed, else the settings Primary /
  Secondary DNS (Cloudflare 1.1.1.1 / 1.0.0.1 defaults).
- Build: Xcode project `client/swiftui/AmneziaVPN-SwiftUI.xcodeproj`
  (app `org.amnezia.AmneziaVPN` + packet-tunnel extension
  `org.amnezia.AmneziaVPN.network-extension`, App Group
  `group.org.amnezia.AmneziaVPN`, iOS 15+, Xcode 26). The extension
  links the local Swift package `client/3rd/amneziawg-apple`
  (WireGuardKit); a run-script phase builds `libwg-go.a` with the
  submodule Makefile (needs Go 1.26). CI
  (`.github/workflows/swiftui-ios.yml`, macOS runner) archives unsigned
  (`CODE_SIGNING_ALLOWED=NO`) and uploads `AmneziaVPN-unsigned.ipa`;
  the sideload tool re-signs it and injects the entitlements from the
  packet-tunnel extension. Device-only in Stage 1: the Makefile has no
  simulator Go target. `VPNKeyDecoder.swift` gained a public
  `decompress(_:)` used by the QR path; otherwise it is the verified
  decoder from `Sources/AmneziaCore/`.
