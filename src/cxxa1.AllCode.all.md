?!== this is full code of cxxa1 ==!?
===== cxxa1/a1/core/pm/download.hpp =====
// download.hpp
#pragma once

#include <string>
#include <iostream>
#include <fstream>

#include <curl/curl.h>

#include <a1/core/version.hpp>

namespace a1pm::curl {
static size_t write_callback(void* contents, size_t size, size_t nmemb, void* userp) {
    std::ofstream* outFile = static_cast<std::ofstream*>(userp);
    size_t totalSize = size * nmemb;
    outFile->write(static_cast<char*>(contents), totalSize);
    return totalSize;
}

static int progress_callback(
    void* clientp,
    double dltotal,
    double dlnow,
    double ultotal,
    double ulnow) {
    if (dltotal > 0) {
        int percent = static_cast<int>((dlnow / dltotal) * 100);
        xmz::print("\rDownload progress:", percent, "%");
        xmz::println("");
        //std::flush();
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
    curl_easy_setopt(curl, CURLOPT_USERAGENT, std::string("a1pm/" + a1::_coreapi::a1pm_version).c_str());

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

====== end =====
===== cxxa1/a1/core/pm/ssl.hpp =====
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

====== end =====
===== cxxa1/a1/core/pm/a1pm_config.hpp =====
// a1pm_config.hpp
#pragma once

#include <string>

#include <a1/core/config.hpp>

namespace a1pm {
class config {
private:
    a1::config::jb_path g_jb;
public:
    std::string pm_cache = g_jb.mod_dir + "/cache/repos";
    std::string repo_f = g_jb.mod_dir + "/repos.ini";
    std::string repo_default_cfg = R"(### example config ###
;;[YouURL]
;;url: https://example.com/yourepo
;;last_sync: UpdateTime
######################

)";
};
} /* namespace a1pm */

====== end =====
===== cxxa1/a1/core/version.hpp.in =====
// version.hpp
#pragma once
#include <string>
namespace a1::_coreapi::version {
    std::string a1_version = "@a1_version@";
    std::string a1ctl_version = "@a1ctl_version@";
    std::string a1mod_version = "@a1mod_version@";
    std::string a1pm_version = "@a1pm_version@";
}

namespace a1::_coreapi {
    using a1::_coreapi::version::a1_version;
    using a1::_coreapi::version::a1ctl_version;
    using a1::_coreapi::version::a1mod_version;
    using a1::_coreapi::version::a1pm_version;
}

namespace a1::version {
    std::string a1 = a1::_coreapi::version::a1_version;
    std::string a1ctl = a1::_coreapi::version::a1ctl_version;
    std::string a1mod = a1::_coreapi::version::a1mod_version;
    std::string a1pm = a1::_coreapi::version::a1pm_version;
}

====== end =====
===== cxxa1/a1/core/get_sys_list.hpp =====
// get_sys_list.hpp
#pragma once
#include <string>
namespace a1::coreapi::lists {
inline std::string high = []() -> std::string {
    return "SpringBoard\n"
"backboardd\n"
"syslogd\n"
"configd\n"
"AppleMediaServicesUI\n"
"com.apple.WebKit.WebContent\n"
"com.apple.WebKit.GPU\n"
"com.apple.WebKit.Networking\n"
"CommCenter\n"
"TranslationUIService\n"
"AccessibilityUIServer\n"
"mobile_assertion_agent\n"
"BTServer\n"
"locationd\n"
"mediaserverd";
}();

inline std::string low = []() -> std::string {
    return "cloudd\n"
"itunesstored\n"
"geod\n"
"assistantd\n"
"calaccessd\n"
"apsd\n"
"adid\n"
"analyticsd\n"
"nsurlsessiond\n"
"softwareupdated\n"
"ckdiscretionaryd\n"
"itunescloudd\n"
"com.apple.sbd\n"
"cloudphotod\n"
"searchd\n"
"fseventsd\n"
"delete_d\n"
"assetsd\n"
"imtransferagent\n"
"pasteboardagent\n"
"cloudpaird\n"
"bird\n"
"mstreamd\n"
"weatherd\n"
"nanoweatherprefsd\n"
"watchlistd\n"
"awdd\n"
"triald\n"
"rtcreportingd\n"
"symptomsd\n"
"symptomsd-diag\n"
"metrickitd\n"
"biomed\n"
"coresymbolicationd\n"
"revisiond\n"
"adprivacyd\n"
"aslmanager\n"
"logd_helper\n"
"siriinferenced\n"
"parsec-fbf\n"
"parsecd\n"
"photoanalysisd\n"
"mediaanalysisd\n"
"searchpartyd\n"
"appstored\n"
"mobileassetd\n"
"appleaccountd\n"
"amsaccountsd\n"
"amsengagementd\n"
"bookassetd\n"
"musiccache\n"
"medialibraryd\n"
"familycircled\n"
"familynotificationd\n"
"donotdisturbd\n"
"wirelessproxd\n"
"nehelper\n"
"networkserviceproxy\n"
"mapsupportd\n"
"navd\n"
"destinationd\n"
"routined\n"
"locationd_helper\n"
"fitnesscoachingd\n"
"healthrecordsd\n"
"activityd\n"
"achievementd\n"
"gamectrld\n"
"sociallayerd\n"
"askpermissiond\n"
"privacyaccountingd\n"
"diagnosticextensionsd\n"
"reportcrash\n"
"spindump\n"
"tailspind\n"
"stackshot\n"
"xpcproxy\n"
"distnoted\n"
"cfprefsd\n"
"suggestd\n"
"duetexpertd\n"
"synceddefaultsd\n"
"nanoprefsyncd\n"
"nanosystemsettingsd\n"
"nanotimekitcompaniond\n"
"nanoregistryd\n"
"nanoregistrylaunchd\n"
"remoted\n"
"remotemanagementd\n"
"com.apple.MobileSoftwareUpdate.CleanupPreparePathService\n"
"com.apple.StreamingUnzipService\n"
"com.apple.SiriTTSService.TrialProxy\n"
"com.apple.siri-distributed-evaluation\n"
"com.apple.VideoSubscriberAccount.DeveloperService\n"
"AppPredictionIntentsHelperService\n"
"AssetCacheLocatorService\n"
"DayStreamProcessorService\n"
"EnforcementService\n"
"HistoricalAnalyzerService\n"
"IDSBlastDoorService\n"
"IMDPersistenceAgent\n"
"MTLCompilerService\n"
"PerfPowerTelemetryClientRegistrationService\n"
"TrustedPeersHelper\n"
"ThreeBarsXPCService\n"
"accountsd\n"
"familycontrolsagent\n"
"generatestorageagent\n"
"icloudpairing\n"
"keyboardservicesd\n"
"mobileactivationd\n"
"mobilebackup\n"
"newsd\n"
"notificationsd\n"
"profiled\n"
"screensharingd\n"
"softwareupdate\n"
"stocksd\n"
"storeassetd\n"
"storebookkeeperd\n"
"storedownloadd\n"
"streaming_zip_conduit\n"
"touchsetupd\n"
"useractivityd";
}();
} /* namespace a1::coreapi::lists */

====== end =====
===== cxxa1/a1/core/lock.hpp =====
// lock.hpp
#pragma once
#include <string>
#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>
#include <flock-ios/flock.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
class lock_manager {
private:
    int lock_fd = -1;
    std::string lock_file;
    bool lock_enabled = false;
public:
    lock_manager() = default;
    ~lock_manager() { release(); }
    void init(const std::string& file_path) { lock_file = file_path; }
    bool acquire() {
        if (!lock_enabled) return true;
        lock_fd = open(lock_file.c_str(), O_RDWR | O_CREAT | O_TRUNC, 0644);
        if (lock_fd < 0) {
            xmz::log::error("unable to open the lock file: ", lock_file);
            return false;
        }
        cleanup_stale_lock();
        int was_timeout = 0;
        int ret = flock_with_retry(lock_fd, LOCK_EX | LOCK_NB, 0, &was_timeout);
        if (ret < 0) {
            if (errno == EWOULDBLOCK || errno == EAGAIN) {
                std::string lock_pid = read_lock_pid();
                if (!lock_pid.empty()) {
                    xmz::log::error("process:", lock_pid, "holding lock, unable to continue the operation");
                    xmz::log::warn("you can choose to delete the lock file to continue the operation.");
                    xmz::log::warn("but! We don’t recommend using this method, unless the holding process is a zombie process, etc.");
                } else {
                    xmz::log::error("unable to get the lock");
                }
            } else {
                xmz::log::error("flock failed: ", strerror(errno));
            }
            close(lock_fd);
            lock_fd = -1;
            return false;
        }

        write_current_pid();
        return true;
    }
    void release() {
        if (lock_fd < 0) return;
        std::string lock_pid = read_lock_pid();
        pid_t current_pid = getpid();
        if (!lock_pid.empty()) {
            pid_t stored_pid = static_cast<pid_t>(std::stoi(lock_pid));
            if (stored_pid == current_pid) { unlink(lock_file.c_str()); }
        }
        int dummy_timeout;
        flock_with_retry(lock_fd, LOCK_UN, 0, &dummy_timeout);
        close(lock_fd);
        lock_fd = -1;
    }
    void set_enabled(bool enabled) { lock_enabled = enabled; }
    bool is_enabled() const { return lock_enabled; }
private:
    void cleanup_stale_lock() {
        std::string lock_pid = read_lock_pid();
        if (lock_pid.empty()) return;
        pid_t pid = static_cast<pid_t>(std::stoi(lock_pid));
        if (kill(pid, 0) != 0 && errno == ESRCH) {
            unlink(lock_file.c_str());
            xmz::log::info("the zombie lock has been cleaned up (the original holding process", pid, "no longer exists)");
        }
    }
    std::string read_lock_pid() {
        int fd = open(lock_file.c_str(), O_RDONLY);
        if (fd < 0) return "";
        char buffer[32] = {0};
        ssize_t n = read(fd, buffer, sizeof(buffer) - 1);
        close(fd);
        if (n <= 0) return "";
        buffer[n] = '\0';
        std::string pid(buffer);
        while (!pid.empty() && (pid.back() == '\n' || pid.back() == '\r')) { pid.pop_back(); }
        return pid;
    }
    void write_current_pid() {
        if (lock_fd < 0) return;
        ftruncate(lock_fd, 0);
        lseek(lock_fd, 0, SEEK_SET);
        std::string pid_str = std::to_string(getpid()) + "\n";
        write(lock_fd, pid_str.c_str(), pid_str.size());
        fsync(lock_fd);
    }
};

} // namespace a1ctl

====== end =====
===== cxxa1/a1/core/a1pmcore.hpp =====
// a1pmcore.hpp
#pragma once

#include <string>
#include <regex>
#include <algorithm>
#include <set>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/time.hpp>

#include <a1/core/a1modcore.hpp>
#include <a1/core/pm/a1pm_config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/pm/download.hpp>
#include <a1/core/pm/ssl.hpp>

namespace a1pm {
	inline std::string url_to_repo_name(const std::string& url) {
		std::string result = url;
		std::regex protocol_regex("^https?://");
		result = std::regex_replace(result, protocol_regex, "");
		if (!result.empty() && result.back() == '/') { result.pop_back(); }
		std::replace(result.begin(), result.end(), '/', '_');
		return result;
	}

	inline void init_repo_list() {
		a1pm::config pmcfg;
		if (xmz::aux::is_file(pmcfg.repo_f) == 1) { xmz::fs::writefile(pmcfg.repo_default_cfg, pmcfg.repo_f); }
		if (xmz::aux::is_dir(pmcfg.pm_cache) == 1) { xmz::fs::mkdir(pmcfg.pm_cache); }
	}

	inline void add_repo(const std::string& url) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (url == "") {
			xmz::log::error("the url cannot be empty");
			return;
		}

		std::string name = url_to_repo_name(url);
		pini.parse_file(cfg.repo_f);
		if (pini.get(url, url) != "") {
			xmz::log::warn("Repo:", url, "already exists, will update the time");
			std::string time = xmz::get_time_str();
			pini.set(url, "last_sync", time);
			xmz::println("already exists, updated last_sync");
		} else {
			std::string time = xmz::get_time_str();
			std::string repo_text = "[" + url + "]\n" + "url: " + url + "\n" + "last_sync: " + time + "\n";
			xmz::fs::writefile(repo_text, cfg.repo_f);
			xmz::println("added successfully");
		}
	}

	inline void remove_repo(const std::string& url) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (url != "") {
			pini.parse_file(cfg.repo_f);
			pini.rmkey(url, "last_sync");
			pini.rmkey(url, url);
			pini.rmsec(url);
			xmz::log::info("Repo:", url, "deleted");
		} else {
			xmz::log::error("the url cannot be empty");
          return;
		}
	}

	namespace aux {
		inline int install_package_with_deps(
			const std::string& package, 
			std::set<std::string>& installed,
			std::set<std::string>& visiting) {
			a1pm::config cfg;
			a1::ini::ini_parser pini;
			if (installed.find(package) != installed.end()) { return 0; }
			if (visiting.find(package) != visiting.end()) {
				xmz::log::error("Circular dependency detected:", package);
				return 1;
			}
			if (package.empty()) {
				xmz::log::error("package name cannot be empty");
				return 1;
			}
			if (!pini.parse_file(cfg.repo_f)) {
				xmz::log::error("Failed to parse repo config:", cfg.repo_f);
				return 1;
			}
			auto sections = pini.get_sec();
			if (sections.empty()) {
				xmz::log::error("No repositories configured");
				return 1;
			}
			std::string cache_dir = cfg.pm_cache;
			if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
			std::string found_repo;
			std::string pkg_filepath;
			std::string pkg_version;
			std::string pkg_sha256;
			std::string pkg_filename;
			std::vector<std::string> pkg_depends;
			std::vector<std::string> pkg_depends_apt;
			for (const auto& repo_url : sections) {
				std::string repo_name = url_to_repo_name(repo_url);
				std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
				if (xmz::aux::is_file(metadata_file) != 0) {
					xmz::log::warn("Repository metadata not found:", repo_url);
					continue;
				}
				a1::ini::ini_parser pkg_parser;
				if (!pkg_parser.parse_file(metadata_file)) {
					xmz::log::warn("Failed to parse metadata for:", repo_url);
					continue;
				}
				auto pkg_sections = pkg_parser.get_sec();
				for (const auto& pkg_name : pkg_sections) {
					if (pkg_name == package) {
						pkg_version = pkg_parser.get(pkg_name, "version", "");
						pkg_filepath = pkg_parser.get(pkg_name, "filepath", "");
						pkg_sha256 = pkg_parser.get(pkg_name, "sha256", "");
						pkg_filename = pkg_parser.get(pkg_name, "filename", "");
						std::string depends_str = pkg_parser.get(pkg_name, "depends", "");
						if (!depends_str.empty()) {
							auto parts = xmz::str::split(depends_str, ",");
							for (auto& p : parts) {
								p = xmz::str::trim(p);
								if (!p.empty()) {
									std::string dep_name = p;
									size_t pos = dep_name.find('(');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('>');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('<');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('=');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									if (!dep_name.empty()) { pkg_depends.push_back(dep_name); }
								}
							}
						}
					 std::string depends_apt_str = pkg_parser.get(pkg_name, "depends_apt", "");
						if (!depends_apt_str.empty()) {
							auto parts = xmz::str::split(depends_apt_str, ",");
							for (auto& p : parts) {
								p = xmz::str::trim(p);
								if (!p.empty()) { pkg_depends_apt.push_back(p); }
							}
						}
						if (pkg_version.empty() || pkg_filepath.empty()) {
							xmz::log::warn("Package", package, "in", repo_url, "has incomplete metadata");
							continue;
						}
						found_repo = repo_url;
						break;
					}
				}
				if (!found_repo.empty()) break;
			}
			if (found_repo.empty()) {
				xmz::log::error("Package not found:", package);
				return 1;
			}
			if (!pkg_depends_apt.empty()) {
				xmz::log::info("Checking system dependencies...");
				for (const auto& apt_pkg : pkg_depends_apt) {
					auto result = xmz::cmd::run_shell_capture(
						"dpkg -l " + apt_pkg + " 2>/dev/null | grep '^ii'"
					);
					if (result.exit_code != 0) {
						xmz::log::error("Missing system package:", apt_pkg);
						xmz::log::info("Install with: apt install", apt_pkg);
						return 1;
					}
				}
				xmz::log::info("System dependencies satisfied");
			}
			visiting.insert(package);
			if (!pkg_depends.empty()) {
				xmz::log::info("Installing dependencies for:", package);
				for (const auto& dep : pkg_depends) {
					if (installed.find(dep) == installed.end()) {
						xmz::log::info("  Dependency:", dep);
						if (install_package_with_deps(dep, installed, visiting) != 0) {
							xmz::log::error("Failed to install dependency:", dep);
							visiting.erase(package);
							return 1;
						}
					}
				}
			}
			std::string download_url = found_repo;
			if (download_url.back() != '/') { download_url += "/"; }
			download_url += pkg_filepath;
			std::string cache_filename = pkg_filename.empty() ? 
				std::filesystem::path(pkg_filepath).filename().string() : pkg_filename;
			std::string download_cache = cache_dir + "/downloads/" + cache_filename;
			if (xmz::aux::is_dir(cache_dir + "/downloads") == 1) { xmz::fs::mkdir(cache_dir + "/downloads"); }
			xmz::log::info("Installing package:", package);
			xmz::println("	Version:", pkg_version);
			xmz::println("	From:", found_repo);
			xmz::println("	URL:", download_url);
			std::string error_msg;
			if (!a1pm::curl::download_file(download_url, download_cache, error_msg)) {
				xmz::log::error("Download failed:", error_msg);
				return 1;
			}
			auto file_size = xmz::aux::get_file_size(download_cache);
			xmz::log::info("Download completed (", file_size, " bytes)");
			if (!pkg_sha256.empty()) {
				xmz::log::info("Verifying file integrity...");
				std::string sha256_actual = a1pm::ssl::get_file_hash_hex(download_cache);
				if (sha256_actual != pkg_sha256) {
					xmz::log::error("SHA256 verification failed!");
					xmz::println("	Expected:", pkg_sha256);
					xmz::println("	Actual:  ", sha256_actual);
					xmz::fs::recrmdir(download_cache);
					visiting.erase(package);
					return 1;
				}
				xmz::log::info("File integrity verified");
			}
			int install_result = a1mod::install(download_cache);
			xmz::fs::rmfile(download_cache);
			if (install_result == 0) {
				installed.insert(package);
				xmz::log::info("Package installed successfully:", package);
			}
			visiting.erase(package);
			return install_result;
		}
	} /* namespace aux */
	inline int install_package(const std::string& package) {
		std::set<std::string> installed;
		std::set<std::string> visiting;
		for (const auto& [name, entry] : a1mod::g_module_db.modules) { installed.insert(name); }
		return aux::install_package_with_deps(package, installed, visiting);
	}

	inline int remove_package(const std::string& package) { return a1mod::remove(package); }

	inline void list_repos() {
		a1pm::config cfg;
		//a1::ini::ini_parser pini;
		xmz::println("current source list");
		xmz::fs::readfile(cfg.repo_f);
	}

	inline int search_package(const std::string& query) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (query.empty()) {
			xmz::log::error("Search query cannot be empty");
			return 1;
		}

		if (!pini.parse_file(cfg.repo_f)) {
			xmz::log::error("Failed to parse repo config:", cfg.repo_f);
			return 1;
		}

		auto sections = pini.get_sec();
		if (sections.empty()) {
			xmz::log::error("No repositories configured");
			return 1;
		}

		std::string cache_dir = cfg.pm_cache;
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }

		struct search_result {
			std::string package;
			std::string version;
			std::string name;
			std::string description;
			std::string repo;
			bool is_installed;
		};
		std::vector<search_result> results;
		std::string query_lower = query;
		std::transform(query_lower.begin(), query_lower.end(), query_lower.begin(), ::tolower);
		for (const auto& repo_url : sections) {
			std::string repo_name = url_to_repo_name(repo_url);
			std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
			if (xmz::aux::is_file(metadata_file) != 0) {
				xmz::log::warn("Repository metadata not found:", repo_url);
				xmz::log::info("Please sync repository first");
				continue;
			}

			a1::ini::ini_parser pkg_parser;
			if (!pkg_parser.parse_file(metadata_file)) {
				xmz::log::warn("Failed to parse metadata for:", repo_url);
				continue;
			}

			auto pkg_sections = pkg_parser.get_sec();
			for (const auto& pkg_name : pkg_sections) {
				std::string version = pkg_parser.get(pkg_name, "version", "");
				std::string name = pkg_parser.get(pkg_name, "name", pkg_name);
				std::string description = pkg_parser.get(pkg_name, "description", "");
				//std::string descr_msg = pkg_parser.get(pkg_name, "descr", "");
				//if (description.empty()) { description = descr_msg; }
				std::string pkg_lower = pkg_name;
				std::string name_lower = name;
				std::string desc_lower = description;
				std::transform(pkg_lower.begin(), pkg_lower.end(), pkg_lower.begin(), ::tolower);
				std::transform(name_lower.begin(), name_lower.end(), name_lower.begin(), ::tolower);
				std::transform(desc_lower.begin(), desc_lower.end(), desc_lower.begin(), ::tolower);
				bool match = false;
				if (pkg_lower.find(query_lower) != std::string::npos ||
					name_lower.find(query_lower) != std::string::npos ||
					desc_lower.find(query_lower) != std::string::npos) {
					match = true;
				}

				if (match) {
					search_result result;
					result.package = pkg_name;
					result.version = version;
					result.name = name.empty() ? pkg_name : name;
					result.description = description;
					result.repo = repo_url;
					result.is_installed = a1mod::g_module_db.modules.find(pkg_name) != 
										  a1mod::g_module_db.modules.end();
					results.push_back(result);
				}
			}
		}

		if (results.empty()) {
			xmz::println("No packages found matching:", query);
			return 0;
		}

		xmz::println("Search Results for '", query, "'");
		xmz::println("Found", results.size(), "package(s):");
		xmz::println("");
		int count = 1;
		for (const auto& result : results) {
			xmz::println(count, ". ", result.name);
			xmz::println("	 Package: ", result.package);
			xmz::println("	 Version: ", result.version);
			xmz::println("	 Description: ", result.description);
			xmz::println("	 Repository: ", result.repo);
			xmz::println("	 Status: ", result.is_installed ? "[INSTALLED]" : "[NOT INSTALLED]");
			xmz::println("");
			count++;
		}
		return 0;
	}

	inline int search_package_detail(const std::string& query) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (query.empty()) {
			xmz::log::error("Search query cannot be empty");
			return 1;
		}

		if (!pini.parse_file(cfg.repo_f)) {
			xmz::log::error("Failed to parse repo config:", cfg.repo_f);
			return 1;
		}
	
		auto sections = pini.get_sec();
		if (sections.empty()) {
			xmz::log::error("No repositories configured");
			return 1;
		}

		std::string cache_dir = cfg.pm_cache;
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
		bool found = false;
		for (const auto& repo_url : sections) {
			std::string repo_name = url_to_repo_name(repo_url);
			std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
			if (xmz::aux::is_file(metadata_file) != 0) { continue; }
			a1::ini::ini_parser pkg_parser;
			if (!pkg_parser.parse_file(metadata_file)) { continue; }
			std::string version = pkg_parser.get(query, "version", "");
			if (!version.empty()) {
				found = true;
				std::string name = pkg_parser.get(query, "name", query);
				std::string description = pkg_parser.get(query, "description", "");
				//if (description.empty()) { description = pkg_parser.get(query, "descr", ""); }
				std::string author = pkg_parser.get(query, "author", "");
				std::string maintainer = pkg_parser.get(query, "maintainer", "");
				std::string depends = pkg_parser.get(query, "depends", "");
				std::string depends_apt = pkg_parser.get(query, "depends_apt", "");
				std::string filepath = pkg_parser.get(query, "filepath", "");
				std::string sha256 = pkg_parser.get(query, "sha256", "");
				std::string size = pkg_parser.get(query, "size", "");
				bool is_installed = a1mod::g_module_db.modules.find(query) != 
									a1mod::g_module_db.modules.end();
				xmz::println("Package Details");
				xmz::println("Package: ", query);
				xmz::println("Name: ", name);
				xmz::println("Version: ", version);
				xmz::println("Description: ", description);
				if (!author.empty()) { xmz::println("Author: ", author); }
				if (!maintainer.empty()) { xmz::println("Maintainer: ", maintainer); }
				if (!depends.empty()) { xmz::println("Depends: ", depends); }
				if (!depends_apt.empty()) { xmz::println("System Depends: ", depends_apt); }
				if (!size.empty()) { xmz::println("Size: ", size); }
				xmz::println("Repository: ", repo_url);
				xmz::println("Status: ", is_installed ? "INSTALLED" : "NOT INSTALLED");
				if (is_installed) {
					auto it = a1mod::g_module_db.modules.find(query);
					if (it != a1mod::g_module_db.modules.end()) {
						xmz::println("Installed Location: ", it->second.install_base);
						xmz::println("Installed Date: ", it->second.installed_date);
					}
				}
				break;
			}
		}

		if (!found) {
			xmz::log::error("Package not found:", query);
			xmz::log::info("Try using 'search' to find similar packages");
			return 1;
		}
		return 0;
	}

	inline int update_repo(const std::string& repo_url) {
		a1pm::config cfg;
		if (repo_url.empty()) {
			xmz::log::error("Repository URL cannot be empty");
			return 1;
		}
		std::string repo_name = url_to_repo_name(repo_url);
		std::string cache_dir = cfg.pm_cache;
		std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
		std::string metadata_url = repo_url;
		if (metadata_url.back() != '/') { metadata_url += "/"; }
		metadata_url += "Packages.ini";
		xmz::log::info("Updating repository:", repo_url);
		xmz::println("	URL:", metadata_url);
		std::string error_msg;
		if (!a1pm::curl::download_file(metadata_url, metadata_file, error_msg)) {
			xmz::log::error("Failed to update repository:", error_msg);
			return 1;
		}
		a1::ini::ini_parser parser;
		if (!parser.parse_file(metadata_file)) {
			xmz::log::error("Invalid metadata file:", metadata_file);
			xmz::fs::rmfile(metadata_file);
			return 1;
		}
		a1::ini::ini_parser repo_parser;
		repo_parser.parse_file(cfg.repo_f);
		std::string time = xmz::get_time_str();
		repo_parser.set(repo_url, "last_sync", time);
		repo_parser.save_cover(cfg.repo_f);
		auto packages = parser.get_sec();
		xmz::log::info("Repository updated successfully");
		xmz::println("	Packages:", packages.size());
		xmz::println("	Last sync:", time);
		return 0;
	}

	inline int update_all_repos() {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (!pini.parse_file(cfg.repo_f)) {
			xmz::log::error("Failed to parse repo config:", cfg.repo_f);
			return 1;
		}
		auto sections = pini.get_sec();
		if (sections.empty()) {
			xmz::log::error("No repositories configured");
			return 1;
		}
		xmz::log::info("Updating all repositories...");
		xmz::println("Total repositories:", sections.size());
		xmz::println("");
		int success_count = 0;
		int fail_count = 0;
		for (const auto& repo_url : sections) {
			if (update_repo(repo_url) == 0) { success_count++; } else { fail_count++; }
			xmz::println("");
		}
		xmz::log::info("Update completed");
		xmz::println("	Successful:", success_count);
		xmz::println("	Failed:", fail_count);
		return fail_count > 0 ? 1 : 0;
	}

	inline int check_updates() {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (!pini.parse_file(cfg.repo_f)) {
			xmz::log::error("Failed to parse repo config:", cfg.repo_f);
			return 1;
		}
		auto sections = pini.get_sec();
		if (sections.empty()) {
			xmz::log::error("No repositories configured");
			return 1;
		}
		std::string cache_dir = cfg.pm_cache;
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
		struct update_info {
			std::string package;
			std::string current_version;
			std::string new_version;
			std::string repo;
		};
		std::vector<update_info> updates;
		for (const auto& [pkg_name, entry] : a1mod::g_module_db.modules) {
			std::string current_version = entry.version;
			std::string found_new_version;
			std::string found_repo;
			for (const auto& repo_url : sections) {
				std::string repo_name = url_to_repo_name(repo_url);
				std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
				if (xmz::aux::is_file(metadata_file) != 0) { continue; }
				a1::ini::ini_parser pkg_parser;
				if (!pkg_parser.parse_file(metadata_file)) { continue; }
				std::string version = pkg_parser.get(pkg_name, "version", "");
				if (!version.empty()) {
					if (a1mod::version::compare(version, current_version) > 0) {
						found_new_version = version;
						found_repo = repo_url;
						break;
					}
				}
			}

			if (!found_new_version.empty()) {
				update_info info;
				info.package = pkg_name;
				info.current_version = current_version;
				info.new_version = found_new_version;
				info.repo = found_repo;
				updates.push_back(info);
			}
		}

		if (updates.empty()) {
			xmz::println("All packages are up to date!");
			return 0;
		}
		
		xmz::println("Available Updates");
		xmz::println("Found", updates.size(), "package(s) with updates:");
		xmz::println("");
		for (const auto& update : updates) {
			xmz::println("	", update.package);
			xmz::println("	  Current version:", update.current_version);
			xmz::println("	  New version:	  ", update.new_version);
			xmz::println("	  Repository:	  ", update.repo);
			xmz::println("");
		}

		xmz::println("To update all packages, run: update");
		xmz::println("To update specific package: update <package>");
		return 0;
	}

	inline int update_package(const std::string& package) {
		auto it = a1mod::g_module_db.modules.find(package);
		if (it == a1mod::g_module_db.modules.end()) {
			xmz::log::error("Package not installed:", package);
			xmz::log::info("Use 'install' to install it first");
			return 1;
		}

		xmz::log::info("Updating package:", package);
		xmz::println("	Current version:", it->second.version);
		xmz::log::info("Removing old version...");
		if (a1mod::remove(package) != 0) {
			xmz::log::error("Failed to remove old version");
			return 1;
		}

		xmz::log::info("Installing new version...");
		return install_package(package);
	}

	inline int update_all_packages() {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		xmz::log::info("Updating repository metadata first...");
		if (update_all_repos() != 0) {
			xmz::log::warn("Some repositories failed to update, continuing...");
		}

		xmz::log::info("Checking for package updates...");
		if (!pini.parse_file(cfg.repo_f)) {
			xmz::log::error("Failed to parse repo config:", cfg.repo_f);
			return 1;
		}

		auto sections = pini.get_sec();
		if (sections.empty()) {
			xmz::log::error("No repositories configured");
			return 1;
		}

		std::string cache_dir = cfg.pm_cache;
		std::vector<std::string> packages_to_update;
		for (const auto& [pkg_name, entry] : a1mod::g_module_db.modules) {
			std::string current_version = entry.version;
			bool has_update = false;
			for (const auto& repo_url : sections) {
				std::string repo_name = url_to_repo_name(repo_url);
				std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
				if (xmz::aux::is_file(metadata_file) != 0) { continue; }
				a1::ini::ini_parser pkg_parser;
				if (!pkg_parser.parse_file(metadata_file)) { continue; }
				std::string version = pkg_parser.get(pkg_name, "version", "");
				if (!version.empty() && a1mod::version::compare(version, current_version) > 0) {
					has_update = true;
					break;
				}
			}

			if (has_update) { packages_to_update.push_back(pkg_name); }
		}

		if (packages_to_update.empty()) {
			xmz::println("All packages are up to date!");
			return 0;
		}

		xmz::println("Found", packages_to_update.size(), "package(s) to update:");
		for (const auto& pkg : packages_to_update) { xmz::println("	-", pkg); }
		xmz::println("");
		int success_count = 0;
		int fail_count = 0;
		for (const auto& pkg : packages_to_update) {
			if (update_package(pkg) == 0) { success_count++; } else { fail_count++; }
			xmz::println("");
		}
		xmz::log::info("Update completed");
		xmz::println("	Successful:", success_count);
		xmz::println("	Failed:", fail_count);
		return fail_count > 0 ? 1 : 0;
	}

	inline int update(const std::string& target = "") { if (target.empty()) { return update_all_packages(); } else { if (target.find("http://") == 0 || target.find("https://") == 0) { return update_repo(target); } else { return update_package(target); } } }

} /* namespace a1pm */


====== end =====
===== cxxa1/a1/core/config.hpp =====
// config.hpp
#pragma once
#include <string>
#include <libxmz/io.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>
#include <a1/core/myini.hpp>
#include <cstdlib>

#ifdef A1_USE_GUI_CFG
#include <a1/core/a1gui_config.hpp>
#else
namespace a1::config {
    class jb_path {
    public:
        std::string jb = get_jb();
        std::string a1_dir = jb + "/a1";
        std::string a1config = a1_dir + "/configs";
        std::string a1_script = jb + "/usr/local/bin/a1";
        std::string 
a1_return_script = jb + "/usr/local/bin/a1-return";
        std::string a1ctl_script = jb + "/usr/local/bin/a1ctl";
        std::string config_dir = a1config;
        std::string backup_dir = a1_dir + "/backup";
        std::string bak_d = backup_dir;
        std::string high_f = a1_dir + "/high_priority.list";
        std::string low_f = a1_dir + "/low_priority.list";
        std::string custom_f = a1_dir + "/custom_priority.list";
        std::string mod_dir = a1_dir + "/modules";
        std::string mod_cfg = mod_dir + "/config.ini";
        std::string mod_list = mod_dir + "/module.list.ini";
    private:
        std::string get_jb() { const char *v = std::getenv("jb"); return v ? v : ""; }
    };
} /* namespace a1::config */
#endif /* A1_USE_GUI_CFG */

====== end =====
===== cxxa1/a1/core/version.hpp =====
// version.hpp
#pragma once
#include <string>
namespace a1::_coreapi::version {
    std::string a1_version = "2.0.0.186";
    std::string a1ctl_version = "2.0.0.105";
    std::string a1mod_version = "2.0.0.106";
    std::string a1pm_version = "2.0.0.95";
}

namespace a1::_coreapi {
    using a1::_coreapi::version::a1_version;
    using a1::_coreapi::version::a1ctl_version;
    using a1::_coreapi::version::a1mod_version;
    using a1::_coreapi::version::a1pm_version;
}

namespace a1::version {
    std::string a1 = a1::_coreapi::version::a1_version;
    std::string a1ctl = a1::_coreapi::version::a1ctl_version;
    std::string a1mod = a1::_coreapi::version::a1mod_version;
    std::string a1pm = a1::_coreapi::version::a1pm_version;
}

====== end =====
===== cxxa1/a1/core/a1core.hpp =====
// a1core.hpp
#pragma once

#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sys/resource.h>
#include <cerrno>
#include <mach/mach_time.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <sys/types.h>
#include <signal.h>
#include <regex>
#include <notify.h>
#include <optional>
#include <sys/stat.h>
#include <unordered_map>
#include <sys/sysctl.h>
#include <sstream>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/get_sys_list.hpp>
#include <a1/core/config.hpp>
#include <src/bin/bundle/libproc.h>
#include <src/bin/bundle/bundle_pid.hpp>
#include <src/bin/bundle/pid_bundle.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>

namespace a1 {
    inline constexpr int HIGH_PRIORITY = 30;
    inline constexpr int LOW_PRIORITY = 10;
    inline constexpr int DEFAULT_PRIORITY = 20;
    // colors
    namespace colors {
        inline std::string red = "\033[0;31m";
        inline std::string green = "\033[0;32m";
        inline std::string yellow = "\033[1;33m";
        inline std::string blue = "\033[0;34m";
        inline std::string bright_yellow = "\033[93m";
        inline std::string bright_blue = "\033[94m";
        inline std::string nc = "\033[0m";
    } /* namespace color */

    // default system list
    inline void get_sys_high_list() { xmz::print(a1::coreapi::lists::high); }
    inline std::string get_sys_high_list_str() { return a1::coreapi::lists::high; }
    inline void get_system_low_list() { xmz::print(a1::coreapi::lists::low); }
    inline std::string get_sys_low_list_str() { return a1::coreapi::lists::low; }

    // priority list read
    class priority_manager {
    public:
        void read_priority_lists(bool filter = false) {
            a1::config::jb_path g_jb;
            // empty the previous data
            high_priority_list_.clear();
            low_priority_list_.clear();
            custom_priority_list_.clear();
            // list of parsing systems
            auto system_high = xmz::str::split(a1::coreapi::lists::high, "\n");
            auto system_low = xmz::str::split(a1::coreapi::lists::low, "\n");
            // remove the blank line
            auto remove_empty = [](std::vector<std::string>& vec) {
                vec.erase(std::remove_if(vec.begin(), vec.end(), 
                    [](const std::string& s) { return s.empty(); }), vec.end());
            };
            remove_empty(system_high);
            remove_empty(system_low);
            // read the high-priority list
            read_list_file(g_jb.a1_dir + "/high_priority.list", 
                       high_priority_list_, system_high, filter, true);
            // read the low-priority list
            read_list_file(g_jb.a1_dir + "/low_priority.list", 
                           low_priority_list_, system_low, filter, false);
            // read custom priority
            read_custom_list(g_jb.a1_dir + "/custom_priority.list");
        }
    
        const std::vector<std::string>& get_high_list() const { return high_priority_list_; }
        const std::vector<std::string>& get_low_list() const { return low_priority_list_; }
        const std::map<std::string, int>& get_custom_list() const { return custom_priority_list_; }
    private:
        std::vector<std::string> high_priority_list_;
        std::vector<std::string> low_priority_list_;
        std::map<std::string, int> custom_priority_list_;
        void read_list_file(const std::string& filepath, 
                            std::vector<std::string>& target_list,
                            const std::vector<std::string>& system_list,
                            bool filter, bool is_high_priority) {
            if (xmz::aux::is_file(filepath) == 0) {
                std::string content = xmz::fs::readfile_str(filepath);
                auto lines = xmz::str::split(content, "\n");
                for (const auto& line : lines) {
                    std::string trimmed = xmz::str::trim(line);
                    if (trimmed.empty() || trimmed[0] == '#') continue;
                    if (filter) {
                        // check whether it is in the system list
                        bool is_system = std::find(system_list.begin(), 
                                                  system_list.end(), 
                                                  trimmed) != system_list.end();
                        if (is_high_priority && trimmed == "SpringBoard") {
                            // SpringBoard always keeps
                            target_list.push_back(trimmed);
                        } else if (!is_system) {
                            // only non-system processes are added
                            target_list.push_back(trimmed);
                        }
                    } else {
                        target_list.push_back(trimmed);
                    }
                }
            } else {
                // the document does not exist
                if (!filter) {
                    target_list = system_list;  // use the system default list
                } else if (is_high_priority) {
                    target_list = {"SpringBoard"};  // the filter mode only retains SpringBoard
                }
            }
        }

        void read_custom_list(const std::string& filepath) {
            if (xmz::aux::exist(filepath) != 0) return;
            std::string content = xmz::fs::readfile_str(filepath);
            auto lines = xmz::str::split(content, "\n");
            for (const auto& line : lines) {
                std::string trimmed = xmz::str::trim(line);
                if (trimmed.empty() || trimmed[0] == '#') continue;
                auto parts = xmz::str::split(trimmed, "=");
                if (parts.size() >= 2) {
                    std::string process_name = xmz::str::trim(parts[0]);
                    std::string priority_str = xmz::str::trim(parts[1]);
                    int priority = 20;  // default value
                    if (!priority_str.empty()) {
                        try {
                            priority = std::stoi(priority_str);
                        } catch (...) {
                            priority = 20;
                        }
                    }
                    custom_priority_list_[process_name] = priority;
                }
            }
        }
    };

    // by process find PID
    inline int find_pid_by_name(const char *target, pid_t& pid) {
        pid = a1::bin::bundle_pid(target);
        //xmz::println(pid);
        return pid == -1 ? 1 : 0;
    }

    namespace get {
        inline std::string process_name_by_pid(int pid) {
            char name[1024] = {0};
            int ret = proc_name(pid, name, sizeof(name));
            if (ret > 0) { return std::string(name); }
            return "";
        }

        // get process nice value
        inline int nice_by_pid(pid_t pid) {
            errno = 0;
            int nice_val = getpriority(PRIO_PROCESS, pid);
            if (nice_val == -1 && errno != 0) { return 0; }
            return nice_val;
        }

        // get process CPU useage rate
        inline int cpu_by_pid(int pid, double interval = 0.5) {
            // the first sampling
            proc_taskinfo info1;
            if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info1, sizeof(info1)) <= 0) { return -1; }
            uint64_t time1 = info1.pti_total_user + info1.pti_total_system;
            // wait for a short time
            usleep(interval * 1000000);
            // the second sampling
            proc_taskinfo info2;
            if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info2, sizeof(info2)) <= 0) { return -1; }
            uint64_t time2 = info2.pti_total_user + info2.pti_total_system;
            // calculate the CPU utilization rate
            uint64_t delta = time2 - time1;
            // switch mach_absolute_time
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);
            double elapsed_ns = (double)delta * timebase.numer / timebase.denom;
            double interval_ns = interval * 1e9;
            int percent = (int)(elapsed_ns / interval_ns * 100.0 + 0.5);
            return percent;
        }
    } /* namespace get */

    namespace set {
        // by renice set priority
        inline bool priority_renice(pid_t pid, int priority) {
            int orig_uid = getuid();
            // convert priority to nice value
            int renice_value = priority - 20;
            // restricted range
            if (renice_value < -20) renice_value = -20;
            if (renice_value > 19) renice_value = 19;
            // set the process priority
            if (setuid(0) != 0) {
                xmz::log::error("setuid(0) failed!");
                return false;
            }
            if (setpriority(PRIO_PROCESS, pid, renice_value) == -1) {
                xmz::println("Failed to set priority for PID", pid, ":", strerror(errno));
                setuid(orig_uid);
                return false;
            }
            setuid(orig_uid);
            return true;
        }

        namespace _jetsan {
            extern "C" {
                int memorystatus_control(uint32_t command, pid_t pid, uint32_t flags, 
                                void *buffer, size_t buffersize);
            }
            enum JetsamPriority : int32_t {
                JETSAM_PRIORITY_IDLE                 = 0,
                JETSAM_PRIORITY_IDLE_DEFERRED        = 1,
                JETSAM_PRIORITY_AGING_BAND1          = 2,
                JETSAM_PRIORITY_AGING_BAND2          = 3,
                JETSAM_PRIORITY_AGING_BAND3          = 4,
                JETSAM_PRIORITY_AGING_BAND4          = 5,
                JETSAM_PRIORITY_AGING_BAND5          = 6,
                JETSAM_PRIORITY_BACKGROUND           = 10,
                JETSAM_PRIORITY_BACKGROUND_DEFERRED  = 11,
                JETSAM_PRIORITY_MAIL                 = 15,
                JETSAM_PRIORITY_PHONE                = 16,
                JETSAM_PRIORITY_UI_SUPPORT           = 17,
                JETSAM_PRIORITY_FOREGROUND           = 18,
                JETSAM_PRIORITY_FOREGROUND_DEFERRED  = 19,
                JETSAM_PRIORITY_FOREGROUND_SUPPORT   = 20,
                JETSAM_PRIORITY_CRITICAL             = 21
            };

            constexpr uint32_t MEMORYSTATUS_CMD_SET_PRIORITY = 1;
            constexpr uint32_t MEMORYSTATUS_CMD_GET_PRIORITY = 2;
            constexpr uint32_t MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT = 3;
            inline bool priority_jetsam_impl(pid_t pid, int32_t priority) {
            int orig_uid = getuid();
            if (setuid(0) != 0) {
                xmz::log::error("setuid(0) failed!");
                return false;
            }
                int ret = memorystatus_control(
                    MEMORYSTATUS_CMD_SET_PRIORITY, 
                    pid, 
                    priority, 
                    nullptr, 
                    0
                );
                if (ret == 0) {
                    setuid(orig_uid);
                    return true;
                } else {
                    setuid(orig_uid);
                    return false;
                }
            }
        } /* namespace _jetsam */

        inline bool priority_jetsamctl(pid_t pid, int32_t priority) {
            a1::config::jb_path g_jb;
            const char* jb = g_jb.jb.c_str();
            if (_jetsan::priority_jetsam_impl(pid, priority)) { return true; }
            return false;
        }

        // Universal priority set
        inline bool priority(int pid, int priority) noexcept {
            return priority_renice(pid, priority) || 
                   priority_jetsamctl(pid, priority);
        }
    } /* namespace set */

    // process tweak func
    inline int adjust_process_auto_impl(int pid, const char* process_name, const char* priority_str) {
        std::string proc_name;
        // process_name
        if (process_name == nullptr && pid <= 0) {
            xmz::log::error("adjust_process_auto_impl: need either pid or process_name");
            return 1;
        }
    
        if (process_name != nullptr) { proc_name = process_name; }

        if (pid <= 0 && !proc_name.empty()) {
            pid = a1::bin::bundle_pid(proc_name.c_str());
            if (pid <= 0) {
                xmz::log::error("Cannot find PID for process:", proc_name);
                return 1;
            }
        }

        if (proc_name.empty() && pid > 0) {
            const char* raw = a1::bin::pid_bundle(pid);
            if (raw != nullptr) {
                proc_name = raw;
                free((void*)raw);
            }
        }

        if (priority_str == nullptr) {
            xmz::log::error("adjust_process_auto_impl: need priority!");
            return 1;
        }
    
        int priority = DEFAULT_PRIORITY;
        try {
            priority = std::stoi(priority_str);
        } catch (...) {
            xmz::log::error("Invalid priority value:", priority_str);
            return 1;
        }

        if (kill(pid, 0) == -1) {
            if (errno == ESRCH) {
                xmz::log::error("Process", pid, "does not exist");
                return 1;
            }
            xmz::log::error("Cannot access process", pid);
            return 1;
        }

        int renice_value = priority - 20;
        if (renice_value < -20) renice_value = -20;
        if (renice_value > 19) renice_value = 19;
    
        bool success = false;

        if (a1::set::priority_renice(pid, priority)) {
            xmz::log::info("[Auto]", proc_name, "(PID:", pid, ") ->", priority);
            success = true;
        } else {
            xmz::log::error("Failed to set renice for PID", pid);
        }

        if (!success && a1::set::priority_jetsamctl(pid, priority)) {
            xmz::log::info("[Auto]", proc_name, "(PID:", pid, ") -> jetsam", priority);
            success = true;
        } else if (!success) {
            xmz::log::error("Failed to set jetsam priority for PID", pid);
        }
    
        return success ? 0 : 1;
    }

    inline int adjust_process_auto(int pid, const char *priority) {
        const char *process_name = nullptr;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(const char *process_name, const char *priority) {
        int pid = -1;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(int pid, const char *process_name, const char *priority) { return adjust_process_auto_impl(pid, process_name, priority); }

    // get target process list (used for dynamic optimization)
    inline std::vector<std::pair<int, std::string>> get_target_processes(const std::string& excluded_list = "") {
        std::vector<std::pair<int, std::string>> processes;
        // build exclusion pattern
        std::string exclude_pattern = "SpringBoard|backboardd|CommCenter|syslogd|apsd|configd|launchd|kernel|syslog_relay";
        std::string full_pattern = exclude_pattern;
        full_pattern = exclude_pattern + "|" + excluded_list;

        std::regex pattern(full_pattern);
        // get number of processes
        int num_pids = proc_listpids(PROC_ALL_PIDS, 0, nullptr, 0);
        if (num_pids <= 0) return processes;
        // allocate buffer and get PIDs
        std::vector<int> pids(num_pids);
        num_pids = proc_listpids(PROC_ALL_PIDS, 0, pids.data(), num_pids * sizeof(int));
        if (num_pids <= 0) return processes;
        int count = num_pids / sizeof(int);
        for (int i = 0; i < count; i++) {
            int pid = pids[i];
            if (pid == 0) continue;
            // get process name
            char name[PROC_PIDPATHINFO_MAXSIZE] = {0};
            int ret = proc_name(pid, name, sizeof(name));
            if (ret > 0) {
                std::string comm(name);
                // skip kernel processes
                if (comm.find("kernel_") == 0) continue;
                // skip excluded processes
                if (std::regex_search(comm, pattern)) continue;
                processes.emplace_back(pid, comm);
            }
        }
        return processes;
    }

    // lockstate check
    inline bool check_lockstate() {
        auto lockstate = []() -> std::optional<uint64_t> {
            int token;
            if (notify_register_check("com.apple.springboard.lockstate", &token) != NOTIFY_STATUS_OK) { return std::nullopt; }
            uint64_t state;
            uint32_t status = notify_get_state(token, &state);
            notify_cancel(token);
            if (status != NOTIFY_STATUS_OK) { return std::nullopt; }
            return state;
        }();

        if (lockstate) {
            if (*lockstate == 1) { return true; }
        } else {
            if (xmz::aux::is_file("/tmp/.a1_notifyutil_warnd") == 1) {
                xmz::log::warn("notifyutil not found, cannot detect lock state.");
                xmz::fs::touch("/tmp/.a1_notifyutil_warned");
            }
        }
        return false; // no lockstate
    }

    // config file Surveillance
    inline bool check_config_changes(std::unordered_map<std::string, time_t>& mtime_map) {
        a1::config::jb_path g_jb;
        bool reload_needed = false;
        std::vector<std::string> conf_files = {
            g_jb.a1_dir + "/high_priority.list",
            g_jb.a1_dir + "/low_priority.list",
            g_jb.a1_dir + "/custom_priority.list"
        };

        for (const auto& f : conf_files) {
            struct stat file_stat;
            time_t current_mtime = 0;
            if (stat(f.c_str(), &file_stat) == 0) { current_mtime = file_stat.st_mtime; }
            if (mtime_map[f] != current_mtime) {
                reload_needed = true;
                mtime_map[f] = current_mtime;
            }
        }
        return reload_needed;
    }

    // kern option tweak
    inline int apply_kernel_patches() {
        xmz::println("Applying kernel patches...");
        xmz::println("_______________________________");

        int orig_uid = getuid();
        if (setuid(0) != 0) { 
            xmz::log::error("setuid(0) failed!"); 
            return 1;
        }

        auto set_kern_sysctl_by_name = [](const std::string& name, int new_value) -> bool {
            size_t size = sizeof(new_value);
            if (sysctlbyname(name.c_str(), nullptr, nullptr, &new_value, size) == -1) {
                xmz::log::error("Failed to set", name, ":", strerror(errno));
                return false;
            }
            return true;
        };

        auto get_and_set_kern_sysctl = [&](const std::string& name, int new_value, const std::string& display_name) {
            int current_value = 0;
            size_t size = sizeof(current_value);
            if (sysctlbyname(name.c_str(), &current_value, &size, nullptr, 0) == 0) {
                xmz::log::info("Current", display_name, ":", current_value);
            } else {
                xmz::log::warn("Cannot read current", display_name);
            }

            if (set_kern_sysctl_by_name(name, new_value)) {
                xmz::log::info("Successfully set", display_name, "to", new_value);
                return true;
            }
            return false;
        };

        std::vector<std::tuple<std::string, int, std::string>> kern_params = {
            {"kern.wq_max_threads", 4096, "kern.wq_max_threads"},
            {"kern.maxvnodes", 100000, "kern.maxvnodes"},
            {"kern.memorystatus_sysprocs_idle_delay_time", 0, "kern.memorystatus_sysprocs_idle_delay_time"},
            {"kern.memorystatus_apps_idle_delay_time", 0, "kern.memorystatus_apps_idle_delay_time"}
        };

        for (const auto& [name, value, display] : kern_params) { get_and_set_kern_sysctl(name, value, display); }

        auto set_vm_sysctl_by_name = [](const std::string& name, int new_value) -> bool {
            size_t size = sizeof(new_value);
            if (sysctlbyname(name.c_str(), nullptr, nullptr, &new_value, size) == -1) {
                xmz::log::error("Failed to set", name, ":", strerror(errno));
                return false;
            }
            return true;
        };

        auto get_and_set_vm_sysctl = [&](const std::string& name, int new_value, const std::string& display_name) {
            int current_value = 0;
            size_t size = sizeof(current_value);
            if (sysctlbyname(name.c_str(), &current_value, &size, nullptr, 0) == 0) {
                xmz::log::info("Current", display_name, ":", current_value);
            } else {
                xmz::log::warn("Cannot read current", display_name);
            }

            if (set_vm_sysctl_by_name(name, new_value)) {
                xmz::log::info("Successfully set", display_name, "to", new_value);
                return true;
            }
            return false;
        };

        std::vector<std::tuple<std::string, int, std::string>> vm_params = {
            {"vm.vm_page_free_min", 10000, "vm.vm_page_free_min"},
            {"vm.vm_page_free_reserved", 256, "vm.vm_page_free_reserved"}
        };
        for (const auto& [name, value, display] : vm_params) { get_and_set_vm_sysctl(name, value, display); }

        auto get_vm_swapusage = []() {
            struct xsw_usage swap_usage;
            size_t swap_len = sizeof(swap_usage);
            if (sysctlbyname("vm.swapusage", &swap_usage, &swap_len, nullptr, 0) == -1) {
                xmz::log::error("Failed to get vm.swapusage:", strerror(errno));
            } else {
                xmz::log::info(
                    "vm.swapusage: total=", swap_usage.xsu_total, 
                    " used=", swap_usage.xsu_used, 
                    " avail=", swap_usage.xsu_avail
                );
            }
        };
        get_vm_swapusage();

        setuid(orig_uid);

        xmz::println("Done.");
        xmz::println("_______________________________________________");
        return 0;
    }

    // launchd process tweak
    inline void adjust_launchd(int priority) {
        xmz::println("Adjusting launchd priority...");
        int launchd_pid = 1;
        if (set::priority(launchd_pid, priority)) {
            xmz::log::info("Set launchd priority to jetsam", priority);
        } else {
            xmz::log::error("Failed to adjust launchd priority");
        }
    }

    // clean func
    inline void kill_pid(const char *script_name = nullptr) {
        if (script_name == nullptr) {
            script_name = "a1";
        }
        int count = 0;

        auto get_a1_pid = [](const std::string& script_name) -> std::vector<int> {
            std::vector<int> pids;
            int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
            size_t size = 0;
            if (sysctl(mib, 4, nullptr, &size, nullptr, 0) < 0) { return pids; }
            std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc));
            if (sysctl(mib, 4, procs.data(), &size, nullptr, 0) < 0) { return pids; }
            size_t count = size / sizeof(kinfo_proc);
            for (size_t i = 0; i < count; ++i) {
                int pid = procs[i].kp_proc.p_pid;
                if (pid <= 0) continue;
                std::string comm = procs[i].kp_proc.p_comm;
                if (pid == getpid()) continue;
                std::string cmdline;
                char buf[PROC_PIDPATHINFO_MAXSIZE] = {0};
                int ret = proc_pidpath(pid, buf, sizeof(buf));
                if (ret > 0) { cmdline = buf; }
                bool match_a1 = false;
                if (comm.size() >= 2) { match_a1 = (comm.substr(comm.size() - 2) == "a1"); }
                if (!match_a1 && !cmdline.empty()) {
                    size_t pos = cmdline.find_last_of('/');
                    std::string basename = (pos != std::string::npos) ? cmdline.substr(pos + 1) : cmdline;
                    match_a1 = (basename.size() >= 2 && basename.substr(basename.size() - 2) == "a1");
                }
                bool match_script = !script_name.empty() && 
                     (comm.find(script_name) != std::string::npos ||
                     cmdline.find(script_name) != std::string::npos);
                if (match_a1 || match_script) { pids.push_back(pid); }
            }
            return pids;
        };
        std::vector<int> pids = get_a1_pid(script_name);
        pid_t current_pid = getpid();
        pid_t parent_pid = getppid();

        for (int pid_int : pids) {
            pid_t pid = static_cast<pid_t>(pid_int);
            if (pid != current_pid && pid != parent_pid && pid > 0) {
                xmz::println("Kill", script_name, "process PID:", pid);
                kill(pid, SIGTERM);
                usleep(500000);
                int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
                struct kinfo_proc info;
                size_t info_size = sizeof(info);
                if (sysctl(mib, 4, &info, &info_size, nullptr, 0) == 0 && info.kp_proc.p_stat != 0) { kill(pid, SIGKILL); }
                count++;
            }
        }

        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        size_t size = 0;
        if (sysctl(mib, 4, nullptr, &size, nullptr, 0) == 0) {
            std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc));
            if (sysctl(mib, 4, procs.data(), &size, nullptr, 0) == 0) {
                size_t proc_count = size / sizeof(kinfo_proc);
                for (size_t i = 0; i < proc_count; ++i) {
                    if (procs[i].kp_proc.p_stat == SZOMB) {
                        pid_t pid = procs[i].kp_proc.p_pid;
                        std::string comm = procs[i].kp_proc.p_comm;
                        if (comm.find(script_name) != std::string::npos) { kill(pid, SIGKILL); }
                    }
                }
            }
        }
        xmz::println("Cleaned", count, "old processes");
    }

    // Core of monitoring mode
    inline void run_monitor(int interval = 15, const char *mode_name = "Scheduled Guard") {
        a1::config::jb_path g_jb;
        xmz::println(mode_name, " Working(interval:", interval, "s)");
        xmz::println("Monitoring processes periodically...");
        xmz::println("_______________________________________________");

        std::unordered_map<int, bool> processed_pids;
        std::unordered_map<std::string, int> priority_map;
        std::unordered_map<std::string, time_t> file_mtime;
        std::vector<std::string> EXCLUDED_PROCESSES = {
        "kernel_task", "launchd", "syslogd", "UserEventAgent",
        "configd", "CommCenter", "SpringBoard", "backboardd"
        };

        priority_manager pm;
        //pm.read_priority_lists(true);
        pm.read_priority_lists(false);

        int circulate = 0;
        while (true) {
            circulate++;
            xmz::log::info("Current number of cycles:", circulate);
            // Check lockstate
            if (check_lockstate()) {
                xmz::log::info("It is in the lock screen state and has been dormant");
                sleep(60);
                continue;
            }

            // Check config file changes
            if (check_config_changes(file_mtime)) {
                pm.read_priority_lists(true);
                priority_map.clear();
                // build priority map from high priority list
                for (const auto& p : pm.get_high_list()) {
                    priority_map[p] = HIGH_PRIORITY;
                }
                // build priority map from low priority list
                for (const auto& p : pm.get_low_list()) {
                    priority_map[p] = LOW_PRIORITY;
                }
                // add custom priorities
                for (const auto& [proc, prio] : pm.get_custom_list()) {
                    priority_map[proc] = prio;
                }
            }
            // get process list (simulating ps output)
            auto processes = get_target_processes();
            // Clear dead PIDs
            int dead_pids = 0;
            for (auto it = processed_pids.begin(); it != processed_pids.end(); ) {
                if (kill(it->first, 0) != 0) {
                    it = processed_pids.erase(it);
                    dead_pids++;
                } else {
                    ++it;
                }
            }
            if (dead_pids > 0) {
               xmz::log::info("Cleared", dead_pids, "dead PIDs from tracking");
            }
            // process adjustments
            for (const auto& [process_name, target_priority] : priority_map) {
                if (process_name.empty()) continue;
                std::vector<int> pids_found;
                // try to find by bundle ID (if looks like xxx.xxx.xxx)
                if (std::regex_search(process_name, std::regex("^[a-zA-Z0-9_]+\\.[a-zA-Z0-9_]+\\.[a-zA-Z0-9_]+"))) {
                    // try bundle_pid first
                    int bundle_pid_result = a1::bin::bundle_pid(process_name.c_str());
                    if (bundle_pid_result != -1) {
                        pids_found.push_back(bundle_pid_result);
                        xmz::log::info("  Process:", process_name, "exists");
                    } else {
                        // fall back to searching in process list
                        for (const auto& [pid, name] : processes) {
                            if (name == process_name) {
                                pids_found.push_back(pid);
                                xmz::log::info("  Process:", process_name, "exists");
                            }
                        }
                    }
                } else {
                    // find by process name
                    for (const auto& [pid, name] : processes) {
                        if (name == process_name) {
                            pids_found.push_back(pid);
                            xmz::log::info("  Process:", name, "is", process_name);
                        }
                    }
                }

                for (int pid : pids_found) {
                    if (pid <= 0) continue;
                    if (processed_pids[pid]) continue;
                    // check if process should be excluded
                    bool excluded = false;
                    if (process_name != "SpringBoard") {
                        for (const auto& excl : EXCLUDED_PROCESSES) {
                            if (process_name == excl) {
                                excluded = true;
                                break;
                            }
                        }
                    }
                    if (excluded) continue;
                    // get current nice value
                    int current_nice = get::nice_by_pid(pid);
                    if (current_nice == -1) continue;
                    int target_nice = target_priority - 20;
                    if (current_nice == target_nice) continue;
                    // adjust the process
                    if (adjust_process_auto(pid, process_name.c_str(), std::to_string(target_priority).c_str()) == 0) {
                        processed_pids[pid] = true;
                        xmz::log::info("  PID:", pid, "priority value", current_nice, "->", target_nice);
                    }
                }
            }
            // control processed_pids size (limit to 200 as in original)
            if (processed_pids.size() > 200) {
                std::unordered_map<int, bool> new_processed_pids;
                int count = 0;
                for (const auto& [pid, _] : processed_pids) {
                    if (count >= 500) break;
                    new_processed_pids[pid] = true;
                    count++;
                }
                processed_pids = std::move(new_processed_pids);
            }
            sleep(interval);
        }
    }

    // compatible interface
    inline void scheduled_guard() { return run_monitor(15, "Scheduled Guard"); }
    inline void auto_adjust() { run_monitor(1, "Auto-Adjust"); }
    // a1ctl:custom_auth_adjust, a1ctl:custom_scheduled_guard
    inline void start_monitor(int interval, const std::string& mode_name) {
        return run_monitor(interval, mode_name.c_str());
    }
    inline void custom_auto_adjust() { start_monitor(1, "Auto-Adjust"); }
    inline void custom_scheduled_guard() { start_monitor(15, "Scheduled-Guard"); }

} /* namespace a1 */

====== end =====
===== cxxa1/a1/core/myini.hpp =====
// myini.hpp
#ifndef A1_MYINI_HPP
#define A1_MYINI_HPP

#include <string>
#include <map>
#include <vector>
#include <libxmz/fs.hpp>
#include <libxmz/str.hpp>

namespace a1::ini {
class ini_parser {
public:
    bool parse_file(const std::string& filepath) {
        std::string content = xmz::fs::readfile_str(filepath);
        if (content.empty()) return false;
        return parse_str(content);
    }

    bool parse_str(const std::string& content) {
        data_.clear();
        std::string currentSection;
        auto lines = xmz::str::split(content, "\n");
        for (auto line : lines) {
            line = remove_comments(line);
            line = xmz::str::trim(line);
            if (line.empty()) continue;
            if (line[0] == '[' && line.back() == ']') {
                std::string sectionName = xmz::str::trim(
                    line.substr(1, line.size() - 2));
                sectionName = unescape_string(sectionName);
                currentSection = sectionName;
                data_.try_emplace(currentSection);
                continue;
            }
            auto pos_eq = line.find('=');
            auto pos_col = line.find(':');
            auto pos = std::string::npos;
            if (pos_eq != std::string::npos && pos_col != std::string::npos)
                pos = std::min(pos_eq, pos_col);
            else if (pos_eq != std::string::npos)
                pos = pos_eq;
            else if (pos_col != std::string::npos)
                pos = pos_col;

            if (pos != std::string::npos) {
                auto key = xmz::str::trim(line.substr(0, pos));
                auto val = xmz::str::trim(line.substr(pos + 1));
                key = unescape_string(key);
                val = unescape_string(val);
                if (!key.empty()) { data_[currentSection][key] = val; }
            }
        }
        return true;
    }

    std::string get(const std::string& sec,
                    const std::string& key,
                    const std::string& def = "") const {
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        const std::map<std::string, std::map<std::string, std::string>>* current = &data_;
        for (const auto& s : sections) {
            auto it = current->find(s);
            if (it == current->end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    auto ki = direct_it->second.find(key);
                    return ki != direct_it->second.end() ? ki->second : def;
                }
                return def;
            }
            current = &it->second;
            if (current->empty() || current->begin()->second.empty()) { if (&current == &it->second) break; }
        }
        if (!sections.empty()) {
            auto last_it = data_.find(sections.back());
            if (last_it == data_.end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    auto ki = direct_it->second.find(key);
                    return ki != direct_it->second.end() ? ki->second : def;
                }
            } else {
                auto ki = last_it->second.find(key);
                if (ki != last_it->second.end()) return ki->second;
            }
        }
        return def;
#else
        auto si = data_.find(sec);
        if (si == data_.end()) return def;
        auto ki = si->second.find(key);
        return ki != si->second.end() ? ki->second : def;
#endif
    }

    int get_int(const std::string& sec,
                const std::string& key,
                int def = 0) const {
        auto s = get(sec, key);
        if (s.empty()) return def;
        try { return std::stoi(s); }
        catch (...) { return def; }
    }

    bool get_bool(const std::string& sec,
                  const std::string& key,
                  bool def = false) const {
        auto s = get(sec, key);
        if (s.empty()) return def;
        return s == "true" || s == "1" || s == "yes" || s == "on";
    }

    std::vector<std::string> getSections() const {
        std::vector<std::string> out;
        for (auto& [k, _] : data_) out.push_back(k);
        return out;
    }

    inline std::vector<std::string> get_sec() const { return getSections(); }

    std::vector<std::string> get_key(const std::string& sec) const {
        std::vector<std::string> out;
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        const std::map<std::string, std::map<std::string, std::string>>* current = &data_;
        for (const auto& s : sections) {
            auto it = current->find(s);
            if (it == current->end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    for (auto& [k, _] : direct_it->second) out.push_back(k);
                    return out;
                }
                return out;
            }
            current = &it->second;
        }
        if (!sections.empty()) {
            auto last_it = data_.find(sections.back());
            if (last_it == data_.end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    for (auto& [k, _] : direct_it->second) out.push_back(k);
                }
            } else {
                for (auto& [k, _] : last_it->second) out.push_back(k);
            }
        }
        return out;
#else
        auto it = data_.find(sec);
        if (it != data_.end())
            for (auto& [k, _] : it->second) out.push_back(k);
        return out;
#endif
    }

    void clear() { data_.clear(); }

    bool save_cover(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) { 
                out += escape_string(k) + "=" + escape_string(v) + "\n"; 
            }
        }
        return xmz::fs::writefile(out, filepath);
    }

    bool save_append(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) { 
                out += escape_string(k) + "=" + escape_string(v) + "\n"; 
            }
        }
        return xmz::fs::append(out, filepath);
    }

    void set(const std::string& sec, const std::string& key, 
             const std::string& val) { 
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        data_[full_path][key] = val;
#else
        data_[sec][key] = val;
#endif
    }

    void set_int(const std::string& sec, const std::string& key, int val) { set(sec, key, std::to_string(val)); }

    void set_bool(const std::string& sec, const std::string& key, bool val) { set(sec, key, val ? "true" : "false"); }

    bool remove_key(const std::string& sec, const std::string& key) {
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        auto si = data_.find(full_path);
#else
        auto si = data_.find(sec);
#endif
        if (si != data_.end()) { return si->second.erase(key) > 0; }
        return false;
    }

    bool remove_section(const std::string& sec) { 
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        return data_.erase(full_path) > 0;
#else
        return data_.erase(sec) > 0;
#endif
    }

    bool rmkey(const std::string& sec, const std::string& key) { return remove_key(sec, key); }
    bool rmsec(const std::string& sec) { return remove_section(sec); }

    static std::string escape_string(const std::string& str) {
        std::string result;
        result.reserve(str.size() * 2);
        for (char c : str) {
            switch (c) {
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                case '\v': result += "\\v"; break;
                case '\f': result += "\\f"; break;
                case '\b': result += "\\b"; break;
                case '\\': result += "\\\\"; break;
                case '\"': result += "\\\""; break;
                case '\'': result += "\\'"; break;
                case ';': result += "\\;"; break;
                case '#': result += "\\#"; break;
                default: result += c; break;
            }
        }
        return result;
    }

    static std::string unescape_string(const std::string& str) {
        std::string result;
        result.reserve(str.size());
        for (size_t i = 0; i < str.size(); ++i) {
            if (str[i] == '\\' && i + 1 < str.size()) {
                char next = str[i + 1];
                switch (next) {
                    case 'n': result += '\n'; ++i; break;
                    case 'r': result += '\r'; ++i; break;
                    case 't': result += '\t'; ++i; break;
                    case 'v': result += '\v'; ++i; break;
                    case 'f': result += '\f'; ++i; break;
                    case 'b': result += '\b'; ++i; break;
                    case '\\': result += '\\'; ++i; break;
                    case '\"': result += '\"'; ++i; break;
                    case '\'': result += '\''; ++i; break;
                    case ';': result += ';'; ++i; break;
                    case '#': result += '#'; ++i; break;
                    default: result += str[i]; break;
                }
            } else {
                result += str[i];
            }
        }
        return result;
    }

    static std::string remove_comments(const std::string& line) {
        bool in_quotes = false;
        bool escape_next = false;
        std::string result;
        for (size_t i = 0; i < line.size(); ++i) {
            char c = line[i];
            if (escape_next) {
                result += c;
                escape_next = false;
                continue;
            }
            if (c == '\\') {
                if (i + 1 < line.size()) {
                    char next = line[i + 1];
                    if (next == ';' || next == '#') {
                        result += c;
                        result += next;
                        ++i;
                        continue;
                    }
                }
                escape_next = true;
                result += c;
                continue;
            }
            if (c == '"') {
                in_quotes = !in_quotes;
                result += c;
                continue;
            }
            if (!in_quotes && (c == ';' || c == '#')) { return result; }
            result += c;
        }
        return result;
    }
private:
    std::map<std::string, std::map<std::string, std::string>> data_;
#ifdef A1_INI_EXPAND
    static std::vector<std::string> split_path(const std::string& path) {
        std::vector<std::string> parts;
        size_t start = 0;
        size_t end = path.find('.');
        while (end != std::string::npos) {
            parts.push_back(path.substr(start, end - start));
            start = end + 1;
            end = path.find('.', start);
        }
        parts.push_back(path.substr(start));
        return parts;
    }
#endif
};
} /* namespace a1::ini */
#endif /* A1_MYINI_HPP */

====== end =====
===== cxxa1/a1/core/set_defaults.hpp =====
// set_defaults.hpp
#pragma once
#include <string>
#include <cstdlib>
#include <unordered_map>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>

namespace a1::_coreapi {
struct set_defaults_config {
    int high_priority = 39;
    int low_priority = 0;
    int launchd_priority = 20;
    int jetsam_priority = 15;
    int max_cpu_percent = 15;
    // mode on/off
    bool loop_mode = false;
    bool auto_adjust = false;
    bool scheduled_guard = false;
    bool experimental = false;
    bool log_reincarnation = false;
    bool custom_priority_enabled = false;
    bool debug_mode = true;
    bool module_switch = false;
    // gap set
    int optimize_interval = 1800;
    int loop_sleep_interval = 5;
    // Permission set
    bool use_sudo_all = true;
    bool use_sudo_a1 = true;
    bool use_sudo_a1ctl = true;
    bool use_root_a1ctl = true;
    // other
    bool compat_mode = false;
    bool lock_use = true;
    bool dynamic_optimization = false;
};

inline set_defaults_config& get_config() {
    static set_defaults_config config;
    return config;
}

inline std::string config_text = []() -> std::string {
    return R"(#config.ini

#Priority configuration
high_priority = 0
low_priority = 39
launchd_priority = 20
jetsam_priority = 15

#mode on/off
loop_mode = false
auto_adjust = false
auto_apply = false
scheduled_guard = false
#experimental = false
log_reincarnation = false
custom_priority_enabled = false
debug_mode = true
module_switch = false

#gap set
optimize_interval = 1800
loop_sleep_interval = 5

#permission set
#use_sudo_all = false
#use_sudo_a1 = false
#use_sudo_a1ctl = false
#use_root_a1ctl = false

#other
compat_mode = false
lock_use = true
dynamic_optimization = false

)";
}();
} /* namespace a1::_coreapi */

namespace a1::coreapi {
inline void set_defaults() {
    auto& g_config = a1::_coreapi::get_config();

    a1::config::jb_path g_jb;
    std::string config_path = g_jb.a1config + "/config.ini";

    a1::ini::ini_parser parser;
    bool has_config_file = parser.parse_file(config_path);

    auto get_config_int = [&](const char* key, int default_val) -> int {
        if (!has_config_file) return default_val;
        return parser.get_int("", key, default_val);
    };

    auto get_config_bool = [&](const char* key, bool default_val) -> bool {
        if (!has_config_file) return default_val;
        return parser.get_bool("", key, default_val);
    };

    // read all configuration items
    g_config.high_priority       = get_config_int("high_priority", 30);
    g_config.low_priority        = get_config_int("low_priority", 10);
    g_config.launchd_priority    = get_config_int("launchd_priority", 20);
    g_config.jetsam_priority     = get_config_int("jetsam_priority", 15);
    g_config.max_cpu_percent     = get_config_int("max_cpu_percent", 15);
    g_config.optimize_interval   = get_config_int("optimize_interval", 1800);
    g_config.loop_sleep_interval = get_config_int("loop_sleep_interval", 5);

    g_config.loop_mode                = get_config_bool("loop_mode", false);
    g_config.auto_adjust              = get_config_bool("auto_adjust", false);
    g_config.scheduled_guard          = get_config_bool("scheduled_guard", false);
    g_config.experimental             = get_config_bool("experimental", false);
    g_config.log_reincarnation        = get_config_bool("log_reincarnation", false);
    g_config.custom_priority_enabled  = get_config_bool("custom_priority_enabled", false);
    g_config.debug_mode               = get_config_bool("debug_mode", true);
    g_config.module_switch            = get_config_bool("module_switch", false);
    g_config.use_sudo_all             = get_config_bool("use_sudo_all", true);
    g_config.use_sudo_a1              = get_config_bool("use_sudo_a1", true);
    g_config.use_sudo_a1ctl           = get_config_bool("use_sudo_a1ctl", true);
    g_config.use_root_a1ctl           = get_config_bool("use_root_a1ctl", true);
    g_config.compat_mode              = get_config_bool("compat_mode", false);
    g_config.lock_use                 = get_config_bool("lock_use", true);
    g_config.dynamic_optimization     = get_config_bool("dynamic_optimization", false);
}

inline const _coreapi::set_defaults_config& set_defaults_cfg() { return _coreapi::get_config(); }

inline std::string cfg_text = []() -> std::string { return _coreapi::config_text; }();

inline const _coreapi::set_defaults_config& get_cfg() { return _coreapi::get_config(); }

} /* namespace a1::coreapi */

====== end =====
===== cxxa1/a1/core/a1ctlcore.hpp =====
// a1ctlcore.hpp
#pragma once

#include <a1/core/a1core.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/set_defaults.hpp>

#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdlib>
#include <stdlib.h>
#include <filesystem>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/time.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    inline void default_config() {
        a1::config::jb_path g_jb;
        std::string cfg_f = g_jb.a1config + "/config.ini";
        xmz::fs::writefile(a1::coreapi::cfg_text, cfg_f);
    }

    inline void a1_conf() { return default_config(); }

    inline void init_config() {
        a1::config::jb_path g_jb;
        if (xmz::aux::path_exist(g_jb.a1_dir) == 1)
            xmz::fs::mkdir(g_jb.a1_dir);

        if (xmz::aux::is_dir(g_jb.a1config) == 1)
            xmz::fs::mkdir(g_jb.a1config);

        if (xmz::aux::is_dir(g_jb.bak_d) == 1)
            xmz::fs::mkdir(g_jb.bak_d);

        if (xmz::aux::is_file(g_jb.high_f) == 1)
            xmz::fs::writefile(a1::coreapi::lists::high, g_jb.high_f);

        if (xmz::aux::is_file(g_jb.low_f) == 1) {
            xmz::fs::writefile(a1::coreapi::lists::low, g_jb.low_f);
        }

        if (xmz::aux::is_file(g_jb.custom_f) == 1)
            xmz::fs::writefile({
                "#custom priority format: process_name = value",
                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)",
                "#eample: com.apple.springboard = 0"
            }, g_jb.custom_f);
    }

    inline int check_config_conflict() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_file(config_file) == 1) {
            xmz::log::warn("file:", config_file, "not exist!");
            xmz::log::warn("The default configuration has been automatically created");
            xmz::fs::writefile(a1::coreapi::cfg_text, config_file);
        }

        if (!pini.parse_file(config_file)) return -1;
        bool loop_mode = pini.get_bool("", "loop", false);
        bool auto_adjust = pini.get_bool("", "auto_adjust", false);
        bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        int conflicts = 0;
        if (loop_mode == true && auto_adjust == true) {
            xmz::log::warn("loop_mode and auto_adjust cannot be turned on at the same time!");
            conflicts++;
        }

        if (loop_mode == true && scheduled_guard == true) {
            xmz::log::warn("loop_mode and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (auto_adjust == true && scheduled_guard == true) {
            xmz::log::warn("auto_adjust and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (conflicts != 0) {
            xmz::log::warn("It is recommended to adjust the configuration to prevent conflicts.");
            return 1;
        }

        return 0;
    }

    inline int check_a1_running() { if (a1::bin::bundle_pid("a1") == -1) { return 1; } else { return 0; } }

    inline int check_if_should_run_a1() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        if (xmz::aux::is_file(config_file) == 0) {
            pini.parse_file(config_file);
            pini.get_bool("", "loop", false);
            pini.get_bool("", "auto_adjust", false);
            pini.get_bool("", "scheduled_guard", false);
            return 0;
        }
        return 1;
    }

    // backstage start up
    inline void start_a1_service() {
        a1::config::jb_path g_jb;
        xmz::log::info("check the configuration...");
        if (check_config_conflict() != 0) {
            xmz::log::error("configuration conflict, startup has stopped");
            return;
        }

        a1::kill_pid();
        sleep(1);

        std::string a1_script;

        if (xmz::aux::is_file((g_jb.jb + "/usr/local/bin/a1")) == 0) { a1_script = g_jb.jb + "/usr/local/bin/a1"; }

        if (a1_script != "") {
            xmz::log::info("pull up A1 service...");
            pid_t pid = fork();
            pid_t pid2 = 0;
            if (pid == 0) {
                pid2 = fork();
                if (pid2 == 0) {
                    execl((g_jb.jb + "/usr/local/bin/a1").c_str(), nullptr, nullptr, nullptr);
                    _exit(127);
                }
                _exit(0);
            } else if (pid > 0) {
                waitpid(pid, nullptr, 0);
            }
            
            sleep(2);
            if (kill(pid2, 0) == 0) {
                xmz::log::info("A1 has been activated(PID:", pid2, ")");
            } else {
                xmz::log::error("A1 startup failed");
            }
        }
    }

    inline void auto_apply_check() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        bool auto_apply = false;
        bool loop = false;
        bool auto_adjust = false;
        bool scheduled_guard = false;

        if (xmz::aux::is_file(config_file) == 0) {
            pini.parse_file(config_file);
            auto_apply = pini.get_bool("", "auto_apply", false);
            loop = pini.get_bool("", "loop", false);
            auto_adjust = pini.get_bool("", "auto_adjust", false);
            scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        }

        if (auto_apply == true) {
            if (check_config_conflict() == 1) {
                xmz::log::error("configuration conflict, automatic application has stopped");
                return;
            } else {
                xmz::log::info("automatic application is taking effect...");
                a1::kill_pid();
                sleep(2);
            }
        }

        if (loop == true || auto_adjust == true || scheduled_guard == true) {
            start_a1_service();
        } else {
            xmz::log::warn("A1 is not started");
        }
    }

    inline void check_status() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;

        if (check_a1_running() == 0) {
            xmz::log::info("A1 is running");
            if (xmz::aux::is_file(config_file) == 0) {
                pini.parse_file(config_file);
                bool loop = pini.get_bool("", "loop", false);
                bool log_reincarnation = pini.get_bool("", "log_reincarnation", false);
                bool custom_priority_enabled = pini.get_bool("", "custom_priority_enabled", false);
                bool auto_apply = pini.get_bool("", "auto_apply", false);
                bool auto_adjust = pini.get_bool("", "auto_adjust", false);
                bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
                bool module_switch = pini.get_bool("", "module_switch", false);

                bool compat_mode = pini.get_bool("", "compat_mode", false);
                bool lock_use = pini.get_bool("", "lock_use", false);

                auto auxoutcfg = [&](const std::string& name, bool configs = false) -> std::string {
                    if (configs == false) {
                        std::string outcfg = name + " is turned off";
                        return outcfg;
                    } else {
                        std::string outcfg = name + " is turned on";
                        return outcfg;
                    }
                };

                xmz::println("configuration status:");
                xmz::println("    ", auxoutcfg("loop", loop));
                xmz::println("    ", auxoutcfg("auto_adjust", auto_adjust));
                xmz::println("    ", auxoutcfg("scheduled_guard", scheduled_guard));
                xmz::println("    ", auxoutcfg("log_reincarnation", log_reincarnation));
                xmz::println("    ", auxoutcfg("auto_apply", auto_apply));
                xmz::println("    ", auxoutcfg("custom_priority_enabled", custom_priority_enabled));
                xmz::println("    ", auxoutcfg("module_switch", module_switch));
                xmz::println("    ", auxoutcfg("compat_mode", compat_mode));
                xmz::println("    ", auxoutcfg("lock_use", lock_use));
                check_config_conflict();
            }
        } else {
            xmz::log::warn("A1 is not running");
        }
    }

    inline int start_a1() {
        a1::config::jb_path g_jb;
        xmz::println("Start A1 optimization...");
        if (check_a1_running() == 0) {
            xmz::println("A1 is already running.");
            xmz::println("use 'a1ctl restart' to restart A1");
            return 0;
        }

        a1::kill_pid();
        sleep(2);
        start_a1_service();
        sleep(1);

        int pid = a1::bin::bundle_pid("a1");
        std::string cxxa1_path = g_jb.a1_dir + "/bin/cxxa1";

        if (pid != -1) {
            xmz::log::info("A1 has been activated(PID:", pid, ")");
            return 0;
        } else {
            xmz::log::error("A1 Startup failed, try the backup startup method...");
            pid_t pid2 = fork();
            if (pid2 == 0) {
                if (std::getenv("jb") != nullptr) {
                    execl(cxxa1_path.c_str(), nullptr, nullptr);
                } else {
                    setenv("jb", g_jb.jb.c_str(), 1);
                    execl(cxxa1_path.c_str(), nullptr, nullptr);
                }
            }

            sleep(1);
            if (a1::bin::bundle_pid("a1") != -1) {
                xmz::log::info("A1 has been activated(PID:", pid2, ")");
                return 0;
            } else {
                xmz::log::error("A1 failed to start!");
                return 1;
            }
        }
        return 1;
    }

    inline void start_a1_foreground() {
        a1::config::jb_path g_jb;
        std::string a1_script = g_jb.jb + "/usr/local/bin/a1";
        xmz::log::info("Start A1 optimization (foreground mode)...");
        a1::kill_pid();
        sleep(1);
        xmz::println("_______________________________________________");
        if (xmz::aux::is_file(a1_script) == 0) {
            execl(a1_script.c_str(), nullptr, nullptr);
        } else {
            xmz::log::error("Unable to find A1 script", a1_script);
        }
    }

    inline void update_config(const std::string& key_name, bool value = false) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_dir(g_jb.a1_dir) == 1) { xmz::fs::mkdir(g_jb.a1_dir); }
        if (xmz::aux::is_file(config_file) == 1) { a1_conf(); }
        pini.parse_file(config_file);
        pini.set("", key_name, value ? "true" : "false");
        pini.save_cover(config_file);
        xmz::log::info("the configuration has been updated:", key_name, "=", value);
    }

    inline void update_config_int(const std::string& key_name, int value) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_dir(g_jb.a1_dir) == 1) { xmz::fs::mkdir(g_jb.a1_dir); }
        if (xmz::aux::is_file(config_file) == 1) { a1_conf(); }
        pini.parse_file(config_file);
        pini.set_int("", key_name, value);
        pini.save_cover(config_file);
        xmz::log::info("the configuration has been updated:", key_name, "=", value);
    }

    inline void set_auto_apply(const bool opt) {
        if (opt == true) {
            update_config("auto_apply", true);
            xmz::log::info("automatic effect has been turned on.");
            auto_apply_check();
        } else {
            update_config("auto_apply", false);
            xmz::log::info("automatic effect has been turned off.");
        }
    }

    inline void show_config() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_file(config_file) == 0) {
            xmz::println("Current configuration");
            xmz::println("----------------");
            xmz::println(xmz::fs::readfile_str(config_file));
            xmz::println("----------------");
            pini.parse_file(config_file);
            xmz::println("priority setting:");
            xmz::println("  high priority: renice 20 (jetsam", pini.get_int("", "high_priority", 39), ")");
            xmz::println("  low priority: renice 19 (jetsam", pini.get_int("", "low_priority", 19), ")");
            xmz::println("  launchd: renice 0 (jetsam", pini.get_int("", "high_priority", 20), ")");
            xmz::println("loop settings:");
            xmz::println("  loop sleep:", pini.get_int("", "loop_sleep_interval", 5));
            xmz::println("other settings:");
            xmz::println("  take effect automatically:", pini.get_bool("", "auto_apply", false));
            xmz::println("  real-time automatic adjustment:", pini.get_bool("", "auto_adjust", false));
            xmz::println("  regular guard:", pini.get_bool("", "scheduled_guard", false));
            xmz::println("  sudo password-free mode(all):", pini.get_bool("", "use_sudo_all", false));
            xmz::println("  sudo password-free mode(a1):", pini.get_bool("", "use_sudo_a1", false));
            xmz::println("  sudo password-free mode(a1ctl):", pini.get_bool("", "use_sudo_a1ctl", false));
            xmz::println("  root-free execution a1ctl:", pini.get_bool("", "use_root_a1ctl", false));
            xmz::println("  compatible mode:", pini.get_bool("", "compat_mode", false));
        } else {
            xmz::log::error("the document could not be found:", config_file);
            return;
        }
    }

    inline void add_priority(const std::string& priority_opt, const std::string& process_name, int priority_value = -255) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;

        if (priority_opt == "high" || priority_opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f) == 0) {
                if (xmz::fs::findstr(g_jb.high_f, process_name) == false) {
                    xmz::fs::append(process_name, g_jb.high_f);
                    xmz::log::info(process_name, "has been added to the high priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the high-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.high_f, "not exist!");
            }
        } else if (priority_opt == "low" || priority_opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f) == 0) {
                if (xmz::fs::findstr(g_jb.low_f, process_name) == false) {
                    xmz::fs::append(process_name, g_jb.low_f);
                    xmz::log::info(process_name, "has been added to the low priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the low-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.low_f, "not exist!");
            }
        } else if (priority_opt == "custom" || priority_opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f) == 0) {
                if (xmz::fs::findstr(g_jb.custom_f, process_name) == false) {
                    if (priority_value != -255 && priority_value >= 0 && priority_value < 100) {
                        pini.set("", process_name, std::to_string(priority_value));
                        xmz::log::info(process_name, "has been added to the custom priority list");
                        auto_apply_check();
                    } else {
                        xmz::log::error("priority_value need >= 0 < 100!");
                    }
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the custom-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.custom_f, "not exist!");
            }
        } else {
            xmz::log::error("unknown parameters:", priority_opt);
            return;
        }
    }

    inline void remove_priority(const std::string& priority_opt, const std::string& process_name, int priority_value = -255) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;

        if (priority_opt == "high" || priority_opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f) == 0) {
                if (xmz::fs::findstr(g_jb.high_f, process_name) == true) {
                    xmz::fs::rmfilestr(g_jb.high_f, process_name);
                    xmz::log::info(process_name, "has been removed from the high priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the high priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.high_f, "not exist!");
            }
        } else if (priority_opt == "low" || priority_opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f) == 0) {
                if (xmz::fs::findstr(g_jb.low_f, process_name) == true) {
                    xmz::fs::rmfilestr(g_jb.low_f, process_name);
                    xmz::log::info(process_name, "has been removed from the low priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the low priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.low_f, "not exist!");
            }
        } else if (priority_opt == "custom" || priority_opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f) == 0) {
                if (xmz::fs::findstr(g_jb.custom_f, process_name) == true) {
                    pini.rmkey("", process_name);
                    xmz::log::info(process_name, "has been removed from the custom priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the custom priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.custom_f, "not exist!");
            }
        } else {
            xmz::log::error("unknown parameters:", priority_opt);
            return;
        }
    }

    inline void list_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        if (opt == "high" || opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f) == 0) {
                xmz::println("high priority list");
                xmz::fs::readfile(g_jb.high_f);
            } else {
                xmz::log::error("the high priority list does not exist");
            }
        } else if (opt == "low" || opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f) == 0) {
                xmz::println("low priority list");
                xmz::fs::readfile(g_jb.low_f);
            } else {
                xmz::log::error("the low priority list does not exist");
            }
        } else if (opt == "custom" || opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f) == 0) {
                xmz::println("custom priority list");
                xmz::fs::readfile(g_jb.custom_f);
            } else {
                xmz::log::error("the custom priority list does not exist.");
            }
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }

    inline void clear_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        auto empty = [&](const std::string& name) -> void {
            std::string display_name = name;
            if (name == "h") { display_name = "high"; } 
            else if (name == "l") { display_name = "low"; } 
            else if (name == "c") { display_name = "custom"; }
            xmz::fs::emptyfile(g_jb.high_f);
            xmz::log::info("the", display_name, "priority list has been cleared");
            auto_apply_check();
        };
        if (opt == "high" || opt == "h") {
            empty("high");
        } else if (opt == "low" || opt == "l") {
            empty("low");
        } else if (opt == "custom" || opt == "c") {
            empty("custom");
            xmz::fs::writefile({
                "#custom priority format: process_name = value",
                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)",
                "#eample: com.apple.springboard = 0"
            }, g_jb.custom_f);
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }

    inline void compat_mode(const bool opt) {
        using xmz::aux::parselink;
        a1::config::jb_path g_jb;
        if (opt == true) {
            update_config("compat_mode", true);
            const char* jbdpkgarch_cstr = std::getenv("jbdpkgarch");
            std::string jbdpkgarch = jbdpkgarch_cstr ? jbdpkgarch_cstr : "";
            if (jbdpkgarch == "iphoneos-arm64e") {
                if (xmz::aux::path_exist(parselink(g_jb.jb)) == 1) return;
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/jb")) == 1) { xmz::fs::mklndir(g_jb.jb, g_jb.jb + "/var/jb"); }
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/a1")) == 1) { xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/var/"); }
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs")) == 0) { if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs/var/a1")) == 1) { xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/rootfs/var/a1"); } }
                xmz::log::info("the operation is successful, and the compatibility mode has been turned on.");
            } else {
                if (jbdpkgarch == "iphoneos-arm64" || jbdpkgarch == "iphoneos-arm") {
                    xmz::log::info("rootless does not need compatibility mode, and this operation will not be executed.");
                } else {
                    xmz::log::warn("incompatible jailbreak:", jbdpkgarch);
                }
            }
        } else if (opt == false) {
            update_config("compat_mode", false);
            xmz::log::info("the compatibility mode is turned off");
        }
    }

    inline int set_priority_value(const std::string& priority_type, int value = -255) {
        if (priority_type == "") {
            xmz::log::error("priority_type cannot be empty, priority_type need high|low|launchd");
            return 1;
        }

        if (value != -255 && value >= 0 && value <= 39) {
            if (priority_type == "high" || priority_type == "h") {
                update_config_int("high_priority", value);
            } else if (priority_type == "low" || priority_type == "l") {
                update_config_int("low_priority", value);
            } else if (priority_type == "launchd" || priority_type == "lchd") {
                update_config_int("launchd_priority", value);
            } else {
                xmz::log::error("undefined options:", priority_type);
                xmz::log::error("priority_type cannot be empty, priority_type need high|low|launchd");
                return 1;
            }
        } else {
            xmz::log::error("value must be between 0 and 39");
            return 1;
        }
        return 0;
    }

    inline void mod_switch_mode(const bool opt) {
        if (opt) {
            update_config("module_switch", true);
            xmz::log::info("the module system has been turned on");
        } else {
            update_config("module_switch", false);
            xmz::log::info("the module system has been shut down");
        }
    }
} /* namespace a1ctl */

====== end =====
===== cxxa1/a1/core/a1gui_config.hpp =====
// a1gui_config.hpp
#pragma once
#include <string>
#include <libxmz/io.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>
#include <a1/core/myini.hpp>
#include <cstdlib>

namespace a1::config {
    class jb_path {
    public:
        std::string jb;
        std::string a1_dir;
        std::string a1config;
        std::string a1_script;
        std::string a1_return_script;
        std::string a1ctl_script;
        std::string config_dir;
        std::string backup_dir;
        std::string bak_d;
        std::string high_f;
        std::string low_f;
        std::string custom_f;
        std::string mod_dir;
        std::string mod_cfg;
        std::string mod_list;
        jb_path() = default;
        void init() {
            jb = get_jb();
            a1_dir = jb + "/a1";
            a1config = a1_dir + "/configs";
            a1_script = jb + "/usr/local/bin/a1";
            a1_return_script = jb + "/usr/local/bin/a1-return";
            a1ctl_script = jb + "/usr/local/bin/a1ctl";
            config_dir = a1config;
            backup_dir = a1_dir + "/backup";
            bak_d = backup_dir;
            high_f = a1_dir + "/high_priority.list";
            low_f = a1_dir + "/low_priority.list";
            custom_f = a1_dir + "/custom_priority.list";
            mod_dir = a1_dir + "/modules";
            mod_cfg = mod_dir + "/config.ini";
            mod_list = mod_dir + "/module.list.ini";
        }
    private:
        std::string get_jb() { const char *v = std::getenv("jb"); return v ? v : ""; }
};
} /* namespace a1::config */

====== end =====
===== cxxa1/a1/core/a1modcore.hpp =====
// a1mod.hpp
#pragma once
#include <string>
#include <vector>
#include <map>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/a1mod_version.hpp>
#include <a1/core/mod/a1mod_depends.hpp>
#include <a1/core/mod/zip.hpp>

namespace a1mod {
    // module database
    struct module_db {
        std::map<std::string, module_entry> modules;
        std::vector<std::string> enabled_modules;
        std::vector<std::string> disabled_modules;
        std::string last_updated;
        bool is_enabled(const std::string& name) const { return std::find(enabled_modules.begin(), enabled_modules.end(), name) != enabled_modules.end(); }
        bool is_disabled(const std::string& name) const { return std::find(disabled_modules.begin(), disabled_modules.end(), name) != disabled_modules.end(); }
    };
    // global module database instance
    inline module_db g_module_db;
    // load the database from the file system
    inline bool load_db_from_file() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        if (!parser.parse_file(db_path)) {
            xmz::log::warn("no existing module database found, creating new one");
            return false;
        }
        g_module_db.modules.clear();
        g_module_db.enabled_modules.clear();
        g_module_db.disabled_modules.clear();
        auto sections = parser.get_sec();
        for (const auto& section : sections) {
            //if (section == "GLOBAL") continue;
            module_entry entry;
            entry.name = parser.get(section, "name", "");
            entry.package = parser.get(section, "package", "");
            entry.version = parser.get(section, "version", "");
            entry.description = parser.get(section, "description", "");
            entry.author = parser.get(section, "author", "");
            entry.maintainer = parser.get(section, "maintainer", "");
            entry.path = parser.get(section, "path", "");
            entry.install_base = parser.get(section, "install_base", "");
            entry.installed_date = parser.get(section, "installed_date", "");
            entry.last_updated = parser.get(section, "last_updated", "");
            std::string depends_str = parser.get(section, "depends", "");
            if (!depends_str.empty()) {
                auto parts = xmz::str::split(depends_str, ",");
                for (auto& p : parts) {
                    p = xmz::str::trim(p);
                    if (!p.empty()) entry.depends.push_back(p);
                }
            }
            std::string apt_depends_str = parser.get(section, "depends_apt", "");
            if (!apt_depends_str.empty()) {
                auto parts = xmz::str::split(apt_depends_str, ",");
                for (auto& p : parts) {
                    p = xmz::str::trim(p);
                    if (!p.empty()) entry.depends_apt.push_back(p);
                }
            }
            std::string status = parser.get(section, "status", "enabled");
            if (status == "enabled") {
                g_module_db.enabled_modules.push_back(entry.package);
            } else {
                g_module_db.disabled_modules.push_back(entry.package);
            }
            g_module_db.modules[entry.package] = entry;
        }
        //g_module_db.last_updated = parser.get("GLOBAL", "last_updated", "");
        xmz::log::info("Loaded " + std::to_string(g_module_db.modules.size()) + " modules from database");
        return true;
    }
    // save the database to the file
    inline bool save_db_to_file() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        //parser.set("GLOBAL", "last_updated", g_module_db.last_updated);
        //parser.set_int("GLOBAL", "total_modules", g_module_db.modules.size());
        for (const auto& [package_name, entry] : g_module_db.modules) {
            std::string section = package_name;
            parser.set(section, "name", entry.name);
            parser.set(section, "package", entry.package);
            parser.set(section, "version", entry.version);
            parser.set(section, "description", entry.description);
            parser.set(section, "author", entry.author);
            parser.set(section, "maintainer", entry.maintainer);
            parser.set(section, "path", entry.path);
            parser.set(section, "install_base", entry.install_base);
            parser.set(section, "installed_date", entry.installed_date);
            parser.set(section, "last_updated", entry.last_updated);
            if (!entry.depends.empty()) {
                std::string depends_str;
                for (size_t i = 0; i < entry.depends.size(); ++i) {
                    if (i > 0) depends_str += ",";
                    depends_str += entry.depends[i];
                }
                parser.set(section, "depends", depends_str);
            }
            if (!entry.depends_apt.empty()) {
                std::string apt_depends_str;
                for (size_t i = 0; i < entry.depends_apt.size(); ++i) {
                    if (i > 0) apt_depends_str += ",";
                    apt_depends_str += entry.depends_apt[i];
                }
                parser.set(section, "depends_apt", apt_depends_str);
            }
    
            bool is_enabled = g_module_db.is_enabled(entry.package);
            parser.set(section, "status", is_enabled ? "enabled" : "disabled");
        }
        bool result = parser.save_append(db_path);
        if (result) { xmz::log::info("Saved database to: " + db_path); } else { xmz::log::error("Failed to save database to: " + db_path); }
        return result;
    }
    // parse authors from author.ini
    inline std::vector<std::string> parse_authors(const std::string& filepath) {
        std::vector<std::string> authors;
        a1::ini::ini_parser parser;
        if (!parser.parse_file(filepath)) return authors;
        std::string authors_str = parser.get("", "author", "");
        if (!authors_str.empty()) {
            auto parts = xmz::str::split(authors_str, ",");
            for (auto& p : parts) {
                p = xmz::str::trim(p);
                if (!p.empty()) authors.push_back(p);
            }
        }
        return authors;
    }
    // check if author is official
    inline bool is_official_author(const std::string& author, const config& cfg) {
        auto authors = parse_authors(cfg.authors);
        return std::find(authors.begin(), authors.end(), author) != authors.end();
    }
    // Initialize module system
    inline void init_system(const a1mod::config& cfg, const a1::config::jb_path& g_jb) {
        xmz::log::info("Initializing module system...");
        // create directory structure
        if (xmz::aux::is_dir(g_jb.mod_dir) == 1) {
            xmz::fs::mkdir(g_jb.mod_dir);
            xmz::fs::mkdir(g_jb.mod_dir + "/downloadas");
            xmz::fs::mkdir(g_jb.mod_dir + "/install");
            xmz::fs::mkdir(cfg.mod_install_tmp);
        }
        if (xmz::aux::is_dir(cfg.users) == 1) { xmz::fs::mkdir(cfg.users); }
        if (xmz::aux::is_dir(cfg.authors) == 1) { xmz::fs::mkdir(cfg.authors); }
        if (xmz::aux::exist(cfg.authors + "/authors.ini") == 1) { xmz::fs::writefile("author: XMZ, LF, AD-iOS", cfg.authors + "/authors.ini"); }
        if (xmz::aux::is_dir(g_jb.mod_dir + "/store") == 1) {
            xmz::fs::mkdir(g_jb.mod_dir + "/store");
            xmz::fs::mkdir(g_jb.mod_dir + "/store/users");
            xmz::fs::mkdir(g_jb.mod_dir + "/store/official");
        }
        load_db_from_file();
        g_module_db.last_updated = xmz::get_time_str();
        save_db_to_file();
    }
    // check if required fields are present
    inline bool check_required(const packinfo& info) {
        auto missing = info.get_miss_fields();
        if (!missing.empty()) {
            xmz::log::error("Missing required fields:");
            for (const auto& field : missing) { xmz::log::error("  - " + field); }
            return false;
        }
        return true;
    }
    // check module dependencies
    inline bool check_depends(const packinfo& info) {
        if (info.depends.empty()) return true;
        for (const auto& dep_str : info.depends) {
            auto deps = depends::parse_depends(dep_str);
            for (const auto& dep : deps) {
                auto it = g_module_db.modules.find(dep.name);
                if (it == g_module_db.modules.end()) {
                    if (dep.optional) continue;
                    xmz::log::error("Missing dependency:" + dep.name);
                    return false;
                }
                if (!dep.version_constraint.empty()) {
                    if (!version::satisfies(it->second.version, 
                                           dep.version_constraint)) {
                        xmz::log::error("Version mismatch for" + dep.name + 
                                       ": required" + dep.version_constraint + 
                                       ", found" + it->second.version);
                        return false;
                    }
                }
            }
        }
        return true;
    }
    // check APT dependencies
    inline bool check_apt_depends(const packinfo& info) {
        if (info.depends_apt.empty()) return true;
        for (const auto& pkg : info.depends_apt) {
            std::string pkg_trimmed = xmz::str::trim(pkg);
            if (pkg_trimmed.empty()) continue;
            // check if package is installed via dpkg
            auto result = xmz::cmd::run_shell_capture(
                "dpkg -l " + pkg_trimmed + " 2>/dev/null | grep '^ii'"
            );
            if (result.exit_code != 0) {
                xmz::log::error("Missing system package:" + pkg_trimmed);
                xmz::log::info("Install with: apt install" + pkg_trimmed);
                return false;
            }
        }
        return true;
    }
    // check for module conflicts
    enum class conflict_result {
        none,
        same_author,
        different_author
    };
    inline std::pair<bool, conflict_result> check_conflict(
        const std::string& package, 
        const std::string& author,
        const config& cfg) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) {
            return {false, conflict_result::none};
        }
        if (it->second.author == author) { return {true, conflict_result::same_author}; }
        return {true, conflict_result::different_author};
    }
    // add module to database
    inline void add_to_db(const module_entry& entry, bool is_official) {
        g_module_db.modules[entry.package] = entry;
        g_module_db.last_updated = xmz::get_time_str();
        g_module_db.enabled_modules.push_back(entry.package);
        xmz::log::info("Added to database:" + entry.package + "(" + (is_official ? "official" : "user") + ")");
        save_db_to_file();
    }
    // remove module from database
    inline bool remove_from_db(const std::string& package) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) {
            xmz::log::error("Module not found:" + package);
            return false;
        }
        g_module_db.modules.erase(it);
        // remove from enabled/disabled lists
        auto& enabled = g_module_db.enabled_modules;
        enabled.erase(std::remove(enabled.begin(), enabled.end(), package), 
                     enabled.end());
        auto& disabled = g_module_db.disabled_modules;
        disabled.erase(std::remove(disabled.begin(), disabled.end(), package), 
                      disabled.end());
        g_module_db.last_updated = xmz::get_time_str();
        save_db_to_file();
        return true;
    }
    // list modules
    inline void list_modules() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        if (!parser.parse_file(db_path)) {
            xmz::println("Failed to parse module database");
            return;
        }
        auto sections = parser.get_sec();
        if (sections.empty()) {
            xmz::println("  No modules installed");
            return;
        }
        xmz::println("Installed Modules");
        for (const auto& section : sections) {
            if (section.empty()) continue;
            std::string name = parser.get(section, "name", "");
            std::string version = parser.get(section, "version", "");
            std::string author = parser.get(section, "author", "");
            std::string maintainer = parser.get(section, "maintainer", "");
            std::string description = parser.get(section, "description", "");
            std::string depends_str = parser.get(section, "depends", "");
            std::string depends_apt_str = parser.get(section, "depends_apt", "");
            std::string enabled_str = parser.get(section, "enabled", "true");
            xmz::println("");
            xmz::println("  " + section + ":" + name + " (v" + version + ")");
            xmz::println("    Author:" + author + ", Maintainer:" + maintainer);
            xmz::println("    Description:" + description);
            if (!depends_str.empty()) {
                xmz::println("    Dependencies:");
                auto deps = xmz::str::split(depends_str, ",");
                for (const auto& dep : deps) {
                    std::string trimmed = xmz::str::trim(dep);
                    if (!trimmed.empty()) xmz::println("      - " + trimmed);
                }
            }
            if (!depends_apt_str.empty()) {
                xmz::println("    System Dependencies:");
                auto deps_apt = xmz::str::split(depends_apt_str, ",");
                for (const auto& dep : deps_apt) {
                    std::string trimmed = xmz::str::trim(dep);
                    if (!trimmed.empty()) xmz::println("      - " + trimmed);
                }
            }
            bool enabled = (enabled_str == "true" || enabled_str == "1" || enabled_str == "yes");
            xmz::println("    Status:" + std::string(enabled ? "Enabled" : "Disabled"));
        }
    }
    // enable module
    inline void enable_module(const std::string& package) {
        auto& disabled = g_module_db.disabled_modules;
        auto it = std::find(disabled.begin(), disabled.end(), package);
        if (it != disabled.end()) { disabled.erase(it); }
        if (!g_module_db.is_enabled(package)) { g_module_db.enabled_modules.push_back(package); }
        xmz::log::info("Module enabled:" + package);
    }
    // disable module
    inline void disable_module(const std::string& package) {
        auto& enabled = g_module_db.enabled_modules;
        auto it = std::find(enabled.begin(), enabled.end(), package);
        if (it != enabled.end()) { enabled.erase(it); }
        if (!g_module_db.is_disabled(package)) {
            g_module_db.disabled_modules.push_back(package);
        }
        xmz::log::info("Module disabled:" + package);
    }

    inline int install(const std::string& filepath) {
        std::filesystem::path p(filepath);
        std::string modname = p.filename();
        config cfg;
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:" + filepath);
            return 1;
        }
        // check file extension
        if (filepath.find(".a1mod") == std::string::npos && 
            filepath.find(".a1module.zip") == std::string::npos) {
            xmz::log::error("Must be .a1module.zip or .a1mod file");
            return 1;
        }
        xmz::log::info("Installing module:" + filepath);
        // create temp directory
        std::string temp_dir = cfg.mod_install_tmp + "/install_" + modname;
        xmz::fs::mkdir(temp_dir);
        // unzip module
        xmz::log::info("Extracting module...");
        if (cmd::unzip(filepath, temp_dir) != 0) {
            xmz::log::error("Failed to extract module");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // find control.ini
        std::string control_file;
        if (xmz::aux::is_file(temp_dir + "/control.ini") == 0) {
            control_file = temp_dir + "/control.ini";
        } else {
            // search for control.ini in subdirectories
            for (const auto& entry : std::filesystem::directory_iterator(temp_dir)) {
                if (entry.is_directory()) {
                    std::string sub_control = entry.path().string() + "/control.ini";
                    if (xmz::aux::is_file(sub_control) == 0) {
                        control_file = sub_control;
                        break;
                    }
                }
            }
        }
        if (control_file.empty()) {
            xmz::log::error("control.ini not found in module");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // parse module info
        xmz::log::info("Parsing module metadata...");
        auto info = parse_packfile(control_file);
        // validate required fields
        if (!check_required(info)) {
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // display module info
        xmz::println("Module information:");
        xmz::println("  Package:" + info.package);
        xmz::println("  Name:" + info.name);
        xmz::println("  Version:" + info.version);
        xmz::println("  Description:" + info.descr);
        // check dependencies
        xmz::log::info("Checking dependencies...");
        if (!check_depends(info)) {
            xmz::log::error("Module dependencies not satisfied");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // check APT dependencies
        if (!check_apt_depends(info)) {
            xmz::log::error("System dependencies not satisfied");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // check conflicts
        auto [has_conflict, conflict] = check_conflict(info.package, 
                                                        info.maintainer.empty() ? 
                                                        "unknown" : info.maintainer[0], 
                                                        cfg);
        if (has_conflict) {
            if (conflict == conflict_result::different_author) {
                xmz::log::error("Module" + info.package + "already exists with different author");
                xmz::fs::recrmdir(temp_dir);
                return 1;
            } else {
                xmz::log::warn("Module already exists, updating...");
                remove_from_db(info.package);
            }
        }
        // determine if official
        bool is_official = false;
        std::string author = info.maintainer.empty() ? "unknown" : info.maintainer[0];
        if (!info.author.empty()) { author = info.author[0]; }
        is_official = is_official_author(author, cfg);
        // set install path
        std::string install_base;
        if (is_official) { install_base = cfg.authors + "/" + author + "/" + info.package; } else { install_base = cfg.users + "/" + author + "/" + info.package; }
        // clean and create install directory
        xmz::fs::recrmdir(install_base);
        xmz::fs::mkdir(install_base);
        xmz::log::info("Installing to:" + install_base);
        std::string source_dir = std::filesystem::path(control_file).parent_path().string();
        for (const auto& entry : std::filesystem::directory_iterator(source_dir)) {
            std::string dest = install_base + "/" + entry.path().filename().string();
            if (entry.is_directory()) { xmz::fs::cp(xmz::fs::cptype::recdir, entry.path().string(), dest); } else { xmz::fs::cp(xmz::fs::cptype::file, entry.path().string(), dest); }
        }
        for (const auto& entry : std::filesystem::directory_iterator(install_base)) { if (entry.path().extension() == ".lua") { chmod(entry.path().c_str(), 0755); } }
        // create module entry
        module_entry entry;
        entry.name = info.name;
        entry.package = info.package;
        entry.version = info.version;
        entry.description = info.descr;
        entry.author = author;
        entry.maintainer = info.maintainer.empty() ? author : info.maintainer[0];
        entry.path = install_base;
        entry.install_base = install_base;
        entry.installed_date = xmz::get_time_str();
        entry.last_updated = xmz::get_time_str();
        entry.depends = info.depends;
        entry.depends_apt = info.depends_apt;
        add_to_db(entry, is_official);
        xmz::fs::recrmdir(temp_dir);
        xmz::log::info("Module installed successfully!");
        xmz::println("  Name:" + info.name);
        xmz::println("  Package:" + info.package);
        xmz::println("  Version:" + info.version);
        xmz::println("  Author:" + author);
        xmz::println("  Type:" + std::string(is_official ? "Official" : "User"));
        xmz::println("  Location:" + install_base);
        return 0;
    }
    // remove module
    inline int remove(const std::string& package) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) {
            xmz::log::error("Module not found:" + package);
            return 1;
        }
        xmz::log::info("Removing module:" + package);
        xmz::println("  Name:" + it->second.name);
        xmz::println("  Version:" + it->second.version);
        xmz::println("  Author:" + it->second.author);
        // remove files
        if (xmz::aux::is_dir(it->second.install_base) == 0) { xmz::fs::recrmdir(it->second.install_base); }
        // remove from database
        remove_from_db(package);
        xmz::log::info("Module removed:" + package);
        return 0;
    }
    inline int package_module(const std::string& path, const std::string& name) {
        if (path.empty()) {
            xmz::log::error("the path can’t be empty!");
            return 1;
        }
        if (name.empty()) {
            xmz::log::error("the name can’t be empty!");
            return 1;
        }
        if (xmz::aux::is_dir(path) == 1) {
            xmz::log::error("path:", path, "not exist");
        }
        //return cmd::zip(name + ".a1mod", path);
        return cmd::zip(name, path);
    }
} // namespace a1mod

====== end =====
===== cxxa1/a1/core/mod/zip.hpp =====
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

====== end =====
===== cxxa1/a1/core/mod/a1mod_depends.hpp =====
// a1mod_depends.hpp
#pragma once
#include <string>
#include <vector>
#include <set>
#include <queue>
#include <algorithm>
#include <regex>
#include <functional>

#include <libxmz/log.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/mod/a1mod_version.hpp>

namespace a1mod {
namespace depends {

struct dep_info {
    std::string name;
    std::string version_constraint;
    bool optional;
};

struct dep_node {
    std::string name;
    std::string version;
    std::vector<dep_info> deps;
    bool installed;
    bool visited;
    bool in_stack;
    //bool optional;
};

// "mod1(>=1.0), mod2(<=2.0)"
// "mod1>=1.0, mod2<=2.0"
// "mod1 (>= 1.0) , mod2 (<= 2.0)"
// "mod1 | mod2" (alternatives)
inline std::vector<dep_info> parse_depends(const std::string& dep_str) {
    std::vector<dep_info> result;
    if (dep_str.empty()) return result;
    auto parts = xmz::str::split(dep_str, ",");
    for (auto& part : parts) {
        part = xmz::str::trim(part);
        if (part.empty()) continue;
        dep_info info;
        info.optional = false;
        size_t alt_pos = part.find('|');
        if (alt_pos != std::string::npos) {
            info.optional = true;
            part = part.substr(0, alt_pos);
            part = xmz::str::trim(part);
        }
        std::regex paren_regex(R"(^([a-zA-Z0-9_\-\.]+)\s*\(\s*([<>=!]+\s*[a-zA-Z0-9_\-\.\+\~]+)\s*\))");
        std::smatch match;
        if (std::regex_search(part, match, paren_regex)) {
            info.name = match[1].str();
            info.version_constraint = xmz::str::trim(match[2].str());
        } else {
            const std::vector<std::string> ops = {">=", "<=", "==", "!=", ">", "<", "="};
            size_t op_pos = std::string::npos;
            std::string found_op;
            for (const auto& op : ops) {
                size_t pos = part.find(op);
                if (pos != std::string::npos && pos > 0) {
                    if (op_pos == std::string::npos || pos < op_pos) {
                        op_pos = pos;
                        found_op = op;
                        break;
                    }
                }
            }
            if (op_pos != std::string::npos) {
                info.name = xmz::str::trim(part.substr(0, op_pos));
                info.version_constraint = xmz::str::trim(part.substr(op_pos));
            } else {
                info.name = part;
            }
        }
        info.name = xmz::str::trim(info.name);
        result.push_back(info);
    }
    return result;
}

inline bool check_dep_satisfied(
    const dep_info& dep, 
    const std::map<std::string, std::string>& installed) {
    auto it = installed.find(dep.name);
    if (it == installed.end()) { return dep.optional; }
    if (dep.version_constraint.empty()) { return true; }
    return version::satisfies(it->second, dep.version_constraint);
}

inline bool resolve_deps(
    const std::string& module_name,
    const std::map<std::string, dep_node>& available,
    const std::map<std::string, std::string>& installed,
    std::vector<std::string>& resolved,
    std::vector<std::string>& missing,
    std::vector<std::string>& conflicts) {
    std::map<std::string, dep_node> working = available;
    std::set<std::string> visited;
    std::set<std::string> in_stack;
    std::vector<std::string> order;
    std::function<bool(const std::string&)> dfs = 
    [&](const std::string& name) -> bool {
        if (in_stack.count(name)) {
            xmz::log::error("circular dependency detected:", name);
            conflicts.push_back(name);
            return false;
        }
        if (visited.count(name)) return true;
        auto it = working.find(name);
        if (it == working.end()) {
            // check if already installed
            if (installed.count(name)) {
                visited.insert(name);
                return true;
            }
            missing.push_back(name);
            return false;
        }
        in_stack.insert(name);
        for (const auto& dep : it->second.deps) {
            if (dep.optional) continue;
            if (!dfs(dep.name)) {
                auto inst_it = installed.find(dep.name);
                if (inst_it != installed.end() && version::satisfies(inst_it->second, dep.version_constraint)) { continue; }
                return false;
            }
        }
        in_stack.erase(name);
        visited.insert(name);
        order.push_back(name);
        return true;
    };
    if (!dfs(module_name)) { return false; }
    resolved = order;
    return true;
}

inline bool validate_deps(
    const std::vector<dep_info>& deps,
    const std::map<std::string, std::string>& installed) {
    for (const auto& dep : deps) {
        if (dep.optional) continue;
        if (!check_dep_satisfied(dep, installed)) {
            xmz::log::error("dependency not satisfied:", dep.name, dep.version_constraint);
            return false;
        }
    }
    return true;
}
} // namespace depends
} // namespace a1mod

====== end =====
===== cxxa1/a1/core/mod/a1mod_luarun.hpp =====
// a1mod_luarun.hpp
#pragma once
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#include <memory>
#include <string>
#include <vector>
#include <map>
#include <type_traits>
#include <a1/core/mod/a1modcore_api.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1mod {
namespace lua_traits {
    template<typename T> struct from_lua;
    template<> struct from_lua<int> { 
        static int get(lua_State* L, int index) { return (int)luaL_checkinteger(L, index); } };
    template<> struct from_lua<bool> { static bool get(lua_State* L, int index) { return lua_toboolean(L, index) != 0; } };
    template<> struct from_lua<std::string> {
        static std::string get(lua_State* L, int index) {
            size_t len;
            const char* str = luaL_checklstring(L, index, &len);
            return std::string(str, len);
        }
    };
    template<typename T> struct to_lua;
    template<> struct to_lua<int> { static void push(lua_State* L, int value) { lua_pushinteger(L, value); } };
    template<> struct to_lua<bool> { static void push(lua_State* L, bool value) { lua_pushboolean(L, value); } };
    template<> struct to_lua<std::string> { static void push(lua_State* L, const std::string& value) { lua_pushlstring(L, value.c_str(), value.size()); } };
    template<> struct to_lua<std::vector<std::string>> {
        static void push(lua_State* L, const std::vector<std::string>& vec) {
            lua_newtable(L);
            for (size_t i = 0; i < vec.size(); ++i) {
                lua_pushlstring(L, vec[i].c_str(), vec[i].size());
                lua_rawseti(L, -2, (int)i + 1);
            }
        }
    };
    template<> struct to_lua<std::map<std::string, int>> {
        static void push(lua_State* L, const std::map<std::string, int>& map) {
            lua_newtable(L);
            for (const auto& pair : map) {
                lua_pushlstring(L, pair.first.c_str(), pair.first.size());
                lua_pushinteger(L, pair.second);
                lua_settable(L, -3);
            }
        }
    };
}
template<typename T>
T get_arg(lua_State* L, int index) { return lua_traits::from_lua<typename std::decay<T>::type>::get(L, index); }
template<typename... Args, size_t... Indices>
auto get_args(lua_State* L, std::index_sequence<Indices...>) { return std::make_tuple(get_arg<Args>(L, (int)Indices + 1)...); }

static int lua_GetProcessPid(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int result = api.GetProcessPid(name);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetProcessName(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    std::string result = api.GetProcessName(pid);
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetNiceValue(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    int result = api.GetNiceValue(pid);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetCPUUsage(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    int result = api.GetCPUUsage(pid);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetHighPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetHighPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetLowPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetLowPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetCustomPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetCustomPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetParsedHighList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedHighList();
    lua_traits::to_lua<std::vector<std::string>>::push(L, result);
    return 1;
}

static int lua_GetParsedLowList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedLowList();
    lua_traits::to_lua<std::vector<std::string>>::push(L, result);
    return 1;
}

static int lua_GetParsedCustomList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedCustomList();
    lua_traits::to_lua<std::map<std::string, int>>::push(L, result);
    return 1;
}

static int lua_GetPresetHighPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetPresetHighPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetPresetLowPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetPresetLowPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_IsDeviceLocked(lua_State* L) {
    a1mod::apis::a1api api;
    bool result = api.IsDeviceLocked();
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_IsA1Running(lua_State* L) {
    a1mod::apis::a1api api;
    bool result = api.IsA1Running();
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_GetA1Dir(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetA1Dir();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetA1ConfigDir(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetA1ConfigDir();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_SetProcessNiceValue(lua_State* L) {
    a1mod::apis::a1api api;
    pid_t pid = (pid_t)luaL_checkinteger(L, 1);
    int nice_value = (int)luaL_checkinteger(L, 2);
    bool result = api.SetProcessNiceValue(pid, nice_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_SetProcessJetsamValue(lua_State* L) {
    a1mod::apis::a1api api;
    pid_t pid = (pid_t)luaL_checkinteger(L, 1);
    int32_t jetsam_value = (int32_t)luaL_checkinteger(L, 2);
    bool result = api.SetProcessJetsamValue(pid, jetsam_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_SetProcessPriority(lua_State* L) {
    a1mod::apis::a1api api;
    if (lua_isnumber(L, 1)) {
        int pid = (int)luaL_checkinteger(L, 1);
        int priority = (int)luaL_checkinteger(L, 2);
        bool result = api.SetProcessPriority(pid, priority);
        lua_pushboolean(L, result);
    } else if (lua_isstring(L, 1)) {
        const char* name = lua_tostring(L, 1);
        int priority = (int)luaL_checkinteger(L, 2);
        bool result = api.SetProcessPriority(name, priority);
        lua_pushboolean(L, result);
    } else {
        luaL_error(L, "Invalid argument type for SetProcessPriority");
        return 0;
    }
    return 1;
}

#define REGISTER_LUA_FUNCTION(name) \
    lua_pushcfunction(L, lua_##name); \
    lua_setfield(L, -2, #name);

class luatime {
public:
    luatime() : L(nullptr), initialized(false) {}
    ~luatime() { close(); }
    luatime(const luatime&) = delete;
    luatime& operator=(const luatime&) = delete;
    luatime(luatime&& other) noexcept 
        : L(other.L), initialized(other.initialized) {
        other.L = nullptr;
        other.initialized = false;
    }

    void init() {
        if (initialized) return;
        L = luaL_newstate();
        if (!L) {
            xmz::log::error("Failed to create Lua state");
            return;
        }
        luaL_openlibs(L);
        register_a1api();
        initialized = true;
    }

    void close() {
        if (L) {
            lua_close(L);
            L = nullptr;
            initialized = false;
        }
    }

    bool is_initialized() const { return initialized && L != nullptr; }
    lua_State* get_state() const { return L; }

    bool run_script(const std::string& script) {
        if (!is_initialized()) return false;
        if (luaL_loadstring(L, script.c_str()) != LUA_OK) {
            xmz::log::error("Load failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
            xmz::log::error("Execute failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        return true;
    }

    bool run_file(const std::string& filename) {
        if (!is_initialized()) return false;
        if (xmz::aux::is_file(filename) == 1) {
            xmz::log::warn("File not found:", filename);
            return false;
        }
        if (luaL_loadfile(L, filename.c_str()) != LUA_OK) {
            xmz::log::error("Load failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
            xmz::log::error("Execute failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        return true;
    }
private:
    lua_State* L;
    bool initialized;

    void register_a1api() {
        lua_newtable(L);
        REGISTER_LUA_FUNCTION(GetProcessPid);
        REGISTER_LUA_FUNCTION(GetProcessName);
        REGISTER_LUA_FUNCTION(GetNiceValue);
        REGISTER_LUA_FUNCTION(GetCPUUsage);
        REGISTER_LUA_FUNCTION(GetHighPriorityList);
        REGISTER_LUA_FUNCTION(GetLowPriorityList);
        REGISTER_LUA_FUNCTION(GetCustomPriorityList);
        REGISTER_LUA_FUNCTION(GetParsedHighList);
        REGISTER_LUA_FUNCTION(GetParsedLowList);
        REGISTER_LUA_FUNCTION(GetParsedCustomList);
        REGISTER_LUA_FUNCTION(GetPresetHighPriorityList);
        REGISTER_LUA_FUNCTION(GetPresetLowPriorityList);
        REGISTER_LUA_FUNCTION(IsDeviceLocked);
        REGISTER_LUA_FUNCTION(IsA1Running);
        REGISTER_LUA_FUNCTION(GetA1Dir);
        REGISTER_LUA_FUNCTION(GetA1ConfigDir);
        REGISTER_LUA_FUNCTION(SetProcessNiceValue);
        REGISTER_LUA_FUNCTION(SetProcessJetsamValue);
        lua_pushcfunction(L, lua_SetProcessPriority);
        lua_setfield(L, -2, "SetProcessPriority");
        lua_setglobal(L, "a1");
    }
};
} /* a1mod */

====== end =====
===== cxxa1/a1/core/mod/a1mod_version.hpp =====
// a1mod_version.hpp
#pragma once
#include <string>
#include <vector>
#include <regex>
#include <algorithm>
#include <cctype>

namespace a1mod {
namespace version {
struct parsed_version {
    int epoch;
    std::string upstream;
    std::string revision;
    parsed_version() : epoch(0) {}
};

// split version string by delimiters
inline std::vector<std::string> split_version(const std::string& str, const std::string& delims) {
    std::vector<std::string> parts;
    size_t start = 0;
    size_t end = 0;
    while ((end = str.find_first_of(delims, start)) != std::string::npos) {
        if (end > start) { parts.push_back(str.substr(start, end - start)); }
        parts.push_back(str.substr(end, 1));
        start = end + 1;
    }
    if (start < str.length()) { parts.push_back(str.substr(start)); }
    return parts;
}

// check if character is digit
inline bool is_digit(char c) { return c >= '0' && c <= '9'; }
// check if character is letter
inline bool is_letter(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
inline int compare_version_strings(const std::string& a, const std::string& b) {
    size_t i = 0, j = 0;
    while (i < a.length() || j < b.length()) {
        int first_diff = 0;
        while ((i < a.length() && !is_digit(a[i])) || (j < b.length() && !is_digit(b[j]))) {
            int ac = (i < a.length()) ? (int)a[i] : 0;
            int bc = (j < b.length()) ? (int)b[j] : 0;
            if (ac != bc) {
                if (ac == '~') return -1;
                if (bc == '~') return 1;
                if (is_letter(ac) && !is_letter(bc)) return -1;
                if (!is_letter(ac) && is_letter(bc)) return 1;
                return ac - bc;
            }
            if (ac) i++;
            if (bc) j++;
        }
        while (i < a.length() && a[i] == '0') i++;
        while (j < b.length() && b[j] == '0') j++;
        size_t start_i = i;
        size_t start_j = j;
        while (i < a.length() && is_digit(a[i])) i++;
        while (j < b.length() && is_digit(b[j])) j++;
        size_t len_i = i - start_i;
        size_t len_j = j - start_j;
        if (len_i != len_j) { return len_i < len_j ? -1 : 1; }
        for (size_t k = 0; k < len_i; k++) { if (a[start_i + k] != b[start_j + k]) { return a[start_i + k] < b[start_j + k] ? -1 : 1; } }
    }
    return 0;
}

// parse version string into epoch, upstream, revision
inline parsed_version parse(const std::string& version) {
    parsed_version pv;
    std::string ver = version;
    size_t colon_pos = ver.find(':');
    if (colon_pos != std::string::npos) {
        std::string epoch_str = ver.substr(0, colon_pos);
        try { pv.epoch = std::stoi(epoch_str); } catch (...) { pv.epoch = 0; }
        ver = ver.substr(colon_pos + 1);
    }
    size_t last_dash = ver.rfind('-');
    if (last_dash != std::string::npos) {
        std::string after_dash = ver.substr(last_dash + 1);
        bool is_numeric = !after_dash.empty() && 
                         std::all_of(after_dash.begin(), after_dash.end(), ::isdigit);
        if (is_numeric) {
            pv.revision = after_dash;
            ver = ver.substr(0, last_dash);
        }
    }
    pv.upstream = ver;
    return pv;
}

inline int compare(const std::string& ver_a, const std::string& ver_b) {
    parsed_version a = parse(ver_a);
    parsed_version b = parse(ver_b);
    // compare epochs
    if (a.epoch != b.epoch) { return a.epoch < b.epoch ? -1 : 1; }
    // compare upstream versions
    int cmp = compare_version_strings(a.upstream, b.upstream);
    if (cmp != 0) return cmp;
    // compare revisions (numeric comparison if both exist)
    if (!a.revision.empty() || !b.revision.empty()) {
        int rev_a = 0, rev_b = 0;
        try { if (!a.revision.empty()) rev_a = std::stoi(a.revision); } catch (...) { rev_a = 0; }
        try { if (!b.revision.empty()) rev_b = std::stoi(b.revision); } catch (...) { rev_b = 0; }
        if (rev_a != rev_b) { return rev_a < rev_b ? -1 : 1; }
    }
    return 0;
}

// check if version matches constraint
// supports: >=, <=, >, <, =, ==, !=
inline bool satisfies(const std::string& version, const std::string& constraint) {
    if (constraint.empty()) return true;
    std::string op;
    std::string ver;
    if (constraint.length() >= 2) {
        std::string prefix = constraint.substr(0, 2);
        if (prefix == ">=" || prefix == "<=" || prefix == "==" || prefix == "!=") {
            op = prefix;
            ver = constraint.substr(2);
        }
    }
    if (op.empty() && !constraint.empty()) {
        if (constraint[0] == '>' || constraint[0] == '<' || constraint[0] == '=') {
            op = constraint.substr(0, 1);
            ver = constraint.substr(1);
        }
    }
    if (op.empty()) {
        op = ">=";
        ver = constraint;
    }
    ver.erase(0, ver.find_first_not_of(" \t"));
    ver.erase(ver.find_last_not_of(" \t") + 1);
    int cmp = compare(version, ver);
    if (op == ">=" || op == ">") {
        return op == ">=" ? cmp >= 0 : cmp > 0;
    } else if (op == "<=" || op == "<") {
        return op == "<=" ? cmp <= 0 : cmp < 0;
    } else if (op == "==" || op == "=") {
        return cmp == 0;
    } else if (op == "!=") {
        return cmp != 0;
    }
    return false;
}

// check if version is in range: ">=1.0,<2.0"
inline bool in_range(const std::string& version, const std::string& range) {
    if (range.empty()) return true;
    auto parts = xmz::str::split(range, ",");
    for (auto& part : parts) {
        part = xmz::str::trim(part);
        if (!part.empty() && !satisfies(version, part)) { return false; }
    }
    return true;
}

} // namespace version
} // namespace a1mod

====== end =====
===== cxxa1/a1/core/mod/a1mod_config.hpp =====
// a1mod_config.hpp
#pragma once
#include <string>
#include <vector>
#include <map>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

namespace a1mod {
struct packinfo {
    /* necessary */
    std::string package;
    std::string name;
    std::string version;
    std::string description;
    std::string descr = description;
    std::vector<std::string> maintainer;
    /* optional */
    std::vector<std::string> author;
    std::vector<std::string> depends;
    std::vector<std::string> depends_apt;
    std::vector<std::string> section;
    bool is_valid() const {
        return !package.empty() && 
               !maintainer.empty() && 
               !version.empty() && 
               !description.empty();
    }
    std::vector<std::string> get_miss_fields() const {
        std::vector<std::string> miss;
        if (package.empty()) miss.push_back("package");
        if (maintainer.empty()) miss.push_back("maintainer");
        if (version.empty()) miss.push_back("version");
        if (description.empty()) miss.push_back("description");
        return miss;
    }
};

// module database entry
struct module_entry {
    std::string name;
    std::string package;
    std::string author;
    std::string maintainer;
    std::string version;
    std::string description;
    std::string path;
    std::string install_base;
    std::string installed_date;
    std::string last_updated;
    std::vector<std::string> depends;
    std::vector<std::string> depends_apt;
    std::vector<std::string> update_log;
};

inline packinfo parse_packinfo(const a1::ini::ini_parser& parser) {
    packinfo info;
    
    info.package = parser.get("", "package");
    info.name = parser.get("", "name", info.package);
    info.version = parser.get("", "version");
    info.description = parser.get("", "description");
    info.descr = info.description;
    // parse maintainer
    std::string maintainer_str = parser.get("", "maintainer");
    if (!maintainer_str.empty()) {
        auto parts = xmz::str::split(maintainer_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.maintainer.push_back(p);
        }
    }
    // parse author
    std::string author_str = parser.get("", "author", "");
    if (!author_str.empty()) {
        auto parts = xmz::str::split(author_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.author.push_back(p);
        }
    }
    // parse section
    std::string section_str = parser.get("", "section", "");
    if (!section_str.empty()) {
        auto parts = xmz::str::split(section_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.section.push_back(p);
        }
    }
    // parse depends
    std::string depends_str = parser.get("", "depends", "");
    if (!depends_str.empty()) {
        auto parts = xmz::str::split(depends_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.depends.push_back(p);
        }
    }
    // parse apt depends
    std::string depends_apt_str = parser.get("", "depends_apt", "");
    if (!depends_apt_str.empty()) {
        auto parts = xmz::str::split(depends_apt_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.depends_apt.push_back(p);
        }
    }
    return info;
}

inline packinfo parse_packfile(const std::string& filepath) {
    a1::ini::ini_parser parser;
    if (!parser.parse_file(filepath)) { return packinfo{}; }
    return parse_packinfo(parser);
}

class config {
private:
    a1::config::jb_path g_jb;
public:
    std::string mod_install_tmp = g_jb.mod_dir + "/cache/temp";
    std::string install_db_path = g_jb.mod_dir + "/db";
    std::string users = install_db_path;
    std::string authors = g_jb.mod_dir + "/official";
};

} // namespace a1mod

====== end =====
===== cxxa1/a1/core/mod/a1modcore_api.hpp =====
// a1modcore_api.hpp
#pragma once
#include <a1/core/a1core.hpp>
#include <a1/core/a1ctlcore.hpp>
#include <libxmz/io.hpp>
#include <libxmz/fs.hpp>
#include <optional>
#include <vector>
#include <map>

namespace a1::_modapi {
class a1api {
public:
    // Get PID through the process name (-1 means not found)
    int GetProcessPid(const std::string& name) { return a1::bin::bundle_pid(name.c_str()); }
    std::string GetProcessName(int pid) { return a1::get::process_name_by_pid(pid); }
    int GetNiceValue(int pid) { return a1::get::nice_by_pid(pid); }
    int GetCPUUsage(int pid) { return a1::get::cpu_by_pid(pid); }
    std::string GetHighPriorityList() { 
        if (xmz::aux::is_file(g_jb.high_f) == 0) {
            return xmz::fs::readfile_str(g_jb.high_f);
        }
        return "";
    }
    std::string GetLowPriorityList() { 
        if (xmz::aux::is_file(g_jb.low_f) == 0) {
            return xmz::fs::readfile_str(g_jb.low_f);
        }
        return "";
    }
    std::string GetCustomPriorityList() {
        if (xmz::aux::is_file(g_jb.custom_f) == 0) {
            return xmz::fs::readfile_str(g_jb.custom_f);
        }
        return "";
    }
    std::vector<std::string> GetParsedHighList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_high_list();
    }
    std::vector<std::string> GetParsedLowList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_low_list();
    }
    std::map<std::string, int> GetParsedCustomList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_custom_list();
    }
    std::string GetPresetHighPriorityList() { return a1::get_sys_high_list_str(); }
    std::string GetPresetLowPriorityList() { return a1::get_sys_low_list_str(); }
    bool IsDeviceLocked() { return a1::check_lockstate(); }
    bool IsA1Running() { return a1ctl::check_a1_running() == 0; }
    std::string GetA1Dir() { return g_jb.a1_dir; }
    std::string GetA1ConfigDir() { return g_jb.a1config; }
    bool SetProcessNiceValue(pid_t pid, int nice_value) {
        if (nice_value < -20 || nice_value > 19) {
            xmz::log::warn("Nice value must be between -20 and 19");
            return false;
        }
        int priority = nice_value + 20;
        return a1::set::priority_renice(pid, priority);
    }
    bool SetProcessJetsamValue(pid_t pid, int32_t jetsam_value) {
        if (jetsam_value < 0 || jetsam_value > 21) {
            xmz::log::warn("Jetsam priority must be between 0 and 21");
            return false;
        }
        if (kill(pid, 0) != 0) {
            xmz::log::error("Process", pid, "does not exist");
            return false;
        }
        return a1::set::priority_jetsamctl(pid, jetsam_value);
    }
    bool SetProcessPriority(int pid, int priority_value) {
        return a1::adjust_process_auto(
            pid, 
            std::to_string(priority_value).c_str()
        ) == 0;
    }
    bool SetProcessPriority(const std::string& process_name, int priority_value) {
        return a1::adjust_process_auto(
            process_name.c_str(),
            std::to_string(priority_value).c_str()
        ) == 0;
    }
private:
    a1::config::jb_path g_jb;
};

} // namespace a1::_modapi

namespace a1mod { namespace apis = a1::_modapi; }

====== end =====
===== cxxa1/src/a1pm-scan.sh =====
#!/bin/bash

set -e

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
        jb="$(jbroot)"
    else
        jb=""
    fi
fi

myini="$jb/a1/bin/myini"
REPO_DIR="${1:-.}"
OUTPUT_FILE="${2:-$REPO_DIR/Packages.ini}"
TEMP_DIR="${TMPDIR:-/tmp}/a1-scan-$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

parse_ini_metadata() {
    local metadata_file="$1"
    local section="${2:-metadata}"
    if [ ! -f "$myini" ]; then
        echo -e "${RED}[Error]${NC}: myini not found: $myini" >&2
        return 1
    fi
    local package=$("$myini" get "$metadata_file" "$section.package" 2>/dev/null || echo "")
    local name=$("$myini" get "$metadata_file" "$section.name" 2>/dev/null || echo "")
    local version=$("$myini" get "$metadata_file" "$section.version" 2>/dev/null || echo "")
    local author=$("$myini" get "$metadata_file" "$section.author" 2>/dev/null || echo "")
    local maintainer=$("$myini" get "$metadata_file" "$section.maintainer" 2>/dev/null || echo "")
    local descr=$("$myini" get "$metadata_file" "$section.description" 2>/dev/null || echo "")
    local depends=$("$myini" get "$metadata_file" "$section.depends" 2>/dev/null || echo "")
    local depends_apt=$("$myini" get "$metadata_file" "$section.depends_apt" 2>/dev/null || echo "")
    local section_name=$("$myini" get "$metadata_file" "$section.section" 2>/dev/null || echo "")
    local priority=$("$myini" get "$metadata_file" "$section.priority" 2>/dev/null || echo "")
    echo "$package|$name|$version|$author|$maintainer|$descr|$depends|$depends_apt|$section_name|$priority"
    return 0
}

compute_sha256() {
    local file="$1"
    if command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    elif command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo ""
    fi
}

get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo ""
}

scan_packages() {
    mkdir -p "$TEMP_DIR"
    local temp_packages="$TEMP_DIR/packages.tmp"
    > "$temp_packages"
    local count=0
    local output_dir=""
    if command -v realpath &>/dev/null; then
        output_dir=$(dirname "$(realpath "$OUTPUT_FILE")")
    else
        output_dir=$(dirname "$OUTPUT_FILE")
        if [[ "$output_dir" != /* ]]; then
            output_dir="$(pwd)/$output_dir"
        fi
    fi
    while IFS= read -r -d '' module_file
    do
        local filename=$(basename "$module_file")
        local extract_dir="$TEMP_DIR/extract_${count}"
        mkdir -p "$extract_dir"
        if ! unzip -q "$module_file" -d "$extract_dir" 2>/dev/null; then
            echo -e "${RED}[Error]${NC}: unzip failed: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local metadata_file=""
        if [ -f "$extract_dir/control.ini" ]; then
            metadata_file="$extract_dir/control.ini"
        fi
        
        if [ -z "$metadata_file" ] || [ ! -f "$metadata_file" ]; then
            echo -e "${RED}[Error]${NC}: not found control.ini: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local metadata=$(parse_ini_metadata "$metadata_file" "")
        if [ $? -ne 0 ] || [ -z "$metadata" ]; then
            rm -rf "$extract_dir"
            continue
        fi
        
        IFS='|' read -r package name version author maintainer description depends depends_apt section priority <<< "$metadata"
        if [ -z "$package" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields package: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$version" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields version: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$maintainer" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields maintainer: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        if [ -z "$descr" ]; then
            echo -e "${RED}[Error]${NC}: missing necessary fields description: $filename" >&2
            rm -rf "$extract_dir"
            continue
        fi
        local file_size=$(get_file_size "$module_file")
        local sha256=$(compute_sha256 "$module_file")
        local file_path=""
        if command -v realpath &>/dev/null; then
            file_path=$(realpath --relative-to="$output_dir" "$module_file" 2>/dev/null)
        else
            local module_abs=$(cd "$(dirname "$module_file")" && pwd)/$(basename "$module_file")
            file_path="${module_abs#$output_dir/}"
            if [ "$file_path" = "$module_abs" ]; then
                file_path="$filename"
            fi
        fi
        [ -z "$file_path" ] && file_path="$filename"
        descr=$(echo "$descr" | tr '\n' ' ' | sed 's/  */ /g')
        cat >> "$temp_packages" << EOF
[${package}]
package: ${package}
name: ${name:-$package}
version: $version
author: $author
maintainer: $maintainer
section: $section
priority: $priority
filename: $filename
filepath: $file_path
size: $file_size
sha256: $sha256
depends: $depends
depends_apt: $depends_apt
description: $descr

EOF
        count=$((count + 1))
        rm -rf "$extract_dir"
    done < <(find "$REPO_DIR" \( -name "*.a1mod" -o -name "*.a1module.zip" \) -print0 | sort -z)
    if [ $count -gt 0 ]; then
        echo "the file is in: $OUTPUT_FILE"
    else
        echo -e "${RED}[Error]${NC}: no .a1module.zip or .a1mod files were found."
    fi
    if [ -f "$OUTPUT_FILE" ]; then
        local file_size=$(get_file_size "$OUTPUT_FILE")
        echo "Size: $file_size B"
    fi
}

show_help() {
    cat << EOF
Usage: $0 [options] [dir]
options:
  -o, --output FILE     specify the output file (default: Packages.ini)
  -h, --help            Show this help
Tips:
  $0 .                              # Scan the current directory and subdirectories
  $0 . -o ./Packages.ini            # Specify the output file
  $0 ./a1mod -o ./Packages.ini      # Scan the a1mod directory

EOF
}

main() {
    while [[ $# -gt 0 ]]
    do
        case "$1" in
            -o|--output)
                OUTPUT_FILE="$2"; shift 2 ;;
            -h|--help)
                show_help; exit 0 ;;
            -*)
                echo -e "${RED}[Error]${NC}: unknown option: $1" >&2
                show_help; exit 1 ;;
            *)
                REPO_DIR="$1"; shift ;;
        esac
    done
    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${RED}[Error]${NC}: the directory does not exist.: $REPO_DIR" >&2
        exit 1
    fi
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
    fi
    scan_packages
}

main "$@"

====== end =====
===== cxxa1/src/cxxa1.cc =====
// cxxa1.cc
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/time.hpp>

#include <a1/core/a1core.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>
#include <a1/core/set_defaults.hpp>
#include <a1/core/mod/a1mod_luarun.hpp>
#include <a1/core/version.hpp>

#include <string>
#include <csignal>
#include <ctime>
#include <iostream>
#include <fstream>
#include <vector>
#include <algorithm>

// wait for SpringBoard
void wait_for_springboard() {
    xmz::println("checking SpringBoard...");
    while (true) {
        int sb_pid = a1::bin::bundle_pid("com.apple.springboard");
        if (sb_pid == -1) {
            sb_pid = a1::bin::bundle_pid("SpringBoard");
        }
        if (sb_pid != -1) {
            if (kill(sb_pid, 0) == 0) {
                xmz::println("SpringBoard ready.");
                break;
            }
        }
        xmz::println("waiting for SpringBoard...");
        sleep(3);
    }
}
// apply custom priority settings
int apply_custom_priority() {
    auto& config = a1::coreapi::set_defaults_cfg();
    a1::config::jb_path g_jb;
    if (!config.custom_priority_enabled) { return 0; }
    std::string custom_file = g_jb.a1_dir + "/custom_priority.list";
    if (xmz::aux::is_file(custom_file.c_str())) { return 0; }
    xmz::println("Applying custom priority settings...");
    a1::ini::ini_parser parser;
    if (!parser.parse_file(custom_file)) {
        xmz::perrln("  Failed to parse custom priority file");
        return 0;
    }

    int count = 0;
    auto process_names = parser.get_key("");
    for (const auto& process_name : process_names) {
        int priority = parser.get_int("", process_name, 20);
        pid_t pid = -1;
        a1::find_pid_by_name(process_name.c_str(), pid);
        if (pid > 0) {
            if (a1::set::priority(pid, priority)) {
                if (config.debug_mode) {
                    xmz::println("  " + process_name + " -> " + std::to_string(priority));
                }
                count++;
            }
        }
    }

    if (count > 0) {
        xmz::println("Adjusted " + std::to_string(count) + " processes with custom priorities");
    }
    return count;
}
// main optimization logic
void optimize_system() {
    auto& config = a1::coreapi::set_defaults_cfg();
    xmz::println("Optimizing system priorities...");
    wait_for_springboard();
    a1::priority_manager pm;
    pm.read_priority_lists(false);
    // apply high priority list
    const auto& high_list = pm.get_high_list();
    if (!high_list.empty()) {
        xmz::println("Boosting critical processes (jetsam priority: " + 
                     std::to_string(config.high_priority) + "):");
        xmz::println("If it fails, please try to re-execute it with sudo a1");
        int count = 0;
        for (const auto& process : high_list) {
            pid_t pid = -1;
            a1::find_pid_by_name(process.c_str(), pid);
            if (pid > 0) {
                if (a1::set::priority(pid, config.high_priority)) {
                    if (config.debug_mode) {
                        xmz::println("  " + process + " (PID:" + 
                                    std::to_string(pid) + ") -> " + 
                                    std::to_string(config.high_priority));
                    }
                    count++;
                }
            } else {
                if (config.debug_mode) {
                    xmz::println("  " + process + " not found");
                }
            }
        }
        xmz::println("  Adjusted " + std::to_string(count) + 
                    " processes to priority " + std::to_string(config.high_priority));
        xmz::println("");
    } else {
        xmz::log::warn("No high priority processes defined");
        xmz::println("");
    }
    // apply low priority list
    const auto& low_list = pm.get_low_list();
    if (!low_list.empty()) {
        xmz::println("Lowering non-essential processes (jetsam priority: " + 
                     std::to_string(config.low_priority) + "):");
        int count = 0;
        for (const auto& process : low_list) {
            pid_t pid = -1;
            a1::find_pid_by_name(process.c_str(), pid);
            if (pid > 0) {
                if (a1::set::priority(pid, config.low_priority)) {
                    if (config.debug_mode) {
                        xmz::println("  " + process + " (PID:" + 
                                    std::to_string(pid) + ") -> " + 
                                    std::to_string(config.low_priority));
                    }
                    count++;
                }
            } else {
                if (config.debug_mode) {
                    xmz::println("  " + process + " not found");
                }
            }
        }
        xmz::println("  Adjusted " + std::to_string(count) + 
                    " processes to priority " + std::to_string(config.low_priority));
        xmz::println("");
    } else {
        xmz::log::warn("No low priority processes defined");
        xmz::println("");
    }
    // apply custom priority
    apply_custom_priority();
    xmz::println("_______________________________________________");
    xmz::println("Optimization complete");
    xmz::println("_______________________________________________");
}

// reload configuration
void read_a1_config() {
    a1::coreapi::set_defaults();
    xmz::println("configuration reloaded from environment");
}

void load_modules(a1mod::luatime& lt) {
    a1::config::jb_path g_jb;
    a1::ini::ini_parser pini;
    struct modinfo {
        std::string section;
        std::string status;
        std::string path;
    };
    auto getmod = [&]() -> std::vector<modinfo> {
        std::string filepath = g_jb.mod_dir + "/module.db.ini";
        std::vector<modinfo> result;
        if (!pini.parse_file(filepath)) { return result; }
        auto sections = pini.get_sec();
        for (const auto& section : sections) {
            modinfo info;
            info.section = section;
            info.status = pini.get(section, "status", "");
            info.path = pini.get(section, "path", "");
            if (!info.status.empty() && !info.path.empty()) { result.push_back(info); }
        }
        return result;
    };
    std::vector<modinfo> modules = getmod();
    if (modules.empty()) {
        xmz::log::info("No modules found to load");
        return;
    }
    for (const auto& mod : modules) {
        if (mod.status == "enabled") {
            if (xmz::aux::is_file(mod.path + "/main.lua") == 0) {
                lt.run_file(mod.path + "/main.lua");
                xmz::log::info("Module:", mod.section, "run successfully");
            } else {
                xmz::log::warn("Module:", mod.section, "main.lua not found at:", mod.path);
            }
        } else {
            xmz::log::info("Module:", mod.section, "not activated (status:", mod.status, ")");
        }
    }
}

int main() {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1 need set jb env value!");
        xmz::log::info("Use a1 status, not cxxa1!");
        return 1;
    }
    a1::config::jb_path g_jb;
    a1mod::luatime lt;
    xmz::println(xmz::get_time_str());
    xmz::println("______________________");
    xmz::println("A1 are working......");
    xmz::println("A1 Version:", a1::_coreapi::a1_version);
    xmz::println("----------------------");
    // Initialize environment, read defaults from environment
    a1::coreapi::set_defaults();
    auto& config = a1::coreapi::set_defaults_cfg();
    // read priority lists
    a1::priority_manager pm;
    pm.read_priority_lists(false);
    // Load modules
    if (config.module_switch == true) {
        lt.init();
        load_modules(lt);
    } else {
        xmz::log::info("the module system is shut down");
    }
    a1::apply_kernel_patches();
    a1::adjust_launchd(config.launchd_priority);
    optimize_system();
    // log reincarnation
    if (config.log_reincarnation) {
        std::string info_log = g_jb.a1_dir + "/a1.log";
        std::string err_log = g_jb.a1_dir + "/a1error.log";
        xmz::println("cleaning up...");
        std::ofstream info_file(info_log, std::ios::trunc);
        info_file.close();
        std::ofstream err_file(err_log, std::ios::trunc);
        err_file.close();
    }
    // mode selection
    if (config.auto_adjust) {
        xmz::println("starting Auto-Adjust (real-time) mode...");
        a1::auto_adjust();
    } else if (config.scheduled_guard) {
        xmz::println("starting Scheduled Guard mode...");
        a1::scheduled_guard();
    } else if (config.loop_mode) {
        xmz::println("starting Loop mode...");
        while (true) {
            // countdown display
            for (int i = config.loop_sleep_interval; i >= 1; i--) {
                xmz::print("\rNext Circulate Time:" + std::to_string(i) + "s");
                std::cout.flush();
                sleep(1);
            }
            xmz::println("");
            // reload config
            read_a1_config();
            // check if loop mode is still enabled
            if (!a1::coreapi::set_defaults_cfg().loop_mode) { break; }
            // re-read priority lists with filter
            pm.read_priority_lists(true);
            xmz::println("Running optimization cycle...");
            optimize_system();
        }
    } else {
        xmz::log::warn("No monitoring mode enabled.");
        return 0;
    }
    xmz::println("All operations completed successfully");
    sleep(1);
    return 0;
}

====== end =====
===== cxxa1/src/cxxa1mod.cc =====
// cxxa1mod.cc

#include <string>

#include <libxmz/fs.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/a1mod_version.hpp>
#include <a1/core/mod/a1mod_depends.hpp>
#include <a1/core/a1modcore.hpp>
#include <a1/core/version.hpp>
#include <a1/core/lock.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>

inline std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " [command] [option]") + R"(
  init                    Initialize the module system
  list                    List all installed modules
  package <dir> <name>    Packaging module
  install <file>          Install the module from the local file
  remove <ModID>          Delete the module
  enable <ModID>          Enable the module
  disable <ModID>         Disable the module
  help                    Show this help message
  version                 Show version message
)";
}

a1ctl::lock_manager g_lock_mgr;
inline void signal_handler(int sig) {
    xmz::log::info("received the signal", sig, "is cleaning up and exiting...");
    g_lock_mgr.release();
    exit(sig);
}

int main(int argc, char *argv[]) {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1Mod need set jb env value!");
        xmz::log::info("Use a1mod status, not cxxa1mod");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1mod::config cfg;
    //a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    //a1ctl::init_config();

    std::string lock_file = g_jb.mod_dir + "/lock";
    g_lock_mgr.init(lock_file);
    g_lock_mgr.set_enabled(true);
    if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });

    std::string cmd = argv[1];

    auto check_opt = [](char *arg) -> bool { if (arg == nullptr) { return false; } return true; };

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd.empty()) {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "init") {
        a1mod::init_system(cfg, g_jb);
    } else if (cmd == "install" || cmd == "i") {
        if (!check_opt(argv[2])) { xmz::log::error("the kit id cannot be empty."); return 1; }
        a1mod::install(argv[2]);
    } else if (cmd == "remove" || cmd == "r") {
        if (!check_opt(argv[2])) { xmz::log::error("the kit id cannot be empty."); return 1; }
        a1mod::remove(argv[2]);
    } else if (cmd == "list" || cmd == "l") {
        a1mod::list_modules();
    } else if (cmd == "enable") {
        if (!check_opt(argv[2])) { xmz::log::error("the kit id cannot be empty."); return 1; }
        check_opt(argv[2]);
        a1mod::enable_module(argv[2]);
    } else if (cmd == "disable") {
        a1mod::disable_module(argv[2]);
    } else if (cmd == "package" || cmd == "pack") {
        if (!check_opt(argv[2])) { xmz::log::error("the catalog cannot be empty."); return 1; }
        if (!check_opt(argv[3])) { xmz::log::error("the name cannot be empty."); return 1; }
        a1mod::package_module(argv[2], argv[3]);
    } else if (cmd == "version" || cmd == "V") {
        xmz::println("A1Mod Version:", a1::_coreapi::a1mod_version);
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1mod help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}

====== end =====
===== cxxa1/src/a1cil.sh =====
#!/bin/bash
#a1cil.sh
#set -x # debug

jbdpkgarch="$(dpkg --print-architecture)"

if test "$jbdpkgarch" = "iphoneos-arm64"; then
    jb="/var/jb"
elif test "$jbdpkgarch" = "iphoneos-arm64e"; then
    jb="$(jbroot)"
else
    unset jb
    jb=""
fi

export jb
jb_a1="$jb/a1"
export jb_a1
myself="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

[ ! -f "$jb/usr/local/bin/a1ctl" ] && ln -sf $myself "$jb/usr/local/bin/a1ctl"
[ ! -f "$jb/usr/local/bin/a1mod" ] && ln -sf $myself "$jb/usr/local/bin/a1mod"
[ ! -f "$jb/usr/local/bin/a1" ] && ln -sf $myself "$jb/usr/local/bin/a1"
[ ! -f "$jb/usr/local/bin/a1pm" ] && ln -sf $myself "$jb/usr/local/bin/a1pm"

case "$0" in
    *a1ctl)
       # exec ./cxxa1ctl "$@"
        exec "$jb_a1/bin/cxxa1ctl" "$@"
        ;;
    *a1mod)
       # exec ./cxxa1mod "$@"
        exec "$jb_a1/bin/cxxa1mod" "$@"
        ;;
    *a1)
       # exec ./cxxa1
        exec "$jb_a1/bin/cxxa1"
        ;;
    *a1pm)
       # exec ./cxxa1pm "$@"
        exec "$jb_a1/bin/cxxa1pm" "$@"
    *)
        printf "%s\n" "$0: please run a1 or a1ctl or a1mod or a1pm, not $jb_a1/bin/a1cil"
esac

====== end =====
===== cxxa1/src/cxxa1ctl.cc =====
// cxxa1ctl.cc
#include <a1/core/a1ctlcore.hpp>
#include <a1/core/version.hpp>
#include <a1/core/lock.hpp>
#include <a1/core/myini.hpp>

#include <libxmz/log.hpp>
#include <libxmz/io.hpp>
#include <string>
#include <cstdlib>
#include <unistd.h>

inline std::string help_text(const std::string& myself) {
    return std::string(R"(
  __    _       _     _     ___  
 / /\  / |     | |_| | | | | |_) 
/_/--\ |_|     |_| | \_\_/ |_|_) 

Author: LF | Maintainer: LF, AD
Organization(QQ): 1030152896
)") + "Usage: " + myself + " [options] [command]" + R"(
Basic Commands:
  start                    Start A1
  stop                     Stop A1
  status                   View status
  restart                  Restart A1

Mode Control:
  loop <on|off>            Enable/disable loop mode
  auto-adjust <on|off>     Enable/disable real-time auto-adjust mode (1s polling)
  scheduled-guard <on|off> Enable/disable scheduled guard mode (15s polling)
  olr <on|off>             Enable/disable log reincarnation
  custom <on|off>          Enable/disable custom priority

Priority Management:
  add high <process>       Add to high priority list
  add low <process>        Add to low priority list
  add <process> <value>    Add custom priority (0-99)
  remove <process>         Remove from priority list
  list <high|low|custom>   View priority list
  clear <high|low|custom>  Clear priority list
  set <type> <value>       Set priority value

  type: high, low, launchd*
  value: 0-39 (Jetsam value)

Configuration Management:
  config                   View current configuration
  set-interval <seconds>   Set optimization interval
  loop-sleep <seconds>     Set loop interval
  auto-apply <on|off>      Enable/disable auto-apply
  restore                  Restore configuration from backup
  compat <on|off>          Enable/disable compatibility mode
  mod-switch <on|off>      Enable/turn off the mod mode

Other:
  help                     Show this help
  version                  Show Version
  -f                       Forced start/foreground mode

Tips:
  Real-time auto-adjust mode: Check new processes every second and adjust priority (more aggressive)
  Scheduled guard mode: Check every 15 seconds (more battery efficient)
  Loop mode: Traditional mode, periodically execute full optimization
  -20=Highest (Jetsam 0)
  0=Default
  19=Lowest (Jetsam 39)
  Default priority is determined by the launchd process
)";
}

a1ctl::lock_manager g_lock_mgr;
inline void signal_handler(int sig) {
    xmz::log::info("received the signal", sig, "is cleaning up and exiting...");
    g_lock_mgr.release();
    exit(sig);
}

int main(int argc, char *argv[]) {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1Ctl need set jb env value!");
        xmz::log::info("Use a1ctl status, not cxxa1ctl!");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    a1ctl::init_config();
    auto& g_cfg = a1::coreapi::get_cfg();

    bool lock_use = pini.get_bool("", "lock_use", true);

    if (lock_use) {
        std::string lock_file = g_jb.a1_dir + "/lock";
        g_lock_mgr.init(lock_file);
        g_lock_mgr.set_enabled(true);
        if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });
        //xmz::log::debug("successfully obtained the file lock");
    } /* else {
        //xmz::log::debug("the lock has been disabled. skip this stage");
    } */

    std::string cmd = argv[1];

    auto check_opt = [](char *arg) -> bool { if (arg == nullptr) { return false; } return true; };

    if (cmd == "1" || cmd == "start") {
        a1ctl::start_a1();
    } else if (cmd == "0" || cmd == "stop") {
        a1::kill_pid();
        xmz::log::info("A1 has stopped");
    } else if (cmd == "restart") {
        a1::kill_pid();
        sleep(2);
        a1ctl::start_a1();
    } else if (cmd == "status") {
        a1ctl::check_status();
    } else if (cmd == "loop") {
        if (argc < 3) {
            xmz::log::error("usage: loop <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("loop", true);
            a1ctl::update_config("auto_adjust", false);
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("loop mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("loop", false);
            xmz::log::info("loop mode is off");
        } else {
            xmz::log::error("usage: loop <on|off>");
        }
    } else if (cmd == "auto-adjust") {
        if (argc < 3) {
            xmz::log::error("usage: auto-adjust <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("auto_adjust", true);
            a1ctl::update_config("loop", false);
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("real-time auto-adjust mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("auto_adjust", false);
            xmz::log::info("real-time auto-adjust mode is off");
        } else {
            xmz::log::error("usage: auto-adjust <on|off>");
        }
    } else if (cmd == "scheduled-guard" || cmd == "guard") {
        if (argc < 3) {
            xmz::log::error("usage: scheduled-guard <on|off> or guard <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("scheduled_guard", true);
            a1ctl::update_config("loop", false);
            a1ctl::update_config("auto_adjust", false);
            xmz::log::info("scheduled guard mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("scheduled guard mode is off");
        } else {
            xmz::log::error("usage: scheduled-guard <on|off> or guard <on|off>");
        }
    } else if (cmd == "olr") {
        if (argc < 3) {
            xmz::log::error("usage: olr <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("log_reincarnation", true);
            xmz::log::info("log reincarnation is on");
        } else if (opt == "off") {
            a1ctl::update_config("log_reincarnation", false);
            xmz::log::info("log reincarnation is off");
        } else {
            xmz::log::error("usage: olr <on|off>");
        }
    } else if (cmd == "custom") {
        if (argc < 3) {
            xmz::log::error("usage: custom <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("custom_priority_enabled", true);
            xmz::log::info("custom priority is on");
        } else if (opt == "off") {
            a1ctl::update_config("custom_priority_enabled", false);
            xmz::log::info("custom priority is off");
        } else {
            xmz::log::error("usage: custom <on|off>");
        }
    } else if (cmd == "add") {
        if (argc < 3) {
            xmz::log::error("usage: add <high|low> <process> or add <process> <value>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "high" || opt == "h") {
            if (!check_opt(argv[3])) { xmz::log::error("the process name cannot be empty."); return 1; }
            a1ctl::add_priority("h", argv[3], g_cfg.high_priority);
        } else if (opt == "low" || opt == "l") {
            if (!check_opt(argv[3])) { xmz::log::error("the process name cannot be empty."); return 1; }
            a1ctl::add_priority("l", argv[3], g_cfg.low_priority);
        } else {
            std::string type = "c";
            std::string process = argv[2];
            int value = std::stoi(argv[3]);
            a1ctl::add_priority(type, process, value);
        }
    } else if (cmd == "remove") {
        if (argc < 3) {
            xmz::log::error("usage: remove <process>");
            return 1;
        }
        a1ctl::remove_priority("high", argv[2]);
        a1ctl::remove_priority("low", argv[2]);
        a1ctl::remove_priority("custom", argv[2]);
    } else if (cmd == "list") {
        if (argc < 3) {
            xmz::log::error("usage: list <high|low|custom>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the options cannot be empty."); return 1; }
        a1ctl::list_priority(argv[2]);
    } else if (cmd == "clear") {
        if (argc < 3) {
            xmz::log::error("usage: clear <high|low|custom>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the options cannot be empty."); return 1; }
        a1ctl::clear_priority(argv[2]);
    } else if (cmd == "set") {
        if (argc < 4) {
            xmz::log::error("usage: set <high|low|launchd> <value>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the options cannot be empty."); return 1; }
        if (!check_opt(argv[3])) { xmz::log::error("the value cannot be empty."); return 1; }
        a1ctl::set_priority_value(argv[2], std::atoi(argv[3]));
    } else if (cmd == "config" || cmd == "show-config") {
        a1ctl::show_config();
    } else if (cmd == "set-interval") {
        if (argc < 3) {
            xmz::log::error("usage: set-interval <seconds>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the seconds cannot be empty."); return 1; }
        a1ctl::update_config_int("optimize_interval", std::atoi(argv[2]));
    } else if (cmd == "loop-sleep") {
        if (argc < 3) {
            xmz::log::error("usage: loop-sleep <seconds>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the seconds cannot be empty."); return 1; }
        int val = std::atoi(argv[2]);
        if (val < 1) {
            xmz::log::error("loop sleep time must be a positive integer");
            return 1;
        }
        a1ctl::update_config_int("loop_sleep_interval", val);
    } else if (cmd == "auto-apply") {
        if (argc < 3) {
            xmz::log::error("usage: auto-apply <on|off>");
            return 1;
        }
        if (!check_opt(argv[2])) { xmz::log::error("the options cannot be empty."); return 1; }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::set_auto_apply(true);
        } else if (opt == "off") {
            a1ctl::set_auto_apply(false);
        } else {
            xmz::log::error("unknown option:", opt);
            xmz::log::error("usage: auto-apply <on|off>");
            return 1;
        }
    } else if (cmd == "restore" || cmd == "restore-config") {
        a1ctl::init_config();
        xmz::log::info("configuration restored from backup");
    } else if (cmd == "compat" || cmd == "compat-mode") {
        if (argc < 3) {
            xmz::log::error("usage: compat <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::compat_mode(true);
        } else if (opt == "off") {
            a1ctl::compat_mode(false);
        } else {
            xmz::log::error("unknown option:", opt);
            xmz::log::error("usage: compat <on|off>");
            return 1;
        }
    } else if (cmd == "mod-switch") {
        if (argc < 3) {
            xmz::log::error("usage: mod-switch <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::mod_switch_mode(true);
        } else if (opt == "off") {
            a1ctl::mod_switch_mode(false);
        } else {
            xmz::log::error("unknown option:", opt);
            xmz::log::error("usage: mod-switch <on|off>");
            return 1;
        }
    } else if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "version") {
        xmz::println("A1Ctl Version:", a1::_coreapi::a1ctl_version);
    } else if (cmd == "-f") {
        if (argc >= 3 && std::string(argv[2]) == "start") {
            a1ctl::start_a1_foreground();
        } else {
            xmz::log::error("command error: ", (argc >= 3 ? argv[2] : ""));
        }
    } else if (cmd == "lock") {
        if (argc < 3) {
            xmz::log::error("usage: lock <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("lock_use", true);
            xmz::log::info("lock has been turned on");
            xmz::log::info("lock is a mechanism that can ensure that the program is not affected by other processes when running,");
            xmz::log::info("avoid accidents (such as document damage, etc.)");
            xmz::log::info("but it also has its own shortcomings: it can only be executed in a single process and cannot be executed simultaneously.");
        } else if (opt == "off") {
            a1ctl::update_config("lock_use", false);
            xmz::log::info("lock is closed");
            xmz::log::warn("lock has been turned off, and a1 can now perform multi-threaded mode.");
            xmz::log::warn("however, this may cause data such as configuration files to be damaged.");
        } else {
            xmz::log::error("please enter on/off, such as a1ctl lock on");
        }
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1ctl help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}

====== end =====
===== cxxa1/src/cxxa1pm.cc =====
// cxxa1pm.cc

#include <string>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1pmcore.hpp>
#include <a1/core/lock.hpp>

std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " <command> [options]") + R"(
command:
  add-repo <url>        Add a remote warehouse
  remove-repo <url>     Delete the remote warehouse
  list                  List all warehouses
  update                Synchronized warehouse index
  search <package id>   Search for remote packages
  info <package id>     Display the details of the remote package
  install <package id>  Install the package from the remote end
  remove <package id>   Remove the module
  upgrade [package id]  Upgrade module
  upgrade-full          Upgrade all modules
  check-update          Check for available updates
  help                  Show this help message
  version               Display the version number
)";
}

a1ctl::lock_manager g_lock_mgr;
inline void signal_handler(int sig) {
    xmz::log::info("received the signal", sig, "is cleaning up and exiting...");
    g_lock_mgr.release();
    exit(sig);
}

int main(int argc, char *argv[]) {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1Mod need set jb env value!");
        xmz::log::info("Use a1mod status, not cxxa1mod");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1pm::config cfg;
    a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    a1pm::init_repo_list();

    std::string lock_file = cfg.pm_cache + "/lock";
    g_lock_mgr.init(lock_file);
    g_lock_mgr.set_enabled(true);
    if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });

    std::string cmd = argv[1];

    auto check_opt = [](char *arg) -> bool { if (arg == nullptr) { return false; } return true; };

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "add-repo") {
        if (!check_opt(argv[2])) { xmz::log::error("the url cannot be empty."); return 1; }
        a1pm::add_repo(argv[2]);
    } else if (cmd == "remove-repo") {
        if (!check_opt(argv[2])) { xmz::log::error("the url cannot be empty."); return 1; }
        a1pm::remove_repo(argv[2]);
    } else if (cmd == "install") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::install_package(argv[2]);
    } else if (cmd == "remove") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::remove_package(argv[2]);
    } else if (cmd == "list") {
        a1pm::list_repos();
    } else if (cmd == "search") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::search_package(argv[2]);
    } else if (cmd == "info") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::search_package_detail(argv[2]);
    } else if (cmd == "update") {
        a1pm::update_all_repos();
    } else if (cmd == "upgrade") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::update_package(argv[2]);
    } else if (cmd == "upgrade-full") {
        a1pm::update_all_packages();

    } else if (cmd == "check-update") {
        a1pm::check_updates();
    } else if (cmd == "version" || cmd == "V") {
        xmz::println("A1PM Version:", a1::_coreapi::a1mod_version);
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1pm help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}


====== end =====
