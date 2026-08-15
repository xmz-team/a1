// myini.cc

#include <string>

#include <a1/core/myini.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

a1::ini::ini_parser pini;

std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + R"( <command> [options] <file> [section.key|.key]
Commands:
  get <file> [section.]key        Get string value
  get-int <file> [section.]key    Get integer value
  get-bool <file> [section.]key   Get boolean value
  set <file> [section.]key <val>  Set string value
  set-int <file> [section.]key <val> Set integer value
  set-bool <file> [section.]key <val> Set boolean value
  list-sec <file>                 List sections
  list-key <file> [section]       List keys in section
  rm-key <file> [section.]key     Remove key
  rm-sec <file> <section>         Remove section
  help                            Show this help
  version                         Show version
)";
}

std::pair<std::string, std::string> parse_section_key(const std::string& input) {
    if (input.empty()) return {"", ""};
    if (input[0] == '.') { return {"", input.substr(1)}; }
    auto pos = input.find('.');
    if (pos != std::string::npos) { return {input.substr(0, pos), input.substr(pos + 1)}; }
    return {"", input};
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        xmz::println(help_text(argv[0]));
        return 1;
    }

    std::string cmd = argv[1];

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h") {
        xmz::println(help_text(argv[0]));
        return 0;
    }

    if (cmd == "version" || cmd == "V" || cmd == "-V" || cmd == "--version") {
        xmz::println(argv[0], "version 0.0.1");
        return 0;
    }

    if (cmd == "list-sec" && argc >= 3) {
        std::string filepath = argv[2];
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:", filepath);
            return 1;
        }
        pini.parse_file(filepath);
        auto secs = pini.get_sec();
        for (const auto& s : secs) { xmz::println(s); }
        return 0;
    }
    if (cmd == "list-key" && argc >= 3) {
        std::string filepath = argv[2];
        std::string section = (argc >= 4) ? argv[3] : "";
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:", filepath);
            return 1;
        }
        pini.parse_file(filepath);
        auto keys = pini.get_key(section);
        for (const auto& k : keys) { xmz::println(k); }
        return 0;
    }

    if (cmd == "rm-key" && argc >= 4) {
        std::string filepath = argv[2];
        auto [sec, key] = parse_section_key(argv[3]);
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:", filepath);
            return 1;
        }
        pini.parse_file(filepath);
        if (pini.rmkey(sec, key)) {
            pini.save(filepath);
            xmz::println("Removed key:", sec.empty() ? key : sec + "." + key);
        } else {
            xmz::log::error("Key not found:", sec.empty() ? key : sec + "." + key);
            return 1;
        }
        return 0;
    }

    if (cmd == "rm-sec" && argc >= 4) {
        std::string filepath = argv[2];
        std::string section = argv[3];
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:", filepath);
            return 1;
        }
        pini.parse_file(filepath);
        if (pini.rmsec(section)) {
            pini.save(filepath);
            xmz::println("removed section:", section);
        } else {
            xmz::log::error("section not found:", section);
            return 1;
        }
        return 0;
    }

    if ((cmd == "get" || cmd == "get-str" || cmd == "get-int" || cmd == "get-bool") && argc >= 4) {
        std::string filepath = argv[2];
        auto [sec, key] = parse_section_key(argv[3]);
        if (key.empty()) {
            xmz::log::error("Key is required");
            return 1;
        }
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:", filepath);
            return 1;
        }
        pini.parse_file(filepath);
        if (cmd == "get" || cmd == "get-str") {
            std::string val = pini.get(sec, key);
            xmz::println(val);
        } else if (cmd == "get-int") {
            int val = pini.get_int(sec, key);
            xmz::println(val);
        } else if (cmd == "get-bool") {
            bool val = pini.get_bool(sec, key);
            xmz::println(val ? "true" : "false");
        }
        return 0;
    }

    if ((cmd == "set" || cmd == "set-str" || cmd == "set-int" || cmd == "set-bool") && argc >= 5) {
        std::string filepath = argv[2];
        auto [sec, key] = parse_section_key(argv[3]);
        std::string val = argv[4];
        if (key.empty()) {
            xmz::log::error("Key is required");
            return 1;
        }
        if (xmz::aux::is_file(filepath) != 0) { xmz::fs::touch(filepath); }
        pini.parse_file(filepath);
        if (cmd == "set" || cmd == "set-str") {
            pini.set(sec, key, val);
            xmz::println("Set", sec.empty() ? key : sec + "." + key, "=", val);
        } else if (cmd == "set-int") {
            try {
                int ival = std::stoi(val);
                pini.set_int(sec, key, ival);
                xmz::println("Set", sec.empty() ? key : sec + "." + key, "=", ival);
            } catch (...) {
                xmz::log::error("Invalid integer value:", val);
                return 1;
            }
        } else if (cmd == "set-bool") {
            bool bval = (val == "true" || val == "1" || val == "yes" || val == "on");
            pini.set_bool(sec, key, bval);
            xmz::println("Set", sec.empty() ? key : sec + "." + key, "=", (bval ? "true" : "false"));
        }
        pini.save(filepath);
        return 0;
    }

    xmz::log::error("Unknown command:", cmd);
    xmz::println(help_text(argv[0]));
    return 1;
}
