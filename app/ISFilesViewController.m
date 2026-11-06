#import "ISFilesViewController.h"
#import "ISTheme.h"
#import "ISPaths.h"
#import "ISService.h"
#import "ISFileCell.h"
#import <QuickLook/QuickLook.h>

@interface ISPreviewItem : NSObject <QLPreviewItem>
@property (nonatomic, strong) NSURL *previewItemURL;
@property (nonatomic, copy) NSString *previewItemTitle;
@end

@implementation ISPreviewItem
@end

@interface ISFilesViewController () <UITableViewDataSource, UITableViewDelegate,
                                     QLPreviewControllerDataSource>
@property (nonatomic, copy) NSString *relativePath;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray *entries;
@property (nonatomic, strong) NSArray *previewFiles;
@end

@implementation ISFilesViewController

- (instancetype)initWithRelativePath:(NSString *)relativePath {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _relativePath = [(relativePath.length ? relativePath : @"/") copy];
        _entries = @[];
        _previewFiles = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [ISTheme background];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                  style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64.0;
    self.tableView.backgroundColor = [ISTheme background];
    self.tableView.separatorColor = [ISTheme separator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 68.0, 0, 0);
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0, 12.0, 0);
    [self.tableView registerClass:[ISFileCell class] forCellReuseIdentifier:@"ISFileCell"];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [ISTheme fontBody];
    self.emptyLabel.textColor = [ISTheme textSecondary];
    [self.view addSubview:self.emptyLabel];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reload)
                  forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(createFolder)];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-24.0],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32.0],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32.0]
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:ISServiceFilesDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reload)
                                                 name:ISServiceStateDidChangeNotification
                                               object:nil];

    [self updateTitle];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateTitle {
    if ([self.relativePath isEqualToString:@"/"]) {
        self.title = @"Archivos";
    } else {
        self.title = [self.relativePath lastPathComponent];
    }
}

#pragma mark - Datos

- (void)reload {
    ISService *service = [ISService shared];
    NSString *full = [service resolveRelativePath:self.relativePath];

    BOOL isDirectory = NO;
    if (!full || ![[NSFileManager defaultManager] fileExistsAtPath:full
                                                      isDirectory:&isDirectory] ||
        !isDirectory) {
        self.relativePath = @"/";
        full = [service resolveRelativePath:@"/"];
    }

    NSError *error = nil;
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:full
                                                                        error:&error];
    NSMutableArray *items = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];

    for (NSString *name in names) {
        if ([name hasPrefix:@".isend-"] || [name isEqualToString:@".DS_Store"]) { continue; }

        NSString *path = [full stringByAppendingPathComponent:name];
        BOOL itemIsDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:path
                                                  isDirectory:&itemIsDirectory]) { continue; }

        NSDictionary *attributes = [[NSFileManager defaultManager]
                                    attributesOfItemAtPath:path error:NULL];
        NSDate *date = attributes[NSFileModificationDate];
        NSString *relative = ISRelativePath(path, service.rootPath);
        if (!relative) { continue; }

        NSMutableDictionary *item = [@{
            @"name": name,
            @"path": relative,
            @"dir": @(itemIsDirectory),
            @"size": @([attributes[NSFileSize] unsignedLongLongValue]),
            @"mtime": @(date ? [date timeIntervalSince1970] : 0),
            @"kind": ISFileKindForPath(path, itemIsDirectory)
        } mutableCopy];

        [items addObject:item];
        if (!itemIsDirectory) { [files addObject:item]; }
    }

    [items sortUsingComparator:^NSComparisonResult(id a, id b) {
        NSDictionary *left = (NSDictionary *)a;
        NSDictionary *right = (NSDictionary *)b;
        BOOL aDir = [left[@"dir"] boolValue];
        BOOL bDir = [right[@"dir"] boolValue];
        if (aDir != bDir) { return aDir ? NSOrderedAscending : NSOrderedDescending; }
        return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];

    self.entries = items;
    self.previewFiles = files;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];

    self.emptyLabel.hidden = (items.count > 0);
    self.emptyLabel.text = error
        ? [NSString stringWithFormat:@"No se pudo leer la carpeta.\n%@", error.localizedDescription]
        : @"Esta carpeta está vacía.\nEnvía archivos desde el navegador o crea una carpeta con +.";

    self.tableView.separatorStyle = items.count
        ? UITableViewCellSeparatorStyleSingleLine
        : UITableViewCellSeparatorStyleNone;

    [self updateTitle];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISFileCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ISFileCell"
                                                       forIndexPath:indexPath];
    NSDictionary *item = self.entries[indexPath.row];
    BOOL isDirectory = [item[@"dir"] boolValue];

    NSString *detail;
    if (isDirectory) {
        detail = @"Carpeta";
    } else {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[item[@"mtime"] doubleValue]];
        detail = [NSString stringWithFormat:@"%@ · %@",
                  ISFormatBytes([item[@"size"] unsignedLongLongValue]),
                  ISFormatDate(date)];
    }

    [cell configureWithName:item[@"name"]
                     detail:detail
                      emoji:ISEmojiForKind(item[@"kind"])
                     folder:isDirectory];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.entries[indexPath.row];

    if ([item[@"dir"] boolValue]) {
        ISFilesViewController *next =
            [[ISFilesViewController alloc] initWithRelativePath:item[@"path"]];
        [self.navigationController pushViewController:next animated:YES];
        return;
    }

    NSUInteger index = [self.previewFiles indexOfObject:item];
    if (index == NSNotFound) { return; }

    QLPreviewController *preview = [[QLPreviewController alloc] init];
    preview.dataSource = self;
    preview.currentPreviewItemIndex = (NSInteger)index;
    [self presentViewController:preview animated:YES completion:nil];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                        editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.entries[indexPath.row];

    UITableViewRowAction *delete =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive
                                           title:@"Borrar"
                                         handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self confirmDeleteAtIndexPath:path];
    }];

    UITableViewRowAction *rename =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Renombrar"
                                         handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self renameAtIndexPath:path];
    }];
    rename.backgroundColor = [ISTheme cardAlt];

    UITableViewRowAction *share =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Compartir"
                                         handler:^(UITableViewRowAction *action, NSIndexPath *path) {
        [self shareAtIndexPath:path];
    }];
    share.backgroundColor = [ISTheme accentDark];

    // En una carpeta no tiene sentido compartirla como archivo.
    if ([item[@"dir"] boolValue]) {
        return @[ delete, rename ];
    }
    return @[ delete, rename, share ];
}

#pragma mark - Acciones

- (void)shareAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.entries[indexPath.row];
    NSString *full = [[ISService shared] resolveRelativePath:item[@"path"]];
    if (!full) { return; }

    UIActivityViewController *activity =
        [[UIActivityViewController alloc] initWithActivityItems:@[ [NSURL fileURLWithPath:full] ]
                                          applicationActivities:nil];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    activity.popoverPresentationController.sourceView = cell ?: self.view;
    activity.popoverPresentationController.sourceRect = cell ? cell.bounds : self.view.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)renameAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.entries[indexPath.row];
    NSString *full = [[ISService shared] resolveRelativePath:item[@"path"]];
    if (!full) { return; }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Renombrar"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = item[@"name"];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Guardar"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self applyRename:full inAlert:alert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyRename:(NSString *)full inAlert:(UIAlertController *)alert {
    NSString *name = ISSafeFileName(alert.textFields.firstObject.text);
    if (!name.length) { return; }

    NSString *directory = [full stringByDeletingLastPathComponent];
    NSString *target = [directory stringByAppendingPathComponent:name];
    if ([target isEqualToString:full]) { return; }

    if ([[NSFileManager defaultManager] fileExistsAtPath:target]) {
        [self showAlertWithTitle:@"Ya existe"
                         message:@"Hay otro elemento con ese nombre en esta carpeta."];
        return;
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:full toPath:target error:&error]) {
        [self showAlertWithTitle:@"No se pudo renombrar"
                         message:error.localizedDescription];
        return;
    }
    [self reload];
    [[ISService shared] notifyFilesChanged];
}

- (void)confirmDeleteAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.entries[indexPath.row];
    NSString *full = [[ISService shared] resolveRelativePath:item[@"path"]];
    if (!full) { return; }

    BOOL isDirectory = [item[@"dir"] boolValue];
    NSString *message = isDirectory
        ? @"Se borrará la carpeta y todo su contenido."
        : @"Esta acción no se puede deshacer.";

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"¿Borrar «%@»?", item[@"name"]]
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Borrar"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:full error:&error]) {
            [self showAlertWithTitle:@"No se pudo borrar"
                             message:error.localizedDescription];
            return;
        }
        [self reload];
        [[ISService shared] notifyFilesChanged];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)createFolder {
    NSString *full = [[ISService shared] resolveRelativePath:self.relativePath];
    if (!full) { return; }

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Nueva carpeta"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Nombre";
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Crear"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        NSString *name = ISSafeFileName(alert.textFields.firstObject.text);
        if (!name.length) { return; }
        NSString *target = [full stringByAppendingPathComponent:name];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:target
                                       withIntermediateDirectories:NO
                                                        attributes:nil error:&error]) {
            [self showAlertWithTitle:@"No se pudo crear"
                             message:error.localizedDescription];
            return;
        }
        [self reload];
        [[ISService shared] notifyFilesChanged];
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

#pragma mark - QuickLook

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
    return (NSInteger)self.previewFiles.count;
}

- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller
                    previewItemAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.previewFiles.count) { return nil; }
    NSDictionary *item = self.previewFiles[index];
    NSString *full = [[ISService shared] resolveRelativePath:item[@"path"]];

    ISPreviewItem *preview = [[ISPreviewItem alloc] init];
    preview.previewItemURL = full ? [NSURL fileURLWithPath:full] : nil;
    preview.previewItemTitle = item[@"name"];
    return preview;
}

@end
