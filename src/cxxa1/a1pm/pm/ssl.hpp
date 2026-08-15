// ssl.hpp
#pragma once

#include <openssl/evp.h>
#include <openssl/sha.h>
#include <fstream>
#include <sstream>
#include <iomanip>

namespace a1pm::ssl {
inline std::string get_file_hash_hex(const std::string& path) {
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (!ctx) return "";
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        EVP_MD_CTX_free(ctx);
        return "";
    }
    char buffer[8192];
    while (file.read(buffer, sizeof(buffer))) { EVP_DigestUpdate(ctx, buffer, file.gcount()); }
    EVP_DigestUpdate(ctx, buffer, file.gcount());
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int len;
    EVP_DigestFinal_ex(ctx, hash, &len);
    EVP_MD_CTX_free(ctx);
    std::stringstream ss;
    for (unsigned int i = 0; i < len; i++) { ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i]; }
    return ss.str();
}

inline std::string get_file_hash_bin(const std::string& path) {
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (!ctx) return "";
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        EVP_MD_CTX_free(ctx);
        return "";
    }
    char buffer[8192];
    while (file.read(buffer, sizeof(buffer))) { EVP_DigestUpdate(ctx, buffer, file.gcount()); }
    EVP_DigestUpdate(ctx, buffer, file.gcount());
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int len;
    EVP_DigestFinal_ex(ctx, hash, &len);
    EVP_MD_CTX_free(ctx);
    return std::string(reinterpret_cast<char*>(hash), len);
}

// verify file hash
inline bool verify_file_hash(const std::string& path, const std::string& expected_hex) {
    std::string actual = get_file_hash_hex(path);
    return actual == expected_hex;
}

} /* namespace a1pm::ssl */
