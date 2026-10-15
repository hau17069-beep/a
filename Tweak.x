// FoodyJB — Jailbreak Bypass cho vn.foody.nowpartner

#import <Foundation/Foundation.h>
#import <substrate.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <sys/errno.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <errno.h>
#import <string.h>
#import <stdlib.h>
#import <stdarg.h>
#import <dlfcn.h>

// ============ PRIVATE APIs ============
extern int proc_pidinfo(int pid, int flavor, uint64_t arg, void *buf, int size);
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
extern int csops_audittoken(pid_t pid, unsigned int ops, void *useraddr, size_t usersize, audit_token_t *token);
extern int sandbox_check(pid_t pid, const char *op, int type, ...);

// ============ CONSTANTS ============
#define CS_DEBUGGED  0x10000000
#define CS_HARD      0x00000100
#define CS_KILL      0x00000200
#define CS_RESTRICT  0x00000800
#define CS_CLEAR     (CS_DEBUGGED | CS_HARD | CS_KILL | CS_RESTRICT)
#define P_TRACED_FLAG 0x00000800
#define S_IFMT_M     0xF000
#define S_IFLNK_M    0xA000
#define S_IFDIR_M    0x4000

// ============ JB KEYWORDS ============
static NSArray *gJBKeywords(void) {
    static NSArray *a = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[@"cydia", @"sileo", @"zebra", @"mobilesubstrate",
              @"/applications/blackra1n", @"/applications/fakecarrier",
              @"/applications/icy.app", @"/applications/intelliscreen",
              @"/applications/mxtube", @"/applications/rockapp",
              @"/applications/sbsettings", @"/applications/winterboard",
              @"/bin/bash", @"/usr/sbin/sshd", @"/usr/bin/ssh",
              @"/etc/apt", @"/private/var/lib/apt", @"/private/var/lib/cydia",
              @"/private/var/stash", @"/private/var/tmp/cydia.log",
              @"/usr/libexec/cydia", @"/usr/libexec/sftp-server",
              @"//etc/apt", @"//var/cache", @"//var/lib/cydia",
              @"//var/lib/apt", @"//bin/bash", @"//bin/sh",
              @"//etc/ssh", @"//var/log", @"//library/mobilesubstrate",
              @"//systetem", @"//system/library/launchdaemons",
              @"//usr/libexec", @"/applications/cydia.app",
              @"/library/mobilesubstrate", @"sbettings", @"sbsettings"];
    });
    return a;
}

static BOOL isJBPath(const char *cp) {
    if (!cp) return NO;
    NSString *p = [[NSString stringWithUTF8String:cp] lowercaseString];
    if ([p containsString:@".jbroot"]) return NO;
    if ([p containsString:@"jbroot-"]) return NO;
    if ([p containsString:@"tweakinject"]) return NO;
    if ([p containsString:@"roothide"]) return NO;
    if ([p containsString:@"ellekit"]) return NO;
    for (NSString *kw in gJBKeywords()) {
        if ([p containsString:kw]) return YES;
    }
    return NO;
}

// ============ SYMLINK PATHS ============
static NSArray *gSymlinkPaths(void) {
    static NSArray *a = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[@"/applications", @"/var", @"/tmp", @"/etc",
              @"/private", @"/usr", @"/library", @"/system",
              @"/bin", @"/sbin", @"/dev", @"/cores"];
    });
    return a;
}

static BOOL isSysSymlink(const char *cp) {
    if (!cp) return NO;
    NSString *p = [[NSString stringWithUTF8String:cp] lowercaseString];
    return [gSymlinkPaths() containsObject:p];
}

// ============ WRITE TEST PATHS ============
static BOOL isWriteTest(const char *cp) {
    if (!cp) return NO;
    return (strstr(cp, "/private/test") != NULL ||
            strstr(cp, "/private/temp") != NULL ||
            strstr(cp, ".sb-") != NULL);
}

// ============ DYLIB KEYWORDS ============
static BOOL isBadDylibName(const char *cp) {
    if (!cp) return NO;
    return (strstr(cp, "FoodyJB") != NULL ||
            strstr(cp, "AutoPickFoody") != NULL ||
            strstr(cp, "NSLogViewer") != NULL ||
            strstr(cp, "gpsmaster") != NULL ||
            strstr(cp, "AppSync") != NULL ||
            strstr(cp, "systemhook") != NULL ||
            strstr(cp, "Shadow") != NULL ||
            strstr(cp, "Choicy") != NULL ||
            strstr(cp, "ellekit") != NULL ||
            strstr(cp, "libellekit") != NULL ||
            strstr(cp, "frida") != NULL ||
            strstr(cp, "gum-js") != NULL ||
            strstr(cp, "dopamine") != NULL ||
            strstr(cp, "palera1n") != NULL ||
            strstr(cp, "TweakInject") != NULL);
}

// ================================================================
// ============ HOOKS ============
// ================================================================

// -------- 1. LSTAT --------
static int (*orig_lstat)(const char *, struct stat *);
static int new_lstat(const char *path, struct stat *buf) {
    int r = orig_lstat(path, buf);
    if (r == 0 && buf && isSysSymlink(path)) {
        if ((buf->st_mode & S_IFMT_M) == S_IFLNK_M) {
            buf->st_mode = (buf->st_mode & ~S_IFMT_M) | S_IFDIR_M;
        }
    }
    return r;
}

// -------- 2. STAT --------
static int (*orig_stat)(const char *, struct stat *);
static int new_stat(const char *path, struct stat *buf) {
    int r = orig_stat(path, buf);
    if (r == 0 && buf && isSysSymlink(path)) {
        if ((buf->st_mode & S_IFMT_M) == S_IFLNK_M) {
            buf->st_mode = (buf->st_mode & ~S_IFMT_M) | S_IFDIR_M;
        }
    }
    return r;
}

// -------- 3. READLINK --------
static ssize_t (*orig_readlink)(const char *, char *, size_t);
static ssize_t new_readlink(const char *path, char *buf, size_t size) {
    if (isSysSymlink(path)) { errno = ENOENT; return -1; }
    return orig_readlink(path, buf, size);
}

static ssize_t (*orig_readlinkat)(int, const char *, char *, size_t);
static ssize_t new_readlinkat(int fd, const char *path, char *buf, size_t size) {
    if (isSysSymlink(path)) { errno = ENOENT; return -1; }
    return orig_readlinkat(fd, path, buf, size);
}

// -------- 4. FOPEN --------
static FILE *(*orig_fopen)(const char *, const char *);
static FILE *new_fopen(const char *path, const char *mode) {
    if (isJBPath(path)) { errno = ENOENT; return NULL; }
    return orig_fopen(path, mode);
}

// -------- 5. ACCESS --------
static int (*orig_access)(const char *, int);
static int new_access(const char *path, int mode) {
    if (isJBPath(path)) { errno = ENOENT; return -1; }
    return orig_access(path, mode);
}

// -------- 6. OPEN --------
static int (*orig_open)(const char *, int, ...);
static int new_open(const char *path, int flags, ...) {
    if (isJBPath(path)) { errno = ENOENT; return -1; }
    va_list args; va_start(args, flags);
    int mode = va_arg(args, int);
    va_end(args);
    return orig_open(path, flags, mode);
}

// -------- 7. MKDIR --------
static int (*orig_mkdir)(const char *, mode_t);
static int new_mkdir(const char *path, mode_t mode) {
    if (isWriteTest(path)) { errno = EROFS; return -1; }
    return orig_mkdir(path, mode);
}

// -------- 8. CREAT --------
static int (*orig_creat)(const char *, mode_t);
static int new_creat(const char *path, mode_t mode) {
    if (isWriteTest(path)) { errno = EROFS; return -1; }
    return orig_creat(path, mode);
}

// -------- 9. SANDBOX_CHECK --------
static int (*orig_sandbox_check)(pid_t, const char *, int, ...);
static int new_sandbox_check(pid_t pid, const char *op, int type, ...) {
    va_list args;
    va_start(args, type);
    const char *path = va_arg(args, const char *);
    va_end(args);
    
    if (op && path &&
        (strcmp(op, "file-write-create") == 0 ||
         strcmp(op, "file-write-data") == 0 ||
         strcmp(op, "file-write-unlink") == 0) &&
        isWriteTest(path)) {
        return 1;
    }
    
    va_list args2;
    va_start(args2, type);
    const char *p2 = va_arg(args2, const char *);
    va_end(args2);
    return orig_sandbox_check(pid, op, type, p2);
}

// -------- 10. SYSCTL --------
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int new_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp,
                      void *newp, size_t newlen) {
    int r = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (r == 0 && namelen >= 3 && name &&
        name[0] == 1 && name[1] == 14 && name[2] == 1) {
        if (oldp && oldlenp && *oldlenp >= 0x24) {
            uint32_t *pflag = (uint32_t *)((char *)oldp + 0x20);
            *pflag &= ~P_TRACED_FLAG;
        }
    }
    return r;
}

// -------- 11. PROC_PIDINFO --------
static int (*orig_proc_pidinfo)(int, int, uint64_t, void *, int);
static int new_proc_pidinfo(int pid, int flavor, uint64_t arg, void *buf, int size) {
    int r = orig_proc_pidinfo(pid, flavor, arg, buf, size);
    if (r > 0 && buf) {
        if (flavor == 2 && size >= 4) {
            *(uint32_t *)buf &= ~P_TRACED_FLAG;
        } else if (flavor == 13 && size >= 0x24) {
            *(uint32_t *)buf &= ~P_TRACED_FLAG;
            *(uint32_t *)((char *)buf + 0x20) &= ~P_TRACED_FLAG;
        }
    }
    return r;
}

// -------- 12. CSOPS --------
static int (*orig_csops)(pid_t, unsigned int, void *, size_t);
static int new_csops(pid_t pid, unsigned int ops, void *addr, size_t size) {
    int r = orig_csops(pid, ops, addr, size);
    if (r == 0 && addr && size >= 4) {
        *(uint32_t *)addr &= ~CS_CLEAR;
    }
    return r;
}

static int (*orig_csops_audittoken)(pid_t, unsigned int, void *, size_t, audit_token_t *);
static int new_csops_audittoken(pid_t pid, unsigned int ops, void *addr, size_t size, audit_token_t *tok) {
    int r = orig_csops_audittoken(pid, ops, addr, size, tok);
    if (r == 0 && addr && size >= 4) {
        *(uint32_t *)addr &= ~CS_CLEAR;
    }
    return r;
}

// -------- 13. GETENV --------
static char *(*orig_getenv)(const char *);
static char *new_getenv(const char *name) {
    if (name && (strstr(name, "DYLD_INSERT") ||
                 strstr(name, "DYLD_LIBRARY") ||
                 strstr(name, "DYLD_FRAMEWORK") ||
                 strstr(name, "JBPATHLOG") ||
                 strstr(name, "FRIDA") ||
                 strstr(name, "SUBSTRATE"))) {
        return NULL;
    }
    return orig_getenv(name);
}

// -------- 14. DYLD_GET_IMAGE_NAME --------
static const char *(*orig_dyld_get_image_name)(uint32_t);
static const char *new_dyld_get_image_name(uint32_t idx) {
    const char *name = orig_dyld_get_image_name(idx);
    if (isBadDylibName(name)) {
        return "/usr/lib/libSystem.B.dylib";
    }
    return name;
}

// -------- 15. TASK_INFO — FILTER DYLD LIST --------
// Dùng tên struct khác để tránh conflict với SDK
struct my_task_dyld_info {
    uintptr_t all_image_info_addr;
    uintptr_t all_image_info_size;
    integer_t all_image_info_format;
};

static kern_return_t (*orig_task_info)(task_name_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);
static kern_return_t new_task_info(task_name_t task, task_flavor_t flavor,
                                    task_info_t info, mach_msg_type_number_t *count) {
    kern_return_t r = orig_task_info(task, flavor, info, count);
    if (r != KERN_SUCCESS || flavor != 17 || !info) return r;
    
    struct my_task_dyld_info *tdi = (struct my_task_dyld_info *)info;
    void *allInfos = (void *)tdi->all_image_info_addr;
    if (!allInfos) return r;
    
    uint32_t *cntPtr = (uint32_t *)((char *)allInfos + 4);
    void **arrPtr = (void **)((char *)allInfos + 8);
    uint32_t cnt = *cntPtr;
    void *arr = *arrPtr;
    if (!arr || cnt == 0 || cnt > 5000) return r;
    
    uint32_t safeIdx = 0;
    for (uint32_t i = 0; i < cnt; i++) {
        char *entry = (char *)arr + i * 24;
        const char *pathPtr = *(const char **)(entry + 8);
        if (isBadDylibName(pathPtr)) continue;
        if (safeIdx != i) {
            memcpy((char *)arr + safeIdx * 24, entry, 24);
        }
        safeIdx++;
    }
    
    if (safeIdx < cnt) {
        *cntPtr = safeIdx;
    }
    return r;
}

// -------- 16. NSFileManager --------
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if (isJBPath([path UTF8String])) return NO;
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDir {
    if (isJBPath([path UTF8String])) {
        if (isDir) *isDir = NO;
        return NO;
    }
    return %orig;
}

- (BOOL)isWritableFileAtPath:(NSString *)path {
    if (isJBPath([path UTF8String])) return NO;
    return %orig;
}

- (BOOL)isExecutableFileAtPath:(NSString *)path {
    if (isJBPath([path UTF8String])) return NO;
    return %orig;
}

- (BOOL)isReadableFileAtPath:(NSString *)path {
    if (isJBPath([path UTF8String])) return NO;
    return %orig;
}

%end

// ================================================================
// ============ CONSTRUCTOR ============
// ================================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[FoodyJB] Loading...");
        
        MSHookFunction((void *)lstat,      (void *)new_lstat,      (void **)&orig_lstat);
        MSHookFunction((void *)stat,       (void *)new_stat,       (void **)&orig_stat);
        MSHookFunction((void *)readlink,   (void *)new_readlink,   (void **)&orig_readlink);
        MSHookFunction((void *)readlinkat, (void *)new_readlinkat, (void **)&orig_readlinkat);
        MSHookFunction((void *)fopen,      (void *)new_fopen,      (void **)&orig_fopen);
        MSHookFunction((void *)access,     (void *)new_access,     (void **)&orig_access);
        MSHookFunction((void *)open,       (void *)new_open,       (void **)&orig_open);
        MSHookFunction((void *)mkdir,      (void *)new_mkdir,      (void **)&orig_mkdir);
        MSHookFunction((void *)creat,      (void *)new_creat,      (void **)&orig_creat);
        MSHookFunction((void *)sandbox_check, (void *)new_sandbox_check, (void **)&orig_sandbox_check);
        MSHookFunction((void *)sysctl,     (void *)new_sysctl,     (void **)&orig_sysctl);
        MSHookFunction((void *)proc_pidinfo, (void *)new_proc_pidinfo, (void **)&orig_proc_pidinfo);
        MSHookFunction((void *)csops,      (void *)new_csops,      (void **)&orig_csops);
        MSHookFunction((void *)csops_audittoken, (void *)new_csops_audittoken, (void **)&orig_csops_audittoken);
        MSHookFunction((void *)getenv,     (void *)new_getenv,     (void **)&orig_getenv);
        MSHookFunction((void *)_dyld_get_image_name, (void *)new_dyld_get_image_name, (void **)&orig_dyld_get_image_name);
        MSHookFunction((void *)task_info,  (void *)new_task_info,  (void **)&orig_task_info);
        
        NSLog(@"[FoodyJB] ✅ Loaded successfully");
    }
}
