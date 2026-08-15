// download.hpp
#pragma once

#include <string>
#include <iostream>

#include <curl/curl.h>

namespace a1pm::curl {
static int progress_callback(
    void* clientp,
    double dltotal,
    double dlnow,
    double ultotal,
    double ulnow) {
    if (dltotal > 0) {
        int percent = static_cast<int>((dlnow / dltotal) * 100);
        xmz::print("\rDownload progress:", percent, "%");
        std::flush();
    }
    return 0;
}

bool download_file(
    const std::string& url,
    const std::string& outputPath,
    std::string& errorMsg) {
    CURL* curl = curl_easy_init();
    if (!curl) {
        errorMsg = "curl_easy_init() failed";
        return false;
    }

    std::ofstream outFile(outputPath, std::ios::binary);
    if (!outFile.is_open()) {
        errorMsg = "Unable to open the output file: " + outputPath;
        curl_easy_cleanup(curl);
        return false;
    }

    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &outFile);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, progress_callback);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 300L);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_LIMIT, 1024L);
    curl_easy_setopt(curl, CURLOPT_LOW_SPEED_TIME, 30L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, "a1pm/1.0");
    
    CURLcode res = curl_easy_perform(curl);
    long httpCode = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
    curl_easy_cleanup(curl);
    outFile.close();
    
    if (res != CURLE_OK) {
        errorMsg = "curl_easy_perform() failed: " + std::string(curl_easy_strerror(res));
        return false;
    }

    if (httpCode >= 400) {
        errorMsg = "HTTP error code: " + std::to_string(httpCode);
        return false;
    }
    xmz::println("");
    return true;
}

} /* a1pm::curl */
