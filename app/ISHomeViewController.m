#import "ISHomeViewController.h"
#import "ISTheme.h"
#import "ISPaths.h"
#import "ISService.h"
#import "ISQRCode.h"
#import "ISSettingsViewController.h"

@interface ISHomeViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *urlLabel;
@property (nonatomic, strong) UILabel *hostLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *qrBox;
@property (nonatomic, strong) UIImageView *qrView;

@property (nonatomic, strong) UIButton *linkCopyButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *toggleButton;

@property (nonatomic, strong) UILabel *folderPathLabel;
@property (nonatomic, strong) UILabel *folderDetailLabel;

@property (nonatomic, strong) UILabel *receivedValueLabel;
@property (nonatomic, strong) UILabel *sentValueLabel;
@property (nonatomic, strong) UILabel *uploadsValueLabel;

@property (nonatomic, strong) UILabel *footerLabel;
@end

@implementation ISHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ISend";
    self.view.backgroundColor = [ISTheme background];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Ajustes"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openSettings)];

    [self buildInterface];
    [self setupObservers];
    [self updateInterface];
}

- (void)buildInterface {
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = [ISTheme background];
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 14.0;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:20.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-20.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-24.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-40.0]
    ]];

    [self.contentStack addArrangedSubview:[self buildHeroCard]];
    [self.contentStack addArrangedSubview:[self buildActionRow]];
    [self.contentStack addArrangedSubview:[self buildFolderCard]];
    [self.contentStack addArrangedSubview:[self buildStatsCard]];
    [self.contentStack addArrangedSubview:[self buildHelpCard]];

    self.footerLabel = [self labelWithFont:[ISTheme fontCaption]
                                     color:[ISTheme textTertiary]
                                      text:[NSString stringWithFormat:
                                            @"ISend %@ · sin nube · sin cables",
                                            ISAppVersion]];
    self.footerLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentStack addArrangedSubview:self.footerLabel];
}

#pragma mark - Construccion de tarjetas

- (UIView *)buildHeroCard {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [ISTheme accentDark];
    card.layer.cornerRadius = 20.0;

    UIStackView *row = [[UIStackView alloc] initWithFrame:CGRectZero];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 16.0;
    [card addSubview:row];

    UIStackView *text = [[UIStackView alloc] initWithFrame:CGRectZero];
    text.axis = UILayoutConstraintAxisVertical;
    text.alignment = UIStackViewAlignmentLeading;
    text.spacing = 6.0;
    [text setContentCompressionResistancePriority:749.0
                                          forAxis:UILayoutConstraintAxisHorizontal];

    UIView *statusRow = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusDot = [[UIView alloc] initWithFrame:CGRectZero];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.backgroundColor = [ISTheme textPrimary];
    self.statusDot.layer.cornerRadius = 4.0;
    [statusRow addSubview:self.statusDot];

    self.statusLabel = [self labelWithFont:[UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold]
                                     color:[ISTheme textPrimary]
                                      text:@"Servidor activo"];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [statusRow addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusDot.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:statusRow.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:8.0],
        [self.statusDot.heightAnchor constraintEqualToConstant:8.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:7.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:statusRow.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:statusRow.topAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:statusRow.bottomAnchor],
        [statusRow.heightAnchor constraintGreaterThanOrEqualToConstant:16.0]
    ]];

    self.urlLabel = [self labelWithFont:[ISTheme fontMono:22.0]
                                  color:[UIColor whiteColor]
                                   text:@"—"];
    self.urlLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:22.0]
        ?: [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
    self.urlLabel.adjustsFontSizeToFitWidth = YES;
    self.urlLabel.minimumScaleFactor = 0.55;
    self.urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    self.hostLabel = [self labelWithFont:[ISTheme fontMono:11.0]
                                   color:[[UIColor whiteColor] colorWithAlphaComponent:0.7]
                                    text:@""];
    self.hostLabel.hidden = YES;

    self.hintLabel = [self labelWithFont:[ISTheme fontSubhead]
                                   color:[[UIColor whiteColor] colorWithAlphaComponent:0.82]
                                    text:@"Abre esta dirección en el navegador del ordenador o del móvil."];
    self.hintLabel.numberOfLines = 3;

    [text addArrangedSubview:statusRow];
    [text addArrangedSubview:self.urlLabel];
    [text addArrangedSubview:self.hostLabel];
    [text addArrangedSubview:self.hintLabel];

    self.qrBox = [[UIView alloc] initWithFrame:CGRectZero];
    self.qrBox.translatesAutoresizingMaskIntoConstraints = NO;
    self.qrBox.backgroundColor = [UIColor whiteColor];
    self.qrBox.layer.cornerRadius = 14.0;
    [self.qrBox.widthAnchor constraintEqualToConstant:136.0].active = YES;
    [self.qrBox.heightAnchor constraintEqualToConstant:136.0].active = YES;

    self.qrView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.qrView.translatesAutoresizingMaskIntoConstraints = NO;
    self.qrView.contentMode = UIViewContentModeScaleAspectFit;
    [self.qrBox addSubview:self.qrView];
    [NSLayoutConstraint activateConstraints:@[
        [self.qrView.topAnchor constraintEqualToAnchor:self.qrBox.topAnchor constant:4.0],
        [self.qrView.leadingAnchor constraintEqualToAnchor:self.qrBox.leadingAnchor constant:4.0],
        [self.qrView.trailingAnchor constraintEqualToAnchor:self.qrBox.trailingAnchor constant:-4.0],
        [self.qrView.bottomAnchor constraintEqualToAnchor:self.qrBox.bottomAnchor constant:-4.0]
    ]];

    [row addArrangedSubview:text];
    [row addArrangedSubview:self.qrBox];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:card.topAnchor constant:20.0],
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20.0]
    ]];

    return card;
}

- (UIView *)buildActionRow {
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    self.linkCopyButton = [ISTheme buttonWithTitle:@"Copiar enlace"
                                    background:[ISTheme accent]
                                    foreground:[ISTheme colorWithHex:0x06281C alpha:1.0]];
    [self.linkCopyButton addTarget:self action:@selector(copyLink:)
              forControlEvents:UIControlEventTouchUpInside];

    self.shareButton = [ISTheme buttonWithTitle:@"Compartir"
                                     background:[ISTheme cardAlt]
                                     foreground:[ISTheme textPrimary]];
    [self.shareButton addTarget:self action:@selector(shareLink:)
               forControlEvents:UIControlEventTouchUpInside];

    self.toggleButton = [ISTheme buttonWithTitle:@"Detener"
                                      background:[ISTheme cardAlt]
                                      foreground:[ISTheme danger]];
    [self.toggleButton addTarget:self action:@selector(toggleServer:)
                forControlEvents:UIControlEventTouchUpInside];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:
                        @[ self.linkCopyButton, self.shareButton, self.toggleButton ]];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 10.0;
    [container addSubview:row];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:container.topAnchor],
        [row.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [row.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [row.heightAnchor constraintEqualToConstant:46.0]
    ]];

    return container;
}

- (UIView *)buildFolderCard {
    UIView *card = [ISTheme cardView];
    UIStackView *stack = [self verticalStackInCard:card];

    UIView *header = [[UIView alloc] initWithFrame:CGRectZero];
    UILabel *title = [self labelWithFont:[ISTheme fontCaption]
                                   color:[ISTheme textSecondary]
                                    text:@"CARPETA COMPARTIDA"];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];

    UIButton *change = [UIButton buttonWithType:UIButtonTypeSystem];
    change.translatesAutoresizingMaskIntoConstraints = NO;
    [change setTitle:@"Cambiar" forState:UIControlStateNormal];
    [change setTitleColor:[ISTheme accent] forState:UIControlStateNormal];
    change.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    [change addTarget:self action:@selector(changeFolder:) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:change];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [change.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [change.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [change.leadingAnchor constraintGreaterThanOrEqualToAnchor:title.trailingAnchor constant:8.0],
        [header.heightAnchor constraintEqualToConstant:28.0]
    ]];

    self.folderPathLabel = [self labelWithFont:[ISTheme fontMono:12.0]
                                        color:[ISTheme textPrimary]
                                         text:@""];
    self.folderPathLabel.numberOfLines = 2;
    self.folderPathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    self.folderDetailLabel = [self labelWithFont:[ISTheme fontSubhead]
                                          color:[ISTheme textSecondary]
                                           text:@""];

    [stack addArrangedSubview:header];
    [stack addArrangedSubview:self.folderPathLabel];
    [stack addArrangedSubview:self.folderDetailLabel];

    return card;
}

- (UIView *)buildStatsCard {
    UIView *card = [ISTheme cardView];
    UIStackView *stack = [self verticalStackInCard:card];

    UILabel *title = [self labelWithFont:[ISTheme fontCaption]
                                   color:[ISTheme textSecondary]
                                    text:@"ESTA SESIÓN"];
    [stack addArrangedSubview:title];

    UIStackView *row = [[UIStackView alloc] initWithFrame:CGRectZero];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 10.0;

    self.receivedValueLabel = [self statValueWithCaption:@"Recibido" inRow:row];
    self.sentValueLabel = [self statValueWithCaption:@"Enviado" inRow:row];
    self.uploadsValueLabel = [self statValueWithCaption:@"Archivos" inRow:row];

    [stack addArrangedSubview:row];
    return card;
}

- (UILabel *)statValueWithCaption:(NSString *)caption inRow:(UIStackView *)row {
    UIStackView *block = [[UIStackView alloc] initWithFrame:CGRectZero];
    block.axis = UILayoutConstraintAxisVertical;
    block.spacing = 2.0;
    block.alignment = UIStackViewAlignmentLeading;

    UILabel *value = [self labelWithFont:[ISTheme fontMono:17.0]
                                  color:[ISTheme textPrimary]
                                   text:@"0 B"];
    value.adjustsFontSizeToFitWidth = YES;
    value.minimumScaleFactor = 0.7;

    UILabel *label = [self labelWithFont:[ISTheme fontCaption]
                                   color:[ISTheme textTertiary]
                                    text:[caption uppercaseString]];

    [block addArrangedSubview:value];
    [block addArrangedSubview:label];
    [row addArrangedSubview:block];
    return value;
}

- (UIView *)buildHelpCard {
    UIView *card = [ISTheme cardView];
    UIStackView *stack = [self verticalStackInCard:card];

    UILabel *title = [self labelWithFont:[ISTheme fontCaption]
                                   color:[ISTheme textSecondary]
                                    text:@"CÓMO FUNCIONA"];
    [stack addArrangedSubview:title];

    NSArray *steps = @[
        @"1. Conecta el ordenador o el móvil a la misma Wi-Fi que el iPad.",
        @"2. Abre la dirección de arriba en el navegador (o escanea el QR).",
        @"3. Para enviar, arrastra archivos o pulsa «Elegir archivos».",
        @"4. Para recibir, usa el botón de descarga de cada archivo."
    ];
    for (NSString *step in steps) {
        UILabel *label = [self labelWithFont:[ISTheme fontSubhead]
                                      color:[ISTheme textSecondary]
                                       text:step];
        label.numberOfLines = 0;
        [stack addArrangedSubview:label];
    }

    UILabel *note = [self labelWithFont:[ISTheme fontCaption]
                                  color:[ISTheme warning]
                                   text:@"La app debe estar abierta mientras se transfieren archivos."];
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];

    return card;
}

#pragma mark - Utilidades de construccion

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color text:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = font;
    label.textColor = color;
    label.text = text;
    return label;
}

- (UIStackView *)verticalStackInCard:(UIView *)card {
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:16.0],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16.0]
    ]];
    return stack;
}

#pragma mark - Estado

- (void)setupObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(updateInterface)
                   name:ISServiceStateDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(updateInterface)
                   name:ISServiceFilesDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateInterface];
}

- (void)updateInterface {
    ISService *service = [ISService shared];
    BOOL running = service.running;
    NSString *url = service.currentURL;

    self.statusDot.backgroundColor = running ? [ISTheme textPrimary]
                                             : [[UIColor whiteColor] colorWithAlphaComponent:0.45];
    self.statusLabel.text = running ? @"Servidor activo" : @"Servidor detenido";

    self.urlLabel.text = running ? url : @"—";
    self.qrBox.hidden = !running;
    self.qrView.image = running ? [ISQRCode imageForString:url size:128.0] : nil;

    NSString *host = ISLocalHostName();
    BOOL hasHost = running && host.length > 0;
    self.hostLabel.hidden = !hasHost;
    self.hostLabel.text = hasHost
        ? [NSString stringWithFormat:@"también http://%@:%d", host, (int)service.port]
        : @"";

    if (!running) {
        self.hintLabel.text = @"Pulsa «Iniciar servidor» para empezar.";
    } else if ([ISLanIPv4Address() hasPrefix:@"127."]) {
        self.hintLabel.text = @"Sin Wi-Fi. Conecta el iPad a la misma red que el ordenador.";
    } else {
        self.hintLabel.text = @"Abre esta dirección en el navegador del ordenador o del móvil. La pantalla seguirá encendida mientras el servidor esté activo.";
    }

    [self.linkCopyButton setTitle:@"Copiar enlace" forState:UIControlStateNormal];
    self.linkCopyButton.enabled = running;
    self.shareButton.enabled = running;

    [self.toggleButton setTitle:(running ? @"Detener" : @"Iniciar servidor")
                       forState:UIControlStateNormal];
    self.toggleButton.backgroundColor = running ? [ISTheme cardAlt] : [ISTheme accent];
    [self.toggleButton setTitleColor:(running ? [ISTheme danger]
                                             : [ISTheme colorWithHex:0x06281C alpha:1.0])
                            forState:UIControlStateNormal];

    self.folderPathLabel.text = service.rootPath;
    self.folderDetailLabel.text = [NSString stringWithFormat:@"%@ · %@ libres",
                                   service.rootLabel,
                                   ISFormatBytes(ISFreeBytesAtPath(service.rootPath))];

    self.receivedValueLabel.text = ISFormatBytes(service.bytesIn);
    self.sentValueLabel.text = ISFormatBytes(service.bytesOut);
    self.uploadsValueLabel.text = [NSString stringWithFormat:@"%lu",
                                   (unsigned long)service.uploadCount];
}

#pragma mark - Acciones

- (void)copyLink:(UIButton *)sender {
    NSString *url = [ISService shared].currentURL;
    if (!url) { return; }
    [UIPasteboard generalPasteboard].string = url;
    [sender setTitle:@"Copiado" forState:UIControlStateNormal];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [sender setTitle:@"Copiar enlace" forState:UIControlStateNormal];
    });
}

- (void)shareLink:(UIButton *)sender {
    NSString *url = [ISService shared].currentURL;
    if (!url) { return; }

    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[ url ]
                                          applicationActivities:nil];
    activity.popoverPresentationController.sourceView = sender;
    activity.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)toggleServer:(UIButton *)sender {
    ISService *service = [ISService shared];
    if (service.running) {
        [service disable];
        [self updateInterface];
        return;
    }

    NSString *error = nil;
    if (![service enableAndStart:&error]) {
        [self showAlertWithTitle:@"No se pudo iniciar"
                         message:error ?: @"Error desconocido."];
    }
    [self updateInterface];
}

- (void)changeFolder:(UIButton *)sender {
    ISService *service = [ISService shared];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Carpeta compartida"
                                                                  message:service.rootPath
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Documentos de ISend"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self applyRoot:ISAppDocumentsDirectory()];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"/var/mobile/Documents"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self applyRoot:@"/var/mobile/Documents"];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Raíz del sistema (/)" 
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        UIAlertController *confirm =
            [UIAlertController alertControllerWithTitle:@"¿Publicar todo el sistema?"
                                                message:@"Cualquiera en tu Wi-Fi podrá leer los archivos a los que tenga permiso el iPad. Úsalo solo en redes de confianza."
                                         preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Publicar /"
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction *a) {
            [self applyRoot:@"/"];
        }]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)applyRoot:(NSString *)path {
    NSString *error = nil;
    if (![[ISService shared] applyRootPath:path error:&error]) {
        [self showAlertWithTitle:@"No se pudo cambiar" message:error ?: @"Error desconocido."];
        return;
    }
    [self updateInterface];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:ISServiceFilesDidChangeNotification object:nil];
}

- (void)openSettings {
    ISSettingsViewController *settings = [[ISSettingsViewController alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:settings];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Vale"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
