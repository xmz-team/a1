// a1pmcore.hpp
#pragma once

#include <string>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/time.hpp>

#include <a1/core/pm/a1pm_config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/pm/all.hpp>

namespace a1pm {
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
			xmz::fs::append(repo_text, cfg.repo_f);
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

	inline void list_repos() {
		a1pm::config cfg;
		//a1::ini::ini_parser pini;
		xmz::println("current source list");
		xmz::fs::readfile(cfg.repo_f);
	}
} /* namespace a1pm */

