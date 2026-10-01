# a1
this is the source code repository of a1 and its accessory suite.  

[API Document](./docs/lua_api.md)

# build
```bash
git clone --recursive https://github.com/xmz-team/a1.git
# if you use ssh
# git clone --recursive git@github.com:xmz-team/a1.git
cd a1
SDKROOT=[path/to/sdks/XXX.sdk] ./build build-a1-all build-a1-tool pack-all
# example
# SDKROOT="/var/theos/sdks/iPhoneOS16.5.sdk" ./build build-a1-all build-a1-tool pack-all
# SDKROOT="${THEOS_SDK_ROOT}" ./build build-a1-all build-a1-tool pack-all
# SDKROOT="${THEOS_SDK_ROOT}" ./build build-a1-all build-a1-tool pack-all --is-local-build
# If you are a PC/non-iOS
# ./build build-a1-all build-a1-tool pack-all
```

# description
Optimize Jetsam and kernel parameters to enhance background task performance.  
Reduce priority of non-essential processes to improve system fluidity.  
Modify kernel memory management parameters for better background task handling.  
Enter a1 manual execution in the terminal, and enter a1ctl to open the management panel.  

---

