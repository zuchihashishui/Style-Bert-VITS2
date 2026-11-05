# Giu may tinh khong vao Modern Standby / khong tat man hinh trong khi train.
$sig = @'
using System;
using System.Runtime.InteropServices;
public class PowerKeepAwake {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
}
'@
Add-Type -TypeDefinition $sig
while ($true) {
    [PowerKeepAwake]::SetThreadExecutionState(
        [PowerKeepAwake]::ES_CONTINUOUS -bor
        [PowerKeepAwake]::ES_SYSTEM_REQUIRED
    ) | Out-Null
    Start-Sleep -Seconds 30
}
