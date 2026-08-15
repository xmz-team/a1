// zip.hpp
#include <libxmz/fs.hpp>
#include <zip.h>
#include <vector>
#include <string>

namespace a1mod::cmd {

inline int zip(const std::string& zip_path, const std::vector<std::string>& files) {
    int err = 0;
    zip_t* z = zip_open(zip_path.c_str(), ZIP_CREATE | ZIP_TRUNCATE, &err);
    if (!z) return -1;
    for (const auto& file : files) {
        if (xmz::aux::exist(file) != 0) continue;
        zip_source_t* src = zip_source_file(z, file.c_str(), 0, 0);
        if (!src) { zip_close(z); return -1; }
        if (zip_file_add(z, file.c_str(), src, ZIP_FL_OVERWRITE) < 0) {
            zip_source_free(src);
            zip_close(z);
            return -1;
        }
    }
    zip_close(z);
    return 0;
}

inline int zip(const std::string& zip_path, const std::string& dir_path) {
    if (xmz::aux::is_dir(dir_path) != 0) return -1;
    std::vector<std::string> files;
    for (const auto& entry : std::filesystem::recursive_directory_iterator(dir_path)) {
        if (entry.is_regular_file()) { files.push_back(entry.path().string()); }
    }
    return zip(zip_path, files);
}

inline int unzip(const std::string& zip_path, const std::string& dest_dir) {
    int err = 0;
    zip_t* z = zip_open(zip_path.c_str(), 0, &err);
    if (!z) return -1;
    if (xmz::aux::exist(dest_dir) != 0) { std::filesystem::create_directories(dest_dir); }
    zip_int64_t num = zip_get_num_entries(z, 0);
    for (zip_int64_t i = 0; i < num; ++i) {
        const char* name = zip_get_name(z, i, 0);
        if (!name) continue;
        std::string full = dest_dir + "/" + name;
        size_t len = strlen(name);
        if (len > 0 && name[len - 1] == '/') {
            std::filesystem::create_directories(full);
            continue;
        }
        std::string parent = full.substr(0, full.find_last_of('/'));
        if (xmz::aux::exist(parent) != 0) { std::filesystem::create_directories(parent); }
        zip_file_t* zf = zip_fopen_index(z, i, 0);
        if (!zf) { zip_close(z); return -1; }
        std::string content;
        char buf[8192];
        zip_int64_t n;
        while ((n = zip_fread(zf, buf, sizeof(buf))) > 0) { content.append(buf, n); }
        zip_fclose(zf);
        std::ofstream out(full, std::ios::binary);
        if (!out) { zip_close(z); return -1; }
        out.write(content.c_str(), content.size());
        out.close();
    }
    zip_close(z);
    return 0;
}
} /* namespace a1mod::cmd */
