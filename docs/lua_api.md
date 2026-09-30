# A1 Lua API

# Lua introduction
Lua is a lightweight and compact scripting language, written in standard C and available as open-source code. It was designed to be embedded in applications, providing flexible extension and customization features for them.  
Its design is meant to be embedded into applications, giving them flexible ways to expand and customize.  

# Get API
a1.GetProcessPid()               Get process pid  
a1.GetProcessName()              Get process name  
a1.GetNiceValue()                Get process nice value  
a1.GetCPUUsage()                 Get CPU Usage  
a1.GetHighPriorityList()         Get the list of high-priority processes  
a1.GetLowPriorityList()          Get the list of low-priority processes  
a1.GetCustomPriorityList()       Get the list of custom-priority processes  
a1.GetParsedHighList()           Get parsed high list  
a1.GetParsedLowList()            Get parsed low list  
a1.GetParsedCustomList()         Get parsed custom list  
a1.GetPresetHighPriorityList()   Get preset high priority list  
a1.GetPresetLowPriorityList()    Get preset high priority list  
a1.GetA1Dir()                    Get A1 main path  
a1.GetA1ConfigDir()              Get A1 config path  

# Assist API
a1.IsDeviceLocked()              Check if SpringBoard is locked  
a1.IsA1Running()                 Check if A1 is running  

# Set API
a1.SetProcessNiceValue()         Set process nice value  
a1.SetProcessJetsamValue()       Set process jetsam value  
a1.SetProcessPriority()          Set process priority (pid or name)  
a1.SetKernSysctlByName()         Set kernel sysctl by name  
a1.GetAndSetKernSysctl()         Get current value then set kernel sysctl  
a1.SetVmSysctlByName()           Set VM sysctl by name  
a1.GetAndSetVmSysctl()           Get current value then set VM sysctl  
a1.GetVmSwapUsage()              Print VM swap usage info  

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
# A1 is running?
if (a1.GetProcessPid("a1") == -1) then
    print("a1 is not running") # if return value is -1 A1 is not running
else
    # if return value is non -1 A1 is running
    print("a1 pid is " .. a1.GetProcessPid("a1"))
end
```
---

