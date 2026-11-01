c++ -ObjC++ \
  -Wl,-rpath,/usr/lib \
  -Wl,-rpath,/lib \
  -Wl,-rpath,/usr/local/lib \
  -Wl,-rpath,/var/jb/usr/lib \
  -Wl,-rpath,/var/jb/lib \
  -Wl,-rpath,/var/jb/usr/local/lib \
  -Wl,-rpath,@loader_path/.jbroot/usr/local/lib \
  -Wl,-rpath,@loader_path/.jbroot/usr/lib \
  -Wl,-rpath,@loader_path/.jbroot/lib \
  -I../../src/cxxa1 -I../../ \
  -framework CoreFoundation \
  -framework Foundation \
  main.cc -o ../obj/uialert-t
