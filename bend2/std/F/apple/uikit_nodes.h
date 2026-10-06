#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface FCameraFixtureScene : UIView
@end
@implementation FCameraFixtureScene
- (void)drawRect:(CGRect)rect {
  CGContextRef c=UIGraphicsGetCurrentContext();CGFloat w=rect.size.width,h=rect.size.height;
  NSArray* colors=@[(id)[UIColor colorWithRed:0.42 green:0.66 blue:0.78 alpha:1].CGColor,(id)[UIColor colorWithRed:0.88 green:0.90 blue:0.81 alpha:1].CGColor];CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();CGGradientRef sky=CGGradientCreateWithColors(space,(__bridge CFArrayRef)colors,NULL);CGContextDrawLinearGradient(c,sky,CGPointZero,CGPointMake(0,h),0);CGGradientRelease(sky);CGColorSpaceRelease(space);
  CGContextSetFillColorWithColor(c,[UIColor colorWithRed:0.99 green:0.91 blue:0.68 alpha:1].CGColor);CGContextFillEllipseInRect(c,CGRectMake(w*.66,h*.17,w*.14,w*.14));
  CGContextSetFillColorWithColor(c,[UIColor colorWithRed:0.26 green:0.46 blue:0.47 alpha:1].CGColor);CGContextMoveToPoint(c,0,h*.7);CGContextAddCurveToPoint(c,w*.2,h*.24,w*.36,h*.36,w*.55,h*.64);CGContextAddCurveToPoint(c,w*.76,h*.36,w*.84,h*.44,w,h*.62);CGContextAddLineToPoint(c,w,h);CGContextAddLineToPoint(c,0,h);CGContextFillPath(c);
  CGContextSetFillColorWithColor(c,[UIColor colorWithRed:0.12 green:0.31 blue:0.32 alpha:1].CGColor);CGContextMoveToPoint(c,0,h*.84);CGContextAddCurveToPoint(c,w*.35,h*.6,w*.7,h*.95,w,h*.7);CGContextAddLineToPoint(c,w,h);CGContextAddLineToPoint(c,0,h);CGContextFillPath(c);
}
@end

@interface FCameraFixtureView : UIView
@property FCameraFixtureScene* scene;
@property UIView* flash;
@property BOOL live;
@property BOOL captured;
- (void)live:(BOOL)live captured:(BOOL)captured;
@end
@implementation FCameraFixtureView
- (instancetype)init { if((self=[super init])){self.clipsToBounds=YES;self.layer.cornerRadius=16;self.scene=[FCameraFixtureScene new];[self addSubview:self.scene];self.flash=[UIView new];self.flash.backgroundColor=UIColor.whiteColor;self.flash.alpha=0;[self addSubview:self.flash];self.isAccessibilityElement=YES;}return self; }
- (void)layoutSubviews { [super layoutSubviews];self.scene.bounds=CGRectMake(0,0,self.bounds.size.width*1.1,self.bounds.size.height*1.1);self.scene.center=CGPointMake(CGRectGetMidX(self.bounds),CGRectGetMidY(self.bounds));self.flash.frame=self.bounds;[self.scene setNeedsDisplay]; }
- (void)live:(BOOL)live captured:(BOOL)captured {
  BOOL moving=live&&!UIAccessibilityIsReduceMotionEnabled();
  if(live!=self.live||moving!=([self.scene.layer animationForKey:@"mock-viewfinder"]!=nil)){self.live=live;if(moving){CABasicAnimation* pan=[CABasicAnimation animationWithKeyPath:@"transform.translation.x"];pan.fromValue=@(-4);pan.toValue=@4;pan.duration=3;pan.autoreverses=YES;pan.repeatCount=HUGE_VALF;pan.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];[self.scene.layer addAnimation:pan forKey:@"mock-viewfinder"];}
    else {CALayer* shown=self.scene.layer.presentationLayer;if(shown)self.scene.layer.transform=shown.transform;[self.scene.layer removeAnimationForKey:@"mock-viewfinder"];}}
  if(captured&&!self.captured){self.flash.alpha=UIAccessibilityIsReduceMotionEnabled()?0:0.8;[UIView animateWithDuration:0.18 animations:^{self.flash.alpha=0;}];}self.captured=captured;
}
@end


@interface FUIKitNode : UIView <UITextViewDelegate>
@property NSDictionary* node;
@property UIView* leaf;
@property UIVisualEffectView* glass;
@property NSString* sent;
@property id generation;
@property BOOL visibilitySet;
@property BOOL presented;
@property (copy) void (^emit)(NSDictionary*);
- (void)update:(NSDictionary*)node;
@end
@implementation FUIKitNode
- (void)textViewDidChange:(UITextView*)field {
  self.sent = field.text;
  self.emit(@{@"action":@"input", @"name":self.node[@"action"] ?: @"", @"value":field.text});
}
- (void)update:(NSDictionary*)node {
  self.node = node;
  NSString* type = node[@"type"], *text = node[@"text"] ?: @"";
  self.accessibilityIdentifier = node[@"id"] ?: @"";
  self.backgroundColor = [node[@"canvas"] isEqual:@YES] ? UIColor.systemGroupedBackgroundColor : UIColor.clearColor;
  if ([node[@"glass"] boolValue]) {
    if (!self.glass) { self.glass = [[UIVisualEffectView alloc] initWithEffect:nil]; self.glass.layer.cornerRadius = 24; self.glass.clipsToBounds = YES; [self insertSubview:self.glass atIndex:0]; }
    if (UIAccessibilityIsReduceTransparencyEnabled()) { self.glass.effect = nil; self.glass.backgroundColor = UIColor.secondarySystemBackgroundColor; }
    else if (@available(iOS 26.0, *)) { self.glass.effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular]; }
    else self.glass.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
  } else { [self.glass removeFromSuperview]; self.glass = nil; }
  if ([type isEqual:@"text"]) {
    if (!self.leaf) { UILabel* label = [UILabel new]; label.numberOfLines = 0; label.adjustsFontForContentSizeCategory = YES; self.leaf = label; [self addSubview:label]; }
    UILabel* label = (UILabel*)self.leaf; label.text = text;
    label.font = [UIFont preferredFontForTextStyle:[node[@"small"] boolValue] ? UIFontTextStyleCaption1 : [node[@"heading"] boolValue] ? UIFontTextStyleHeadline : UIFontTextStyleBody];
    label.textColor = [node[@"secondary"] boolValue] ? UIColor.secondaryLabelColor : UIColor.labelColor;
  } else if ([type isEqual:@"button"]) {
    if (!self.leaf) {
      UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem]; __weak FUIKitNode* weak = self;
      [button addAction:[UIAction actionWithHandler:^(UIAction* action) { FUIKitNode* n = weak; n.emit(@{@"action":@"click", @"name":n.node[@"action"] ?: @""}); }] forControlEvents:UIControlEventTouchUpInside];
      self.leaf = button; [self addSubview:button];
    }
    UIButton* button = (UIButton*)self.leaf; UIButtonConfiguration* config;
    if (@available(iOS 26.0, *)) config = UIAccessibilityIsReduceTransparencyEnabled() ? [UIButtonConfiguration borderedButtonConfiguration] : ([node[@"prominent"] boolValue] ? [UIButtonConfiguration prominentGlassButtonConfiguration] : [UIButtonConfiguration glassButtonConfiguration]);
    else config = [node[@"prominent"] boolValue] ? [UIButtonConfiguration filledButtonConfiguration] : [UIButtonConfiguration borderedButtonConfiguration];
    config.title = node[@"symbol"] ? nil : text; config.image = node[@"symbol"] ? [UIImage systemImageNamed:node[@"symbol"]] : nil;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    button.configuration = config; button.enabled = ![node[@"disabled"] boolValue]; button.accessibilityLabel = text; button.accessibilityIdentifier = node[@"id"] ?: @"";
  } else if ([type isEqual:@"input"]) {
    if (!self.leaf) { UITextView* field = [UITextView new]; field.delegate = self; field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody]; field.adjustsFontForContentSizeCategory = YES; field.backgroundColor = UIColor.clearColor; self.leaf = field; [self addSubview:field]; }
    UITextView* field = (UITextView*)self.leaf; field.accessibilityLabel = text;
    NSString* value = node[@"value"] ?: @""; id generation = node[@"generation"];
    if (!field.isFirstResponder || ![generation isEqual:self.generation] || [value isEqual:self.sent]) { if (![field.text isEqual:value]) field.text = value; self.sent = value; }
    self.generation = generation;
  } else if ([type isEqual:@"scroll"]) {
    if (!self.leaf) { self.leaf = [UIScrollView new]; [self addSubview:self.leaf]; }
  } else if ([type isEqual:@"mockImage"]) {
    if (!self.leaf) { self.leaf=[FCameraFixtureView new]; [self addSubview:self.leaf]; }
    FCameraFixtureView* image=(FCameraFixtureView*)self.leaf;image.accessibilityLabel=text;
    [image live:[node[@"cameraLive"] isEqual:@YES] captured:[node[@"capture"] isEqual:@YES]];
  }
  if(node[@"motion"]){
    BOOL visible=[node[@"visible"] isEqual:@YES];BOOL changed=self.visibilitySet&&visible!=self.presented;
    self.presented=visible;self.userInteractionEnabled=visible;CGAffineTransform hidden=UIAccessibilityIsReduceMotionEnabled()?CGAffineTransformIdentity:CGAffineTransformMakeScale(0.84,0.84);
    if(changed){[UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled()?0.12:0.3 delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{self.alpha=visible?1:0;self.transform=visible?CGAffineTransformIdentity:hidden;} completion:nil];}
    else if(!self.visibilitySet){self.alpha=visible?1:0;self.transform=visible?CGAffineTransformIdentity:hidden;}self.visibilitySet=YES;
  } else if(self.visibilitySet) { [self.layer removeAllAnimations];self.alpha=1;self.transform=CGAffineTransformIdentity;self.userInteractionEnabled=YES;self.visibilitySet=NO; }
}
@end

@interface FUIKitController : UIViewController
@property NSDictionary* packet;
@property UIScrollView* scroll;
@property NSMutableDictionary<NSString*,FUIKitNode*>* nodes;
@property NSMutableSet* used;
@property (copy) void (^emit)(NSDictionary*);
- (void)apply:(NSDictionary*)packet;
@end
@implementation FUIKitController
- (void)viewDidLoad {
  [super viewDidLoad]; self.view.backgroundColor = UIColor.systemBackgroundColor; self.nodes = [NSMutableDictionary dictionary];
  self.scroll=[UIScrollView new];self.scroll.translatesAutoresizingMaskIntoConstraints=NO;self.scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;[self.view addSubview:self.scroll];
  [NSLayoutConstraint activateConstraints:@[[self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],[self.scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],[self.scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]]];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(accessibilityChanged:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(accessibilityChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(accessibilityChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
}
- (void)accessibilityChanged:(NSNotification*)notification { if (self.packet) [self apply:self.packet]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (CGFloat)height:(NSDictionary*)n width:(CGFloat)width {
  CGFloat pad = [n[@"padding"] doubleValue], inside = MAX(1,width-2*pad), gap = n[@"spacing"] ? [n[@"spacing"] doubleValue] : 12;
  if ([n[@"flex"] boolValue]) return 0;
  if (n[@"height"]) return [n[@"height"] doubleValue];
  NSString* type=n[@"type"]; NSArray* children=n[@"children"] ?: @[];
  if ([type isEqual:@"text"]) {
    UIFont* font=[UIFont preferredFontForTextStyle:[n[@"small"] boolValue]?UIFontTextStyleCaption1:[n[@"heading"] boolValue]?UIFontTextStyleHeadline:UIFontTextStyleBody];
    return ceil([(n[@"text"] ?: @"") boundingRectWithSize:CGSizeMake(inside,CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:font} context:nil].size.height)+2*pad;
  }
  if ([type isEqual:@"input"]) return 84+2*pad;
  if ([type isEqual:@"button"]) return 44+2*pad;
  if ([type isEqual:@"spacer"]) return 0;
  if ([type isEqual:@"hstack"]) { CGFloat h=0,w=MAX(1,(inside-gap*MAX(0,(NSInteger)children.count-1))/MAX(1,children.count)); for(NSDictionary* c in children)h=MAX(h,[self height:c width:w]); return h+2*pad; }
  CGFloat h=0;for(NSDictionary* c in children)h+=[self height:c width:inside];return h+gap*MAX(0,(NSInteger)children.count-1)+2*pad;
}
- (void)render:(NSDictionary*)n path:(NSString*)path parent:(UIView*)parent frame:(CGRect)frame {
  NSString* key=[path stringByAppendingFormat:@":%@",n[@"type"]]; [self.used addObject:key];
  FUIKitNode* view=self.nodes[key]; if(!view){view=[FUIKitNode new];view.emit=self.emit;self.nodes[key]=view;}
  if(view.superview!=parent)[parent addSubview:view]; view.bounds=CGRectMake(0,0,frame.size.width,frame.size.height);view.center=CGPointMake(CGRectGetMidX(frame),CGRectGetMidY(frame));view.clipsToBounds=YES;[view update:n];view.glass.frame=view.bounds;
  CGFloat pad=[n[@"padding"] doubleValue];CGRect box=CGRectInset(view.bounds,pad,pad);view.leaf.frame=box;
  NSArray* children=n[@"children"] ?: @[];NSString* type=n[@"type"];CGFloat gap=n[@"spacing"]?[n[@"spacing"] doubleValue]:12;
  if([type isEqual:@"overlay"]){
    for(NSUInteger i=0;i<children.count;i++){NSDictionary* c=children[i];CGFloat w=c[@"width"]?MIN(box.size.width,[c[@"width"] doubleValue]):box.size.width;CGFloat h=c[@"height"]?MIN(box.size.height,[c[@"height"] doubleValue]):box.size.height;[self render:c path:[path stringByAppendingFormat:@".%lu",(unsigned long)i] parent:view frame:CGRectMake([n[@"alignment"] isEqual:@"center"] ? CGRectGetMidX(box)-w/2 : CGRectGetMaxX(box)-w,[n[@"alignment"] isEqual:@"center"] ? CGRectGetMidY(box)-h/2 : CGRectGetMaxY(box)-h,w,h)];}return;
  }
  if([type isEqual:@"scroll"]){UIScrollView* scroll=(UIScrollView*)view.leaf;CGFloat y=0;for(NSUInteger i=0;i<children.count;i++){NSDictionary* c=children[i];CGFloat h=[self height:c width:box.size.width];[self render:c path:[path stringByAppendingFormat:@".%lu",(unsigned long)i] parent:scroll frame:CGRectMake(0,y,box.size.width,h)];y+=h+gap;}scroll.contentSize=CGSizeMake(box.size.width,MAX(0,y-gap));return;}
  BOOL horizontal=[type isEqual:@"hstack"];CGFloat total=0;NSUInteger flexible=0;NSMutableArray* sizes=[NSMutableArray array];
  for(NSDictionary* c in children){BOOL flex=[c[@"type"] isEqual:@"spacer"]||(!horizontal&&[c[@"flex"] boolValue]);CGFloat size=flex?0:horizontal?([c[@"type"] isEqual:@"button"]?([c[@"symbol"] length]?44:MAX(72,[(c[@"text"] ?: @"") sizeWithAttributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]}].width+28)):MAX(40,(box.size.width-gap*MAX(0,(NSInteger)children.count-1))/MAX(1,children.count))):[self height:c width:box.size.width];[sizes addObject:@(size)];total+=size;if(flex)flexible++;}
  CGFloat extent=horizontal?box.size.width:box.size.height;CGFloat room=MAX(0,extent-total-gap*MAX(0,(NSInteger)children.count-1));CGFloat position=horizontal?box.origin.x:box.origin.y;
  for(NSUInteger i=0;i<children.count;i++){NSDictionary* c=children[i];BOOL flex=[c[@"type"] isEqual:@"spacer"]||(!horizontal&&[c[@"flex"] boolValue]);CGFloat size=flex?room/MAX(1,flexible):[sizes[i] doubleValue];CGRect f=horizontal?CGRectMake(position,box.origin.y,size,box.size.height):CGRectMake(box.origin.x,position,box.size.width,size);[self render:c path:[path stringByAppendingFormat:@".%lu",(unsigned long)i] parent:view frame:f];position+=size+gap;}
}
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews]; if(!self.packet)return;
  self.used=[NSMutableSet set]; CGRect box=CGRectMake(0,0,self.scroll.bounds.size.width,MAX(self.scroll.bounds.size.height,[self height:self.packet[@"tree"] width:self.scroll.bounds.size.width]));
  self.scroll.contentSize=box.size;[self render:self.packet[@"tree"] path:@"root" parent:self.scroll frame:box];
  for(FUIKitNode* node in self.nodes.allValues)if(node.leaf.isFirstResponder)[self.scroll scrollRectToVisible:[node.leaf convertRect:node.leaf.bounds toView:self.scroll] animated:NO];
  for(NSString* key in self.nodes.allKeys)if(![self.used containsObject:key]){[self.nodes[key] removeFromSuperview];[self.nodes removeObjectForKey:key];}
}
- (void)apply:(NSDictionary*)packet {
  [self loadViewIfNeeded];self.packet=packet;self.title=packet[@"title"];
  NSMutableArray* toolbar=[NSMutableArray array];__weak FUIKitController* weak=self;
  for(NSDictionary* item in packet[@"toolbar"]){UIBarButtonItem* button=[[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithHandler:^(UIAction* action){weak.emit(@{@"action":@"click",@"name":item[@"action"] ?: @""});}] menu:nil];button.image=[UIImage systemImageNamed:item[@"symbol"] ?: @"circle"];button.accessibilityLabel=item[@"text"];[toolbar addObject:button];}
  self.navigationItem.rightBarButtonItems=toolbar;
  NSDictionary* leading=packet[@"leading"];
  if([leading isKindOfClass:NSDictionary.class]){UIBarButtonItem* item=[[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithHandler:^(UIAction* action){weak.emit(@{@"action":@"click",@"name":leading[@"action"] ?: @""});}] menu:nil];item.title=leading[@"text"];item.accessibilityLabel=leading[@"text"];self.navigationItem.leftBarButtonItem=item;}else self.navigationItem.leftBarButtonItem=nil;
  if([packet[@"dismissKeyboard"] isEqual:@YES])[self.view endEditing:YES];
  [self.view setNeedsLayout];[self.view layoutIfNeeded];
  if([packet[@"alert"] isEqual:@YES]&&!self.presentedViewController){UIAlertController* alert=[UIAlertController alertControllerWithTitle:packet[@"alertTitle"] message:packet[@"alertMessage"] preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction* a){weak.emit(@{@"action":@"click",@"name":packet[@"cancelAction"] ?: @""});}]];[alert addAction:[UIAlertAction actionWithTitle:packet[@"confirmText"] ?: @"Confirm" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){weak.emit(@{@"action":@"click",@"name":packet[@"confirmAction"] ?: @""});}]];[self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];}
}
@end

@interface FUIKitHost : NSObject
+ (UIViewController*)controllerWithAction:(void (^)(NSDictionary*))action;
+ (void)apply:(NSDictionary*)packet;
@end
@implementation FUIKitHost
static FUIKitController* f_uikit_controller;
+ (UIViewController*)controllerWithAction:(void (^)(NSDictionary*))action { f_uikit_controller=[FUIKitController new];f_uikit_controller.emit=action;return [[UINavigationController alloc] initWithRootViewController:f_uikit_controller]; }
+ (void)apply:(NSDictionary*)packet { [f_uikit_controller apply:packet]; }
@end
