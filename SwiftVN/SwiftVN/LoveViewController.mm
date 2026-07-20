//
//  LoveViewController.mm
//  SwiftVN
//
//  Runs a Love2D game inside a UIViewController.
//
//  SDL3 on iOS requires all UIKit access (window creation, event handling,
//  etc.) to happen on the main thread.  The Love/SDL game loop is therefore
//  run on the main thread via SDL_RunApp().
//
//  SDL_RunApp() with SDL_MAIN_HANDLED calls the supplied mainFunction
//  directly on the calling thread without invoking UIApplicationMain again.
//  We call it from the main thread (already guaranteed by viewDidAppear:).
//
//  IMPORTANT: SDL_RunApp blocks until the game exits.  While the game is
//  running the main run loop is driven by SDL/Love internally (SDL pumps
//  UIKit events via its own CADisplayLink).  When the game exits we call
//  the onQuit block which SwiftUI uses to pop the game view.
//
//  Native iOS dialog bridge
//  ────────────────────────
//  Because Love runs on the main thread we cannot simply dispatch_async a
//  UIAlertController and wait on a semaphore (the main thread would be
//  blocked and UIKit would never deliver the tap).  Instead we use the same
//  technique SDL itself uses for showMessageBox on iOS: present the alert,
//  then spin a nested CFRunLoop until the user makes a choice.  UIKit
//  continues to process touch events inside the nested run loop, so the
//  alert is fully interactive.
//

#import "LoveViewController.h"

// C functions implemented in SlotBridge.swift via @_silgen_name.
extern "C" void    swiftvn_request_slot(const char *dirPath, bool isSave);
extern "C" bool    swiftvn_poll_slot_result(int32_t *outSlot);

#include "common/version.h"
#include "common/runtime.h"
#include "common/Variant.h"
#include "modules/love/love.h"

// SDL_MAIN_HANDLED: include SDL_main.h for SDL_SetMainReady / SDL_RunApp
// without letting it redefine main().
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>
#include <SDL3/SDL.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

#include <string>
#include <vector>

// ---------------------------------------------------------------------------
// Native iOS dialog helpers
// ---------------------------------------------------------------------------

/// Present a UIAlertController on the main thread and block (via a nested
/// CFRunLoop) until the user dismisses it.  Returns the index of the tapped
/// action (0-based), or -1 if the alert was cancelled / dismissed without a
/// choice.
///
/// @param title        Alert title.
/// @param message      Alert message (may be nil).
/// @param actions      Array of NSString button titles.
/// @param cancelTitle  Title of the cancel button (nil = no cancel button).
/// @param destructiveIndex  Index in @a actions that should be styled
///                          destructively, or -1 for none.
static NSInteger showNativeAlert(NSString *title,
                                 NSString * _Nullable message,
                                 NSArray<NSString *> *actions,
                                 NSString * _Nullable cancelTitle,
                                 NSInteger destructiveIndex)
{
    // This function must only be called from the main thread (Love runs on the
    // main thread, so this is always satisfied in normal operation).
    assert([NSThread isMainThread] && "showNativeAlert must be called on the main thread");

    __block NSInteger result = -1;
    __block BOOL done = NO;

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    // Regular action buttons
    for (NSUInteger i = 0; i < actions.count; i++) {
        UIAlertActionStyle style = (NSInteger)i == destructiveIndex
            ? UIAlertActionStyleDestructive
            : UIAlertActionStyleDefault;
        NSUInteger captured_i = i;
        UIAlertAction *action =
            [UIAlertAction actionWithTitle:actions[i]
                                     style:style
                                   handler:^(UIAlertAction *) {
                result = (NSInteger)captured_i;
                done = YES;
            }];
        [alert addAction:action];
    }

    // Optional cancel button
    if (cancelTitle) {
        UIAlertAction *cancel =
            [UIAlertAction actionWithTitle:cancelTitle
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *) {
                result = -1;
                done = YES;
            }];
        [alert addAction:cancel];
    }

    // On iPad, UIAlertControllerStyleActionSheet requires a source view/bar
    // button item.  Point it at the centre of the key window.
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
        }
        if (keyWindow) break;
    }
    if (keyWindow) {
        alert.popoverPresentationController.sourceView = keyWindow;
        alert.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(keyWindow.bounds),
                       CGRectGetMidY(keyWindow.bounds), 1, 1);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }

    // Find the topmost presented view controller to present from.
    UIViewController *presenter = keyWindow.rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;

    [presenter presentViewController:alert animated:YES completion:nil];

    // Spin a nested run loop until the user taps a button.
    // UIKit continues to deliver touch events inside this loop.
    while (!done) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
    }

    return result;
}

// ---------------------------------------------------------------------------
// Lua "swiftvn" module
// ---------------------------------------------------------------------------
//
// Exposed to Lua as the global table `swiftvn` (registered during Love
// boot via luaopen_swiftvn).
//
// API
// ───
//   swiftvn.showSaveDialog(dirPath, mode)
//
//     dirPath – absolute filesystem path to the game directory
//     mode    – "save" or "load"
//
//     Presents the native SwiftUI slot-picker sheet (non-blocking).
//     Poll swiftvn.pollSlotResult() each frame until it returns non-nil.
//
//   swiftvn.pollSlotResult() -> number | false | nil
//
//     Returns the chosen 1-based slot number when the user has picked,
//     false if the user cancelled, or nil if the sheet is still open.
//
//   swiftvn.showPauseMenu() -> string | nil
//
//     Shows the pause menu (blocking UIAlertController).  Returns one of:
//       "continue", "save", "load", "settings", "mainmenu"
//     or nil if dismissed without a choice.

static int l_showSaveDialog(lua_State *L)
{
    // Arg 1: directory path string (absolute filesystem path to the game dir)
    const char *dir_cstr = luaL_checkstring(L, 1);
    // Arg 2: mode string ("save" or "load")
    const char *mode_cstr = luaL_optstring(L, 2, "save");

    bool isSave = strcmp(mode_cstr, "save") == 0;

    // Present the SwiftUI sheet (non-blocking).
    swiftvn_request_slot(dir_cstr, isSave);
    return 0;
}

// swiftvn.pollSlotResult() -> number (slot) | false (cancelled) | nil (pending)
static int l_pollSlotResult(lua_State *L)
{
    int32_t chosen = 0;
    if (!swiftvn_poll_slot_result(&chosen)) {
        // Sheet still open
        lua_pushnil(L);
        return 1;
    }
    if (chosen <= 0) {
        // Cancelled
        lua_pushboolean(L, 0);
    } else {
        lua_pushinteger(L, (lua_Integer)chosen);
    }
    return 1;
}

static int l_showPauseMenu(lua_State *L)
{
    NSArray<NSString *> *actions = @[
        @"Continue",
        @"Save",
        @"Load",
        @"Settings",
        @"Main Menu"
    ];

    NSInteger chosen = showNativeAlert(@"Pause", nil, actions, nil, 4 /* Main Menu = destructive */);

    if (chosen < 0) {
        lua_pushnil(L);
        return 1;
    }

    // Map index → string token
    static const char *tokens[] = {
        "continue", "save", "load", "settings", "mainmenu"
    };
    if (chosen >= 0 && chosen < 5) {
        lua_pushstring(L, tokens[chosen]);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static const luaL_Reg swiftvn_funcs[] = {
    { "showSaveDialog",  l_showSaveDialog  },
    { "pollSlotResult",  l_pollSlotResult  },
    { "showPauseMenu",   l_showPauseMenu   },
    { nullptr, nullptr }
};

static int luaopen_swiftvn(lua_State *L)
{
    luaL_newlib(L, swiftvn_funcs);
    return 1;
}

// ---------------------------------------------------------------------------
// Love2D boot loop
// ---------------------------------------------------------------------------

static int love_preload(lua_State *L, lua_CFunction f, const char *name)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    lua_pushcfunction(L, f);
    lua_setfield(L, -2, name);
    lua_pop(L, 2);
    return 0;
}

enum DoneAction { DONE_QUIT, DONE_RESTART };

static DoneAction runlove(int argc, char **argv, int &retval,
                          love::Variant &restartvalue)
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    love_preload(L, luaopen_love_jitsetup, "love.jitsetup");
    lua_getglobal(L, "require");
    lua_pushstring(L, "love.jitsetup");
    lua_call(L, 1, 0);

    love_preload(L, luaopen_love, "love");

    // Register the swiftvn native module so Lua can require("swiftvn")
    love_preload(L, luaopen_swiftvn, "swiftvn");

    {
        lua_newtable(L);
        if (argc > 0) {
            lua_pushstring(L, argv[0]);
            lua_rawseti(L, -2, -2);
        }
        lua_pushstring(L, "embedded boot.lua");
        lua_rawseti(L, -2, -1);
        for (int i = 1; i < argc; i++) {
            lua_pushstring(L, argv[i]);
            lua_rawseti(L, -2, i);
        }
        lua_setglobal(L, "arg");
    }

    lua_getglobal(L, "require");
    lua_pushstring(L, "love");
    lua_call(L, 1, 1);

    {
        lua_pushboolean(L, 1);
        lua_setfield(L, -2, "_exe");
    }

    love::luax_pushvariant(L, restartvalue);
    lua_setfield(L, -2, "restart");
    restartvalue = love::Variant();

    lua_pop(L, 1);

    lua_getglobal(L, "require");
    lua_pushstring(L, "love.boot");
    lua_call(L, 1, 1);

    lua_newthread(L);
    lua_pushvalue(L, -2);
    int stackpos = lua_gettop(L);
    int nres;
    while (love::luax_resume(L, 0, &nres) == LUA_YIELD)
#if LUA_VERSION_NUM >= 504
        lua_pop(L, nres);
#else
        lua_pop(L, lua_gettop(L) - stackpos);
#endif

    retval = 0;
    DoneAction done = DONE_QUIT;

    int retidx = stackpos;
    if (!lua_isnoneornil(L, retidx)) {
        if (lua_type(L, retidx) == LUA_TSTRING &&
            strcmp(lua_tostring(L, retidx), "restart") == 0)
            done = DONE_RESTART;
        if (lua_isnumber(L, retidx))
            retval = (int)lua_tonumber(L, retidx);
        if (retidx < lua_gettop(L))
            restartvalue = love::luax_checkvariant(L, retidx + 1, false);
    }

    lua_close(L);
    return done;
}

// ---------------------------------------------------------------------------
// SDL_RunApp trampoline
// ---------------------------------------------------------------------------

struct LoveRunArgs {
    std::string              gamePath;
    std::vector<std::string> extraArgs;
    LoveQuitHandler          onQuit;
};

// Single global – we only ever run one Love instance at a time.
static LoveRunArgs *g_loveRunArgs = nullptr;

static int loveSDLMain(int /*argc*/, char ** /*argv*/)
{
    // g_loveRunArgs is the file-scope static set by startLove before this call.
    LoveRunArgs *args = g_loveRunArgs;

    // argv[0] = "swiftvn" (identifies the host app to the Lua game)
    // argv[1] = path to .love file
    // argv[2] = "--fused"  (skip Love's file-picker UI)
    // argv[3..] = any extra args passed by the caller
    std::string arg0 = "swiftvn";
    std::string arg1 = args->gamePath;
    std::string arg2 = "--fused";

    std::vector<char *> argv;
    argv.push_back(const_cast<char *>(arg0.c_str()));
    argv.push_back(const_cast<char *>(arg1.c_str()));
    argv.push_back(const_cast<char *>(arg2.c_str()));
    for (const std::string &extra : args->extraArgs)
        argv.push_back(const_cast<char *>(extra.c_str()));
    argv.push_back(nullptr);
    int argc = static_cast<int>(argv.size()) - 1; // exclude trailing nullptr

    int retval = 0;
    DoneAction done = DONE_QUIT;
    love::Variant restartvalue;

    do {
        done = runlove(argc, argv.data(), retval, restartvalue);
    } while (done == DONE_RESTART);

    // Copy the quit handler before freeing args.
    LoveQuitHandler onQuit = args->onQuit;
    delete args;
    g_loveRunArgs = nullptr;

    // Schedule the quit callback on the next main-queue iteration so that
    // the call stack fully unwinds (SDL cleanup, etc.) before SwiftUI
    // tries to tear down the LoveViewController.
    if (onQuit) {
        dispatch_async(dispatch_get_main_queue(), ^{
            onQuit();
        });
    }

    return retval;
}

// ---------------------------------------------------------------------------
// LoveViewController
// ---------------------------------------------------------------------------

@interface LoveViewController ()
@property (nonatomic, copy) NSString              *gamePath;
@property (nonatomic, copy) NSArray<NSString *>   *extraArgs;
@property (nonatomic, copy) LoveQuitHandler        onQuit;
@end

@implementation LoveViewController

- (instancetype)initWithGamePath:(NSString *)gamePath
                       extraArgs:(NSArray<NSString *> *)extraArgs
                          onQuit:(LoveQuitHandler)onQuit
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _gamePath  = [gamePath  copy];
        _extraArgs = [extraArgs copy];
        _onQuit    = [onQuit    copy];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self startLove];
}

- (void)startLove
{
    NSAssert([NSThread isMainThread], @"startLove must be called on the main thread");

    // SDL_SetMainReady() tells SDL's internal state that UIApplicationMain is
    // already running, so SDL's video subsystem will NOT call UIApplicationMain
    // again when it initialises.
    SDL_SetMainReady();

    // Set up the args struct that loveSDLMain will read from g_loveRunArgs.
    LoveRunArgs *args = new LoveRunArgs();
    args->gamePath = self.gamePath.UTF8String;
    for (NSString *extra in self.extraArgs)
        args->extraArgs.push_back(extra.UTF8String);
    args->onQuit   = self.onQuit;
    g_loveRunArgs  = args;

    // Call the Love boot loop directly on the main thread.
    // DO NOT use SDL_RunApp() – on iOS SDL_RunApp calls UIApplicationMain
    // which would crash with "There can only be one UIApplication instance."
    //
    // This call blocks until the game exits.  SDL drives the UIKit run loop
    // internally via its CADisplayLink, so all UIKit access is on the main
    // thread.  SwiftUI's run loop is suspended while the game runs – this
    // mirrors how a normal SDL/Love iOS app works.
    loveSDLMain(0, nullptr);
}

@end
