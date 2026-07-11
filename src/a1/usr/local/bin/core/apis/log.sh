# log.sh
# system for a1 log
cerr() { builtin printf "%b\n" "$@" >&2; }
elog() { cerr "${RED}[Error]${NC}: $@"; }
wlog() { cerr "${YELLOW}[Warn]${NC}: $@"; }
ilog() { builtin echo -e "${BLUE}[Info]${NC}: $@"; }
export -f elog
export -f wlog
export -f ilog
export -f cerr
