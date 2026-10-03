# A1 Lua API

# Lua introduction
Lua is a lightweight and compact scripting language, written in standard C and available as open-source code. It was designed to be embedded in applications, providing flexible extension and customization features for them.  
Its design is meant to be embedded into applications, giving them flexible ways to expand and customize.  

# Get API
### a1.GetProcessPid(name)
- Get process pid by name/bundle id (-1 if not found)  
### a1.GetProcessName(pid)
- Get process name by pid
### a1.GetNiceValue(pid)
- Get process nice value
### a1.GetCPUUsage(pid)
- Get CPU usage (percent)
### a1.GetHighPriorityList()
- Get the raw content of the high-priority list file
### a1.GetLowPriorityList()
- Get the raw content of the low-priority list file  
### a1.GetCustomPriorityList()
- Get the raw content of the custom-priority list file
### a1.GetParsedHighList()
- Get parsed high list (table of strings)
### a1.GetParsedLowList()
- Get parsed low list (table of strings)
### a1.GetParsedCustomList()
- Get parsed custom list (table: name -> priority)  
### a1.GetPresetHighPriorityList()
- Get preset high priority list (string)
### a1.GetPresetLowPriorityList()
- Get preset low priority list (string)
### a1.GetA1Dir()
- Get A1 main path
### a1.GetA1ConfigDir()
- Get A1 config path
### a1.GetVmSwapUsageInfo()
- Get VM swap usage info (table)

# Assist API
### a1.IsDeviceLocked()
- Check if SpringBoard is locked
### a1.IsA1Running()
- Check if A1 is running

# Set API
### a1.SetProcessNiceValue(pid, nice)
- Set process nice value (nice: -20 ~ 19)
### a1.SetProcessJetsamValue(pid, jetsam)
- Set process jetsam value (jetsam: 0 ~ 21)
### a1.SetProcessPriority(pid, priority)
- Set process priority by pid
### a1.SetProcessPriority(name, priority)
- Set process priority by name/bundle id

> **sysctl API, which is a risky function**

### a1.SetKernSysctlByName(name, value)
- Set kernel sysctl by name
### a1.GetAndSetKernSysctl(name, value, display)
- Get current value then set kernel sysctl
### a1.SetVmSysctlByName(name, value)
- Set VM sysctl by name
### a1.GetAndSetVmSysctl(name, value, display)
- Get current value then set VM sysctl
### a1.GetVmSwapUsage()
- Print VM swap usage info to stdout

# Return value details
### a1.GetVmSwapUsageInfo()
- Returns a table with the following fields:
- ok         : "true" / "false"  whether the query succeeded
- total      : total swap size (bytes)
- used       : used swap size (bytes)
- avail      : available swap size (bytes)
- free       : free swap size (bytes)
- used_ratio : usage ratio (0.0 ~ 1.0)
- error      : error message (only when ok == "false")
- err_code   : errno (only when ok == "false")

### a1.SetProcessNiceValue(pid, nice)
- nice must be in range -20 ~ 19, otherwise the call returns false.
- Internally converts to priority via `priority = nice + 20`.

### a1.SetProcessJetsamValue(pid, jetsam)
- jetsam must be in range 0 ~ 21, otherwise the call returns false.
- Returns false if the target pid does not exist.

# example
- This example will get high and low priority lists and detect whether A1 is running.
```lua
print("This is high priority list")
print("------------")
print(a1.GetHighPriorityList())
print("------------")
print("This is low priority list")
print("------------")
print(a1.GetLowPriorityList())
print("------------")
-- A1 is running?
if (a1.GetProcessPid("a1") == -1) then
    -- if return value is -1 A1 is not running
    print("a1 is not running")
else
    -- if return value is non -1 A1 is running
    print("a1 pid is " .. a1.GetProcessPid("a1"))
end

---


