
#import "RNFileViewerManager.h"
#import <QuickLook/QuickLook.h>
#import <React/RCTConvert.h>

#define OPEN_EVENT @"RNFileViewerDidOpen"
#define DISMISS_EVENT @"RNFileViewerDidDismiss"
#define SEND_EVENT @"RNFileViewerDidSend"

@interface File: NSObject<QLPreviewItem>

@property(readonly, nullable, nonatomic) NSURL *previewItemURL;
@property(readonly, nullable, nonatomic) NSString *previewItemTitle;

- (id)initWithPath:(NSString *)file title:(NSString *)title;

@end

@implementation File

- (id)initWithPath:(NSString *)file title:(NSString *)title {
    if(self = [super init]) {
        _previewItemURL = [NSURL fileURLWithPath:file];
        _previewItemTitle = title;
    }
    return self;
}

@end

@interface CustomQLViewController: QLPreviewController<QLPreviewControllerDataSource>

@property(nonatomic, strong) File *file;
@property(nonatomic, strong) NSNumber *invocation;

@end

@implementation CustomQLViewController

- (instancetype)initWithFile:(File *)file identifier:(NSNumber *)invocation {
    if(self = [super init]) {
        _file = file;
        _invocation = invocation;
        self.dataSource = self;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return UIApplication.sharedApplication.isStatusBarHidden;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller{
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index{
    return self.file;
}

@end

@interface RNFileViewer ()<QLPreviewControllerDelegate>

@property(nonatomic, strong) File *file;
@property(nonatomic, strong) NSNumber *invocation;
@property(nonatomic, assign) BOOL hasListeners;

@end

@implementation RNFileViewer

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

// Will be called when this module's first listener is added.
-(void)startObserving {
    self.hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    self.hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}

+ (UIViewController*)topViewController {
    UIViewController *presenterViewController = [self topViewControllerWithRootViewController:UIApplication.sharedApplication.keyWindow.rootViewController];
    return presenterViewController ? presenterViewController : UIApplication.sharedApplication.keyWindow.rootViewController;
}

+ (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)viewController {
    if ([viewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*)viewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    }
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navContObj = (UINavigationController*)viewController;
        return [self topViewControllerWithRootViewController:navContObj.visibleViewController];
    }
    if (viewController.presentedViewController && !viewController.presentedViewController.isBeingDismissed) {
        UIViewController* presentedViewController = viewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    for (UIView *view in [viewController.view subviews]) {
        id subViewController = [view nextResponder];
        if ( subViewController && [subViewController isKindOfClass:[UIViewController class]]) {
            if ([(UIViewController *)subViewController presentedViewController]  && ![subViewController presentedViewController].isBeingDismissed) {
                return [self topViewControllerWithRootViewController:[(UIViewController *)subViewController presentedViewController]];
            }
        }
    }
    return viewController;
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents {
    return @[OPEN_EVENT, DISMISS_EVENT, SEND_EVENT];
}

RCT_EXPORT_METHOD(open:(NSString *)path invocation:(nonnull NSNumber *)invocationId
                  options:(NSDictionary *)options)
{
    NSString *displayName = [RCTConvert NSString:options[@"displayName"]];
    BOOL showSendButton = [RCTConvert BOOL:options[@"showSendButton"]];
    self.file = [[File alloc] initWithPath:path title:displayName];
    self.invocation = invocationId;
    
    QLPreviewController *controller = [[CustomQLViewController alloc] initWithFile:self.file identifier:invocationId];
    controller.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if (@available(iOS 13.0, *)) {
        [controller setModalInPresentation: true];
    }
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    controller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(didTapDoneButton:)];
    
    // QLPreviewController shows share button as rightBarButtonItem for fraction of second when presented. This blank button would stop that from happening.
    controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:self action:nil];
    
    if (showSendButton) {
        controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStylePlain target:self action:@selector(didTapSendButton:)];
    }
    controller.delegate = self;
    
    typeof(self) __weak weakSelf = self;
    [[RNFileViewer topViewController] presentViewController:navigationController animated:YES completion:^{
        if (weakSelf.hasListeners) {
            [weakSelf sendEventWithName:OPEN_EVENT body: @{@"id": weakSelf.invocation}];
        }
    }];
}

- (void)didTapDoneButton:(id)sender {
     UIViewController* controller = [RNFileViewer topViewController];
    typeof(self) __weak weakSelf = self;
    [[RNFileViewer topViewController] dismissViewControllerAnimated:YES completion:^{
        [weakSelf sendEventWithName:DISMISS_EVENT body: @{@"id": ((CustomQLViewController*)controller).invocation}];
    }];
 }

- (void)didTapSendButton:(id)sender {
    typeof(self) __weak weakSelf = self;
    [[RNFileViewer topViewController] dismissViewControllerAnimated:YES completion:^{
        if (weakSelf.hasListeners) {
            [weakSelf sendEventWithName:SEND_EVENT body: @{@"id": weakSelf.invocation}];
        }
    }];
}

@end
