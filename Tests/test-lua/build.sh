c++ -ObjC++ \
  -I../../src/cxxa1 -I../../ \
  -I../../src/bin/bundle \
  -I../../libs/lua \
  -framework Foundation \
  -framework Security \
  ../../libs/lua/liblua.a \
  test.cc -o test-lua
