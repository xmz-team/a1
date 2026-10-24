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
