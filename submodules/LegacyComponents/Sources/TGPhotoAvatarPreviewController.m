#import "TGPhotoAvatarPreviewController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"

#import "PGPhotoEditor.h"
#import "PGPhotoEditorView.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>

#import "TGPhotoEditorController.h"
#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoAvatarCropView.h"

#import "TGMediaPickerGalleryVideoScrubber.h"
#import "TGModernGalleryVideoView.h"

const CGFloat TGPhotoAvatarPreviewPanelSize = 96.0f;
const CGFloat TGPhotoAvatarPreviewLandscapePanelSize = TGPhotoAvatarPreviewPanelSize + 40.0f;

@interface TGPhotoAvatarPreviewController ()
{
    bool _appeared;
    UIImage *_imagePendingLoad;
    UIView *_snapshotView;
    UIImage *_snapshotImage;
    
    UIView *_wrapperView;
    
    TGPhotoAvatarCropView *_cropView;
        
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    UIView *_portraitWrapperBackgroundView;
    UIView *_landscapeWrapperBackgroundView;
    
    TGMediaPickerGalleryVideoScrubber *_scrubberView;
    UIView *_dotImageView;
    UIView *_videoAreaView;
    UIView *_flashView;
    UIView *_portraitToolControlView;
    UIView *_landscapeToolControlView;
    UILabel *_coverLabel;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoAvatarPreviewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView scrubberView:(TGMediaPickerGalleryVideoScrubber *)scrubberView dotImageView:(UIView *)dotImageView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        _scrubberView = scrubberView;
        
        _dotImageView = dotImageView;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
//    [self.view addSubview:_previewView];
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    __weak TGPhotoAvatarPreviewController *weakSelf = self;
    void(^interactionBegan)(void) = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        self.controlVideoPlayback(false);
    };
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
        
        self.controlVideoPlayback(true);
    };
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    _cropView = [[TGPhotoAvatarCropView alloc] initWithOriginalSize:photoEditor.originalSize screenSize:[self referenceViewSize]];
    [_cropView setCropRect:photoEditor.cropRect];
    [_cropView setCropOrientation:photoEditor.cropOrientation];
    [_cropView setCropMirrored:photoEditor.cropMirrored];
    _cropView.tapped = ^{
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf.togglePlayback != nil)
             strongSelf.togglePlayback();
    };
    _cropView.croppingChanged = ^
    {
        __strong TGPhotoAvatarPreviewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        photoEditor.cropRect = strongSelf->_cropView.cropRect;
        photoEditor.cropOrientation = strongSelf->_cropView.cropOrientation;
        photoEditor.cropMirrored = strongSelf->_cropView.cropMirrored;
        
        if (strongSelf.croppingChanged != nil)
            strongSelf.croppingChanged();
    };
    if (_snapshotView != nil)
    {
        [_cropView setSnapshotView:_snapshotView];
        _snapshotView = nil;
    }
    else if (_snapshotImage != nil)
    {
        [_cropView setSnapshotImage:_snapshotImage];
        _snapshotImage = nil;
    }
    _cropView.interactionBegan = interactionBegan;
    _cropView.interactionEnded = interactionEnded;
    [_wrapperView addSubview:_cropView];
    
    if (self.item.isVideo) {
        _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        _portraitToolsWrapperView.alpha = 0.0f;
        [_wrapperView addSubview:_portraitToolsWrapperView];
        
        _portraitWrapperBackgroundView = [[UIView alloc] initWithFrame:_portraitToolsWrapperView.bounds];
        _portraitWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _portraitWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _portraitWrapperBackgroundView.userInteractionEnabled = false;
        [_portraitToolsWrapperView addSubview:_portraitWrapperBackgroundView];

        _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        _landscapeToolsWrapperView.alpha = 0.0f;
        [_wrapperView addSubview:_landscapeToolsWrapperView];
        
        _landscapeWrapperBackgroundView = [[UIView alloc] initWithFrame:_landscapeToolsWrapperView.bounds];
        _landscapeWrapperBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _landscapeWrapperBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        _landscapeWrapperBackgroundView.userInteractionEnabled = false;
        [_landscapeToolsWrapperView addSubview:_landscapeWrapperBackgroundView];
        
        _videoAreaView = [[UIView alloc] init];
        [self.view insertSubview:_videoAreaView belowSubview:_wrapperView];
        
        [_portraitToolsWrapperView addSubview:_scrubberView];
        
        _flashView = [[UIView alloc] init];
        _flashView.alpha = 0.0;
        _flashView.backgroundColor = [UIColor whiteColor];
        _flashView.userInteractionEnabled = false;
        [_videoAreaView addSubview:_flashView];
        
        _coverLabel = [[UILabel alloc] init];
        _coverLabel.alpha = 0.7f;
        _coverLabel.backgroundColor = [UIColor clearColor];
        _coverLabel.font = TGSystemFontOfSize(14.0f);
        _coverLabel.textColor = [UIColor whiteColor];
        _coverLabel.text = TGLocalized(@"PhotoEditor.SelectCoverFrame");
        [_coverLabel sizeToFit];
        [_portraitToolsWrapperView addSubview:_coverLabel];
        
        [_wrapperView addSubview:_dotImageView];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.photoEditor.additionalOutputs = @[_cropView.fullPreviewView];
    
    if (_appeared)
        return;
    
    if (self.initialAppearance && self.skipTransitionIn)
    {
        [self _finishedTransitionInWithView:nil];
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
    }
    else
    {
        [self transitionIn];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _appeared = true;
    
    if (_imagePendingLoad != nil)
        [_cropView setImage:_imagePendingLoad];

    [self transitionIn];
}

- (BOOL)shouldAutorotate
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && !_cropView.isTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared && !_cropView.isTracking && !_cropView.isAnimating;
}

#pragma mark -

- (void)setImage:(UIImage *)image
{
    if (_dismissing && !_switching)
        return;
        
    if (!_appeared)
    {
        _imagePendingLoad = image;
        return;
    }
        
    [_cropView setImage:image];
}

- (void)setSnapshotImage:(UIImage *)snapshotImage
{
    _snapshotImage = snapshotImage;
    [_cropView _replaceSnapshotImage:snapshotImage];
}

- (void)setSnapshotView:(UIView *)snapshotView
{
    _snapshotView = snapshotView;
}

#pragma mark - Transition

- (void)transitionIn
{
    _scrubberView.layer.rasterizationScale = [UIScreen mainScreen].scale;
    _scrubberView.layer.shouldRasterize = true;
    
    [_cropView animateTransitionIn];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        _scrubberView.layer.shouldRasterize = false;
    }];
        
    switch (self.effectiveOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
            
        default:
        {
            _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f);
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
            break;
    }
}

- (void)transitionOutSwitching:(bool)switching completion:(void (^)(void))completion
{
    if (switching) {
        _dismissing = true;
    }
    
    [_cropView animateTransitionOutSwitching:switching];
    self.photoEditor.additionalOutputs = @[];
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.touchedUp = nil;
    previewView.touchedDown = nil;
    previewView.tapped = nil;
    previewView.interactionEnded = nil;
    
    [_videoAreaView.superview bringSubviewToFront:_videoAreaView];
    
    switch (self.effectiveOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        default:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f);
            } completion:nil];
        }
            break;
    }
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        _videoAreaView.alpha = 0.0f;
        _dotImageView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
    
    self.photoEditor.additionalOutputs = @[];
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    [previewView prepareForTransitionOut];
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    
    if (saving && CGRectIsNull(targetFrame))
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = previewView.frame;
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2, (self.view.frame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        if (parentView != nil)
            [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    }
    
    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    
    NSMutableArray *animations = [NSMutableArray arrayWithArray:@[ previewAnimation, previewAlphaAnimation ]];
    if (snapshotAnimation != nil)
        [animations addObject:snapshotAnimation];
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [snapshotView removeFromSuperview];
         
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:animations];
    
    if (snapshotAnimation != nil)
        [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAlphaAnimation forKey:@"alpha"];
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {
        [self.view insertSubview:transitionView atIndex:0];
    } else {
        [transitionView removeFromSuperview];
    }
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = false;
    [previewView performTransitionInIfNeeded];
    
    [_cropView transitionInFinishedFromCamera:(self.fromCamera && self.initialAppearance)];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    [photoEditor processAnimated:false completion:nil];
}

- (void)_finishedTransitionIn
{
//    [_cropView animateTransitionIn];
    [_cropView transitionInFinishedFromCamera:true];
    
    self.finishedTransitionIn();
    self.finishedTransitionIn = nil;
}

- (void)prepareForCustomTransitionOut
{
    [_cropView hideImageForCustomTransition];
    [_cropView animateTransitionOutSwitching:false];
    
    _previewView.hidden = true;
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        _videoAreaView.alpha = 0.0f;
        _dotImageView.alpha = 0.0f;
    } completion:nil];
}

- (CGRect)transitionOutReferenceFrame
{
    return [_cropView cropRectFrameForView:self.view];
}

- (UIView *)transitionOutReferenceView
{
    return [_cropView cropSnapshotView];
}

- (id)currentResultRepresentation
{
    return [_cropView cropSnapshotView];
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return sourceFrame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGRect frame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    return frame;
}

- (void)updateToolViews
{
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([self inFormSheet] || TGIsPad())
    {
        _landscapeToolsWrapperView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    CGFloat panelSize = UIInterfaceOrientationIsPortrait(orientation) ? TGPhotoAvatarPreviewPanelSize : TGPhotoAvatarPreviewLandscapePanelSize;
    
    CGFloat panelToolbarPortraitSize = panelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = panelSize + TGPhotoEditorToolbarSize;
        
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:self.hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);

            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);

            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);

            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.top, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _portraitToolsWrapperView.frame = CGRectMake((screenSide - referenceSize.width) / 2, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _portraitToolControlView.frame = CGRectMake(0, 0, referenceSize.width, panelSize);
            }];
             
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - TGPhotoAvatarPreviewPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _coverLabel.frame = CGRectMake(floor((_portraitToolsWrapperView.frame.size.width - _coverLabel.frame.size.width) / 2.0), CGRectGetMaxY(_scrubberView.frame) + 6.0, _coverLabel.frame.size.width, _coverLabel.frame.size.height);
        }
            break;
    }
}

- (void)updatePreviewView
{
    CGSize referenceSize = [self referenceViewSize];
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (_dismissing || previewView.superview != self.view)
        return;
        
    CGRect containerFrame = [TGPhotoAvatarPreviewController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    [UIView performWithoutAnimation:^
    {
        _videoAreaView.frame = _previewView.frame;
        _flashView.frame = _videoAreaView.bounds;
    }];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    orientation = [self effectiveOrientation:orientation];
    
    CGSize referenceSize = [self referenceViewSize];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        [_cropView updateCircleImageWithReferenceSize:referenceSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - self.view.frame.size.height) / 2, (screenSide - self.view.frame.size.width) / 2, (screenSide + self.view.frame.size.height) / 2, (screenSide + self.view.frame.size.width) / 2);
        
    if (_dismissing)
        return;
    
    [self updatePreviewView];
    [self updateToolViews];
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:0.0f hasOnScreenNavigation:self.hasOnScreenNavigation];
    containerFrame = CGRectOffset(containerFrame, screenEdges.left, screenEdges.top);
    
    CGFloat shortSide = MIN(referenceSize.width, referenceSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    _cropView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - diameter) / 2, containerFrame.origin.y + (containerFrame.size.height - diameter) / 2, diameter, diameter);
}

- (TGPhotoEditorTab)availableTabs
{
    return TGPhotoEditorRotateTab | TGPhotoEditorMirrorTab | TGPhotoEditorPaintTab | TGPhotoEditorToolsTab;
}

- (TGPhotoEditorTab)activeTab
{
    return TGPhotoEditorNoneTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    id<TGMediaEditAdjustments> adjustments = [self.photoEditor exportAdjustments];
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    
    if (adjustments.toolsApplied)
        tabs |= TGPhotoEditorToolsTab;
    if (adjustments.hasPainting)
        tabs |= TGPhotoEditorPaintTab;
    
    return tabs;
}

- (void)handleTabAction:(TGPhotoEditorTab)tab
{
    switch (tab)
    {
        case TGPhotoEditorRotateTab:
        {
            [self rotate];
        }
            break;
            
        case TGPhotoEditorMirrorTab:
        {
            [self mirror];
        }
            break;
                
        default:
            break;
    }
}

#pragma mark - Cropping

- (void)rotate {
    [_cropView rotate90DegreesCCWAnimated:true];
}

- (void)mirror {
    [_cropView mirror];
}

- (void)beginScrubbing:(bool)flash
{
    if (flash)
        _coverLabel.alpha = 1.0f;
}

- (void)endScrubbing:(bool)flash completion:(bool (^)(void))completion
{
    if (flash) {
        [UIView animateWithDuration:0.12 animations:^{
            _flashView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 animations:^{
                _flashView.alpha = 0.0f;
            } completion:^(BOOL finished) {
                TGDispatchAfter(1.0, dispatch_get_main_queue(), ^{
                    if (completion()) {
                        [UIView animateWithDuration:0.2 animations:^{
                            _coverLabel.alpha = 0.7f;
                        }];
                        
                        self.controlVideoPlayback(true);
                    }
                });
            }];
        }];
    } else {
        TGDispatchAfter(1.32, dispatch_get_main_queue(), ^{
            if (completion()) {
                [UIView animateWithDuration:0.2 animations:^{
                    _coverLabel.alpha = 0.7f;
                }];
                
                self.controlVideoPlayback(true);
            }
        });
    }
}

@end