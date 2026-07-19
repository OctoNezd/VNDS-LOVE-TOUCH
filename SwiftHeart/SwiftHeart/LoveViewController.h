//
//  LoveViewController.h
//  SwiftHeart
//
//  Objective-C header for the Love2D view controller.
//  This header uses only Objective-C types so it can be included
//  from the Swift bridging header.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Called when Love2D exits cleanly (love.event.quit without restart).
typedef void (^LoveQuitHandler)(void);

/// A UIViewController that runs a Love2D game inside its view.
/// The game is loaded from the path provided at initialisation time.
@interface LoveViewController : UIViewController

/// Designated initialiser.
/// @param gamePath   Absolute path to the .love file (or game directory) to run.
/// @param extraArgs  Additional command-line arguments passed to Love2D after the
///                   game path (e.g. @[@"--flag", @"value"]).  May be empty.
/// @param onQuit     Block invoked on the main thread when the game exits without restarting.
- (instancetype)initWithGamePath:(NSString *)gamePath
                       extraArgs:(NSArray<NSString *> *)extraArgs
                          onQuit:(LoveQuitHandler)onQuit NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
