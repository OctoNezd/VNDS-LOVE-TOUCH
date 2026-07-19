//
//  LoveViewController.mm
//  SwiftHeart
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

#import "LoveViewController.h"

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

    // argv[0] = "swiftheart" (identifies the host app to the Lua game)
    // argv[1] = path to .love file
    // argv[2] = "--fused"  (skip Love's file-picker UI)
    // argv[3..] = any extra args passed by the caller
    std::string arg0 = "swiftheart";
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
