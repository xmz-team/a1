print("hello")
print("------------")
print("High priority list")
print(a1.GetHighPriorityList())
print("------------")
print("Low priority list")
print(a1.GetLowPriorityList())
print("------------")
if (a1.GetProcessPid("a1") == -1) then
    print("a1 is not running")
else
    print("a1 pid is " .. a1.GetProcessPid("a1"))
end
