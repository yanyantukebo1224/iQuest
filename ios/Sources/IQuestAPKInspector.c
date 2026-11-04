#include "IQuestAPKInspector.h"

#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <zlib.h>

#define ZIP_EOCD 0x06054b50u
#define ZIP_CENTRAL 0x02014b50u
#define ZIP_LOCAL 0x04034b50u
#define MAX_APK_LIBS 64
#define MAX_APK_NAME 128

static uint16_t rd16(const unsigned char *p) {
    return (uint16_t)(p[0] | ((uint16_t)p[1] << 8));
}
static uint32_t rd32(const unsigned char *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static void seterr(char *out, size_t cap, const char *s) {
    if (out && cap) snprintf(out, cap, "%s", s);
}
static int append(char *out, size_t cap, size_t *used, const char *fmt, ...) {
    if (*used >= cap) return 1;
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(out + *used, cap - *used, fmt, ap);
    va_end(ap);
    if (n < 0 || (size_t)n >= cap - *used) return 1;
    *used += (size_t)n;
    return 0;
}

// Android's binary XML string pool stores UTF-8 strings with two variable
// length prefixes. This helper intentionally rejects malformed lengths.
static int axml_len8(const unsigned char **p, const unsigned char *end, size_t *v) {
    if (*p >= end) return 1;
    unsigned a = *(*p)++;
    if (a & 0x80) {
        if (*p >= end) return 1;
        a = ((a & 0x7f) << 8) | *(*p)++;
    }
    *v = a;
    return 0;
}
static int axml_string(const unsigned char *pool, size_t pool_size,
                       uint32_t index, char *out, size_t cap) {
    if (pool_size < 28) return 1;
    uint32_t count = rd32(pool + 8), flags = rd32(pool + 16);
    uint32_t strings_start = rd32(pool + 20);
    if (index >= count || strings_start >= pool_size) return 1;
    uint32_t off = rd32(pool + 28 + index * 4);
    if (off >= pool_size - strings_start) return 1;
    const unsigned char *p = pool + strings_start + off;
    const unsigned char *end = pool + pool_size;
    if (flags & 0x100) {
        size_t chars, bytes;
        if (axml_len8(&p, end, &chars) || axml_len8(&p, end, &bytes) ||
            bytes > (size_t)(end - p) || bytes >= cap) return 1;
        memcpy(out, p, bytes); out[bytes] = 0; return 0;
    }
    // UTF-16 string pool. Convert the ASCII subset used by Android package
    // names and attribute names; non-ASCII display names are replaced safely.
    if ((size_t)(end - p) < 2) return 1;
    uint16_t units = rd16(p); p += 2;
    if (units >= cap || (size_t)(end - p) < (size_t)units * 2) return 1;
    for (unsigned i = 0; i < units; i++) {
        uint16_t ch = rd16(p + i * 2);
        out[i] = ch < 0x80 ? (char)ch : '?';
    }
    out[units] = 0;
    return 0;
}

static void parse_manifest(const unsigned char *xml, size_t n,
                           char *package, size_t package_cap,
                           char *version, size_t version_cap) {
    if (n < 8 || rd16(xml) != 0x0003) return;
    const unsigned char *p = xml + 8, *end = xml + n;
    char (*strings)[256] = (char (*)[256])calloc(2048, 256);
    if (!strings) return;
    unsigned string_count = 0;
    while ((size_t)(end - p) >= 8) {
        uint16_t type = rd16(p);
        uint16_t header = rd16(p + 2);
        uint32_t size = rd32(p + 4);
        if (size < 8 || size > (uint32_t)(end - p) || header > size) break;
        if (type == 0x0001 && size >= 28) {
            uint32_t count = rd32(p + 8);
            string_count = count < 2048 ? count : 2048;
            memset(strings, 0, 2048u * 256u);
            for (unsigned i = 0; i < string_count; i++)
                axml_string(p, size, i, strings[i], sizeof strings[i]);
        } else if (type == 0x0102 && size >= 36 && string_count) {
            uint32_t name_idx = rd32(p + 20);
            if (name_idx >= string_count || strcmp(strings[name_idx], "manifest")) {
                p += size; continue;
            }
            uint16_t attr_start = rd16(p + 24);
            uint16_t attr_size = rd16(p + 26);
            uint16_t attr_count = rd16(p + 28);
            if (attr_size < 20) { p += size; continue; }
            size_t base = 16u + attr_start;
            for (unsigned i = 0; i < attr_count; i++) {
                size_t at = base + (size_t)i * attr_size;
                if (at + 20 > size) break;
                uint32_t attr_name = rd32(p + at + 4);
                uint32_t value = rd32(p + at + 8);
                if (attr_name >= string_count) continue;
                // Some AXML writers omit rawValue and keep the string only
                // in the typed-value payload (TYPE_STRING = 0x03).
                if (value == 0xffffffffu && p[at + 15] == 0x03)
                    value = rd32(p + at + 16);
                if (!strcmp(strings[attr_name], "package") && value < string_count)
                    snprintf(package, package_cap, "%s", strings[value]);
                if (!strcmp(strings[attr_name], "versionName") && value < string_count)
                    snprintf(version, version_cap, "%s", strings[value]);
            }
            if (*package) { free(strings); return; }
        }
        p += size;
    }
    free(strings);
}

static int extract_manifest(FILE *f, uint32_t local_off, uint16_t method,
                            uint32_t comp_size, uint32_t uncomp_size,
                            unsigned char **out) {
    unsigned char h[30];
    if (fseek(f, (long)local_off, SEEK_SET) || fread(h, 1, sizeof h, f) != sizeof h ||
        rd32(h) != ZIP_LOCAL) return 1;
    uint16_t name_len = rd16(h + 26), extra_len = rd16(h + 28);
    if (fseek(f, (long)(local_off + 30u + name_len + extra_len), SEEK_SET)) return 1;
    unsigned char *src = (unsigned char *)malloc(comp_size ? comp_size : 1);
    unsigned char *dst = (unsigned char *)malloc(uncomp_size ? uncomp_size : 1);
    if (!src || !dst) { free(src); free(dst); return 1; }
    if (fread(src, 1, comp_size, f) != comp_size) { free(src); free(dst); return 1; }
    int bad = 0;
    if (method == 0) {
        if (comp_size != uncomp_size) bad = 1;
        else memcpy(dst, src, uncomp_size);
    } else if (method == 8) {
        z_stream zs; memset(&zs, 0, sizeof zs);
        zs.next_in = src; zs.avail_in = comp_size;
        zs.next_out = dst; zs.avail_out = uncomp_size;
        if (inflateInit2(&zs, -MAX_WBITS) != Z_OK) bad = 1;
        else {
            int z = inflate(&zs, Z_FINISH);
            bad = (z != Z_STREAM_END || zs.total_out != uncomp_size);
            inflateEnd(&zs);
        }
    } else bad = 1;
    free(src);
    if (bad) { free(dst); return 1; }
    *out = dst; return 0;
}

int iquest_apk_inspect(const char *path, char *output, size_t output_capacity,
                       char *error, size_t error_capacity) {
    if (!path || !output || output_capacity < 64) {
        seterr(error, error_capacity, "Invalid arguments"); return 1;
    }
    output[0] = 0;
    FILE *f = fopen(path, "rb");
    if (!f) { seterr(error, error_capacity, "Cannot open APK"); return 1; }
    if (fseek(f, 0, SEEK_END)) { fclose(f); seterr(error,error_capacity,"Cannot seek APK"); return 1; }
    long file_size = ftell(f);
    if (file_size < 22) { fclose(f); seterr(error,error_capacity,"File is too small to be an APK"); return 1; }
    size_t tail_len = (size_t)(file_size < 65557 ? file_size : 65557);
    unsigned char *tail = (unsigned char *)malloc(tail_len);
    if (!tail || fseek(f, file_size - (long)tail_len, SEEK_SET) ||
        fread(tail, 1, tail_len, f) != tail_len) {
        free(tail); fclose(f); seterr(error,error_capacity,"Cannot read ZIP directory"); return 1;
    }
    long eocd = -1;
    for (long i = (long)tail_len - 22; i >= 0; --i)
        if (rd32(tail + i) == ZIP_EOCD) { eocd = i; break; }
    if (eocd < 0) { free(tail); fclose(f); seterr(error,error_capacity,"ZIP end record not found"); return 1; }
    uint16_t entries = rd16(tail + eocd + 10);
    uint32_t cd_size = rd32(tail + eocd + 12), cd_off = rd32(tail + eocd + 16);
    if (entries == 0xffff || cd_size == 0xffffffffu || cd_off == 0xffffffffu ||
        (uint64_t)cd_off + cd_size > (uint64_t)file_size) {
        free(tail); fclose(f); seterr(error,error_capacity,"ZIP64 APK is not supported by this inspector"); return 1;
    }
    free(tail);
    char package[256] = "", version[128] = "";
    char libs[MAX_APK_LIBS][MAX_APK_NAME]; unsigned lib_count = 0, assets = 0;
    unsigned char *manifest = NULL;
    uint32_t manifest_comp=0, manifest_uncomp=0, manifest_off=0;
    uint16_t manifest_method=0; int has_manifest=0;
    if (fseek(f, cd_off, SEEK_SET)) { fclose(f); seterr(error,error_capacity,"Invalid central directory"); return 1; }
    for (unsigned i = 0; i < entries; i++) {
        unsigned char h[46];
        if (fread(h, 1, sizeof h, f) != sizeof h || rd32(h) != ZIP_CENTRAL) {
            fclose(f); seterr(error,error_capacity,"Malformed ZIP central directory"); return 1;
        }
        uint16_t method=rd16(h+10), name_len=rd16(h+28), extra_len=rd16(h+30), comment_len=rd16(h+32);
        uint32_t comp=rd32(h+20), uncomp=rd32(h+24), off=rd32(h+42);
        char name[1024];
        if (!name_len || name_len >= sizeof name) {
            if (fseek(f, (long)name_len + extra_len + comment_len, SEEK_CUR)) break;
            continue;
        }
        if (fread(name, 1, name_len, f) != name_len) break;
        name[name_len] = 0;
        if (fseek(f, (long)extra_len + comment_len, SEEK_CUR)) break;
        if (!strcmp(name, "AndroidManifest.xml")) {
            manifest_comp=comp; manifest_uncomp=uncomp; manifest_off=off; manifest_method=method; has_manifest=1;
        } else if (!strncmp(name, "lib/arm64-v8a/", 14) && strstr(name, ".so") &&
                   lib_count < MAX_APK_LIBS) {
            const char *base = strrchr(name, '/');
            snprintf(libs[lib_count++], MAX_APK_NAME, "%s", base ? base+1 : name);
        } else if (!strncmp(name, "assets/", 7) && name[strlen(name)-1] != '/') {
            assets++;
        }
    }
    if (has_manifest && manifest_uncomp && manifest_uncomp < 16*1024*1024)
        extract_manifest(f, manifest_off, manifest_method, manifest_comp, manifest_uncomp, &manifest);
    fclose(f);
    if (manifest) { parse_manifest(manifest, manifest_uncomp, package, sizeof package, version, sizeof version); free(manifest); }
    size_t used=0;
    if (append(output,output_capacity,&used,"package=%s\nversion=%s\nfile_bytes=%ld\narm64_library_count=%u\nasset_file_count=%u\nmanifest=%s\n",
               *package?package:"(unreadable)",*version?version:"(not set)",file_size,lib_count,assets,has_manifest?"present":"missing")) {
        seterr(error,error_capacity,"Report buffer too small"); return 1;
    }
    for (unsigned i=0;i<lib_count;i++)
        if (append(output,output_capacity,&used,"arm64_library=%s\n",libs[i])) {
            seterr(error,error_capacity,"Report buffer too small"); return 1;
        }
    seterr(error,error_capacity,"");
    return 0;
}
