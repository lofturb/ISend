#import "ISFileCell.h"
#import "ISTheme.h"

@interface ISFileCell ()
@property (nonatomic, strong) UIView *iconBox;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *chevronLabel;
@end

@implementation ISFileCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) { return nil; }

    self.backgroundColor = [ISTheme card];
    self.contentView.backgroundColor = [ISTheme card];
    UIView *selected = [[UIView alloc] init];
    selected.backgroundColor = [ISTheme accentSoft];
    self.selectedBackgroundView = selected;

    _iconBox = [[UIView alloc] init];
    _iconBox.translatesAutoresizingMaskIntoConstraints = NO;
    _iconBox.backgroundColor = [ISTheme cardAlt];
    _iconBox.layer.cornerRadius = 10.0;
    [self.contentView addSubview:_iconBox];

    _iconLabel = [[UILabel alloc] init];
    _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _iconLabel.font = [UIFont systemFontOfSize:20.0];
    _iconLabel.textAlignment = NSTextAlignmentCenter;
    [_iconBox addSubview:_iconLabel];

    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    _nameLabel.textColor = [ISTheme textPrimary];
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.contentView addSubview:_nameLabel];

    _detailLabel = [[UILabel alloc] init];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font = [ISTheme fontSubhead];
    _detailLabel.textColor = [ISTheme textSecondary];
    [self.contentView addSubview:_detailLabel];

    _chevronLabel = [[UILabel alloc] init];
    _chevronLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _chevronLabel.text = @"›";
    _chevronLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightRegular];
    _chevronLabel.textColor = [ISTheme textTertiary];
    _chevronLabel.textAlignment = NSTextAlignmentCenter;
    [self.contentView addSubview:_chevronLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_iconBox.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_iconBox.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_iconBox.widthAnchor constraintEqualToConstant:40.0],
        [_iconBox.heightAnchor constraintEqualToConstant:40.0],

        [_iconLabel.centerXAnchor constraintEqualToAnchor:_iconBox.centerXAnchor],
        [_iconLabel.centerYAnchor constraintEqualToAnchor:_iconBox.centerYAnchor],

        [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconBox.trailingAnchor constant:12.0],
        [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:_chevronLabel.leadingAnchor constant:-6.0],

        [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
        [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3.0],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:_chevronLabel.leadingAnchor constant:-6.0],

        [_chevronLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],
        [_chevronLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_chevronLabel.widthAnchor constraintEqualToConstant:18.0],

        [self.contentView.bottomAnchor constraintGreaterThanOrEqualToAnchor:_detailLabel.bottomAnchor constant:12.0]
    ]];

    return self;
}

- (void)configureWithName:(NSString *)name
                   detail:(NSString *)detail
                    emoji:(NSString *)emoji
                   folder:(BOOL)folder {
    self.nameLabel.text = name;
    self.detailLabel.text = detail;
    self.iconLabel.text = emoji;
    self.iconBox.backgroundColor = folder ? [ISTheme accentSoft] : [ISTheme cardAlt];
    self.chevronLabel.hidden = !folder;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.nameLabel.text = nil;
    self.detailLabel.text = nil;
    self.iconLabel.text = nil;
    self.chevronLabel.hidden = NO;
}

@end
