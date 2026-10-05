print("hello")
print("------------")
print("High priority list")
print(a1.GetHighPriorityList())
print("------------")
print("Low priority list")
print(a1.GetLowPriorityList())
print("------------")
if (a1.GetProcessPid("cxxa1") == -1) then
    print("A1 is not running")
else
    print("A1 pid is " .. a1.GetProcessPid("cxxa1"))
end

print("A1 dir in:" .. a1.GetA1Dir())

if (a1.IsDeviceLocked()) then
    print("The iPhone is locked")
else
    local pid = a1.GetProcessPid("com.apple.springboard")
    print("SpringBoard Nice is: " .. a1.GetNiceValue(pid))

    a1.SetProcessNiceValue(pid, -15)
    print("Now SpringBoard Nice is: " .. a1.GetNiceValue(pid))

    a1.SetProcessNiceValue(pid, -20)
    print("Now SpringBoard Nice is: " .. a1.GetNiceValue(pid))
end
