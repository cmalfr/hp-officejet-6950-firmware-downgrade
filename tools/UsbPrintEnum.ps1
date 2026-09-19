Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class UsbPrintEnum
{
    static Guid UsbPrintGuid = new Guid("28D78FAD-5A12-11D1-AE5B-0000F803A8C2");
    const int DIGCF_PRESENT = 0x2;
    const int DIGCF_DEVICEINTERFACE = 0x10;

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVICE_INTERFACE_DATA
    {
        public int cbSize;
        public Guid InterfaceClassGuid;
        public int Flags;
        public IntPtr Reserved;
    }

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid ClassGuid, IntPtr Enumerator, IntPtr hwndParent, int Flags);

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr DeviceInfoSet, IntPtr DeviceInfoData, ref Guid InterfaceClassGuid, int MemberIndex, ref SP_DEVICE_INTERFACE_DATA DeviceInterfaceData);

    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr DeviceInfoSet, ref SP_DEVICE_INTERFACE_DATA DeviceInterfaceData, IntPtr DeviceInterfaceDetailData, int DeviceInterfaceDetailDataSize, out int RequiredSize, IntPtr DeviceInfoData);

    [DllImport("setupapi.dll")]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr DeviceInfoSet);

    public static string[] GetInterfaces()
    {
        var result = new List<string>();
        IntPtr set = SetupDiGetClassDevs(ref UsbPrintGuid, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        if (set == new IntPtr(-1))
            throw new Exception("SetupDiGetClassDevs failed: " + Marshal.GetLastWin32Error());

        try
        {
            for (int index = 0; ; index++)
            {
                var data = new SP_DEVICE_INTERFACE_DATA();
                data.cbSize = Marshal.SizeOf(typeof(SP_DEVICE_INTERFACE_DATA));

                if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref UsbPrintGuid, index, ref data))
                {
                    int error = Marshal.GetLastWin32Error();
                    if (error == 259) break;
                    throw new Exception("SetupDiEnumDeviceInterfaces failed: " + error);
                }

                int required;
                SetupDiGetDeviceInterfaceDetail(set, ref data, IntPtr.Zero, 0, out required, IntPtr.Zero);
                IntPtr detail = Marshal.AllocHGlobal(required);
                try
                {
                    Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                    if (!SetupDiGetDeviceInterfaceDetail(set, ref data, detail, required, out required, IntPtr.Zero))
                        throw new Exception("SetupDiGetDeviceInterfaceDetail failed: " + Marshal.GetLastWin32Error());

                    IntPtr pDevicePath = IntPtr.Add(detail, 4);
                    string path = Marshal.PtrToStringAuto(pDevicePath);
                    if (!string.IsNullOrEmpty(path))
                        result.Add(path);
                }
                finally
                {
                    Marshal.FreeHGlobal(detail);
                }
            }
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(set);
        }
        return result.ToArray();
    }
}
'@
