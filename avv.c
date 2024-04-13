#include <stdbool.h>
#include <dlfcn.h>
static void android_disable_tags() {
    void *lib_handle = dlopen("libc.so", RTLD_LAZY);
    if (lib_handle) {
        if (android_get_device_api_level() >= 31) {
            int (*mallopt_func)(int, int) = dlsym(lib_handle, "mallopt");
            if (mallopt_func) {
                mallopt_func(204, 0);
            }
            return;
        }
        /* android_get_device_api_level() < 31 */
        bool (*android_mallopt)(int opcode, void* arg, size_t arg_size) = dlsym(lib_handle, "android_mallopt");
        if (android_mallopt) {
            int android_malloc_tag_level = 0;
            android_mallopt(8, &android_malloc_tag_level, sizeof(android_malloc_tag_level));
        }
        dlclose(lib_handle);
    }
}
