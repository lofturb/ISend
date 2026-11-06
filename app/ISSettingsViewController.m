#import "ISSettingsViewController.h"
#import "ISTheme.h"
#import "ISPaths.h"
#import "ISService.h"

typedef NS_ENUM(NSInteger, ISSettingsSection) {
    ISSettingsSectionServer = 0,
    ISSettingsSectionFolder = 1,
    ISSettingsSectionInfo = 2
};

typedef NS_ENUM(NSInteger, ISSettingsServerRow) {
    ISSettingsServerRowSwitch = 0,
    ISSettingsServerRowPort = 1,
    ISSettingsServerRowAllowUpload = 2,
    ISSettingsServerRowAllowDelete = 3,
    ISSettingsServerRowRestart = 4
};

@interface ISSettingsViewController ()
@property (nonatomic, strong) UISwitch *serverSwitch;
@property (nonatomic, strong) UISwitch *uploadSwitch;
@property (nonatomic, strong) UISwitch *deleteSwitch;
@end

@implementation ISSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Ajustes";
    self.tableView.backgroundColor = [ISTheme background];
    self.tableView.separatorColor = [ISTheme separator];
    self.tableView.rowHeight = 48.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Listo"
                                         style:UIBarButtonItemStyleDone
                                        target:self
                                        action:@selector(dismiss)];

    self.serverSwitch = [[UISwitch alloc] init];
    self.serverSwitch.onTintColor = [ISTheme accent];
    [self.serverSwitch addTarget:self action:@selector(serverSwitchChanged:)
                forControlEvents:UIControlEventValueChanged];

    self.uploadSwitch = [[UISwitch alloc] init];
    self.uploadSwitch.onTintColor = [ISTheme accent];
    [self.uploadSwitch addTarget:self action:@selector(uploadSwitchChanged:)
                forControlEvents:UIControlEventValueChanged];

    self.deleteSwitch = [[UISwitch alloc] init];
    self.deleteSwitch.onTintColor = [ISTheme accent];
    [self.deleteSwitch addTarget:self action:@selector(deleteSwitchChanged:)
                forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshControls];
}

- (void)refreshControls {
    ISService *service = [ISService shared];
    self.serverSwitch.on = service.running;
    self.uploadSwitch.on = service.allowUpload;
    self.deleteSwitch.on = service.allowDelete;
    [self.tableView reloadData];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case ISSettingsSectionServer: return 5;
        case ISSettingsSectionFolder: return 2;
        default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case ISSettingsSectionServer: return @"Servidor";
        case ISSettingsSectionFolder: return @"Carpeta compartida";
        default: return @"Información";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case ISSettingsSectionServer:
            return @"El servidor se detiene al salir de la app y vuelve a arrancar al abrirla.";
        case ISSettingsSectionFolder:
            return [ISService shared].rootPath;
        default:
            return @"Todo ocurre en tu red local. ISend no envía nada a Internet.";
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.textLabel.textColor = [ISTheme textSecondary];
        header.textLabel.font = [ISTheme fontCaption];
    }
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail {
    static NSString *identifier = @"ISSettingsCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:identifier];
    }
    cell.backgroundColor = [ISTheme card];
    cell.textLabel.text = title;
    cell.textLabel.textColor = [ISTheme textPrimary];
    cell.textLabel.font = [ISTheme fontBody];
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.textColor = [ISTheme textSecondary];
    cell.detailTextLabel.font = [ISTheme fontSubhead];
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISService *service = [ISService shared];

    if (indexPath.section == ISSettingsSectionServer) {
        if (indexPath.row == ISSettingsServerRowSwitch) {
            UITableViewCell *cell = [self cellWithTitle:@"Servidor activo" detail:nil];
            cell.accessoryView = self.serverSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        if (indexPath.row == ISSettingsServerRowPort) {
            UITableViewCell *cell = [self cellWithTitle:@"Puerto"
                                                 detail:[NSString stringWithFormat:@"%d",
                                                         (int)service.port]];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        if (indexPath.row == ISSettingsServerRowAllowUpload) {
            UITableViewCell *cell = [self cellWithTitle:@"Permitir subir" detail:nil];
            cell.accessoryView = self.uploadSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        if (indexPath.row == ISSettingsServerRowAllowDelete) {
            UITableViewCell *cell = [self cellWithTitle:@"Permitir borrar" detail:nil];
            cell.accessoryView = self.deleteSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        UITableViewCell *cell = [self cellWithTitle:@"Reiniciar servidor" detail:nil];
        cell.textLabel.textColor = [ISTheme accent];
        return cell;
    }

    if (indexPath.section == ISSettingsSectionFolder) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [self cellWithTitle:@"Carpeta"
                                                 detail:service.rootLabel];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        UITableViewCell *cell = [self cellWithTitle:@"Espacio libre"
                                             detail:ISFormatBytes(ISFreeBytesAtPath(service.rootPath))];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    if (indexPath.row == 0) {
        UITableViewCell *cell = [self cellWithTitle:@"Versión" detail:ISAppVersion()];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    if (indexPath.row == 1) {
        UITableViewCell *cell = [self cellWithTitle:@"Dirección"
                                             detail:service.currentURL ?: @"Servidor detenido"];
        cell.detailTextLabel.font = [ISTheme fontMono:12.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }

    UITableViewCell *cell = [self cellWithTitle:@"Abrir interfaz web" detail:nil];
    cell.textLabel.textColor = [ISTheme accent];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == ISSettingsSectionServer) {
        if (indexPath.row == ISSettingsServerRowPort) {
            [self promptForPort];
        } else if (indexPath.row == ISSettingsServerRowRestart) {
            [[ISService shared] restart];
            [self refreshControls];
        }
        return;
    }

    if (indexPath.section == ISSettingsSectionInfo && indexPath.row == 2) {
        NSString *url = [ISService shared].currentURL;
        if (url) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
    }
}

#pragma mark - Acciones

- (void)serverSwitchChanged:(UISwitch *)sender {
    ISService *service = [ISService shared];
    if (sender.isOn) {
        NSString *error = nil;
        if (![service enableAndStart:&error]) {
            sender.on = NO;
            [self showAlertWithTitle:@"No se pudo iniciar"
                             message:error ?: @"Error desconocido."];
        }
    } else {
        [service disable];
    }
    [self refreshControls];
}

- (void)uploadSwitchChanged:(UISwitch *)sender {
    [ISService shared].allowUpload = sender.isOn;
}

- (void)deleteSwitchChanged:(UISwitch *)sender {
    [ISService shared].allowDelete = sender.isOn;
}

- (void)promptForPort {
    ISService *service = [ISService shared];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Puerto del servidor"
                                            message:@"Usa un número entre 1024 y 65535."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeNumberPad;
        field.text = [NSString stringWithFormat:@"%d", (int)service.port];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Aplicar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSInteger port = [alert.textFields.firstObject.text integerValue];
        if (port < 1024 || port > 65535) {
            [self showAlertWithTitle:@"Puerto no válido"
                             message:@"Elige un número entre 1024 y 65535."];
            return;
        }
        NSString *error = nil;
        if (![service applyPort:(uint16_t)port error:&error]) {
            [self showAlertWithTitle:@"No se pudo cambiar"
                             message:error ?: @"Error desconocido."];
        }
        [self refreshControls];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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
