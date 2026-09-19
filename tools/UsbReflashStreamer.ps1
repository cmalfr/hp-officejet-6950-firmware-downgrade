Add-Type @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class UsbReflashStreamer
{
    const uint GENERIC_READ  = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ  = 1;
    const uint FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_OVERLAPPED = 0x40000000;
    const int ERROR_IO_PENDING = 997;
    const uint WAIT_OBJECT_0 = 0;
    const uint WAIT_TIMEOUT = 258;

    [StructLayout(LayoutKind.Sequential)]
    struct OVERLAPPED
    {
        public IntPtr Internal;
        public IntPtr InternalHigh;
        public uint Offset;
        public uint OffsetHigh;
        public IntPtr hEvent;
    }

    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool WriteFile(SafeFileHandle hFile, byte[] buffer, int count, out int written, ref OVERLAPPED overlapped);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr CreateEvent(IntPtr attrs, bool manualReset, bool initialState, string name);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool GetOverlappedResult(SafeFileHandle hFile, ref OVERLAPPED ov, out uint bytes, bool wait);

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr hObject);

    static void WriteBlock(SafeFileHandle h, byte[] block, int timeoutMs, string label)
    {
        IntPtr evt = CreateEvent(IntPtr.Zero, true, false, null);
        if (evt == IntPtr.Zero) throw new Exception("CreateEvent failed");

        try
        {
            OVERLAPPED ov = new OVERLAPPED();
            ov.hEvent = evt;

            int written;
            bool ok = WriteFile(h, block, block.Length, out written, ref ov);
            if (ok)
            {
                Console.WriteLine(label + " -> COMPLETED: " + written + " bytes");
                return;
            }

            int err = Marshal.GetLastWin32Error();
            if (err != ERROR_IO_PENDING)
                throw new Exception(label + " WriteFile failed: " + err);

            Console.WriteLine(label + " -> IO_PENDING");
            uint wait = WaitForSingleObject(evt, (uint)timeoutMs);
            if (wait == WAIT_TIMEOUT)
                throw new Exception(label + " -> TIMEOUT");
            if (wait != WAIT_OBJECT_0)
                throw new Exception(label + " wait failed: " + wait);

            uint bytes;
            if (!GetOverlappedResult(h, ref ov, out bytes, false))
                throw new Exception(label + " GetOverlappedResult failed: " + Marshal.GetLastWin32Error());

            Console.WriteLine(label + " -> COMPLETED: " + bytes + " bytes");
        }
        finally
        {
            CloseHandle(evt);
        }
    }

    public static void Send(string device, string file, int timeoutMs)
    {
        if (!device.ToLowerInvariant().Contains("vid_03f0&pid_cafe"))
            throw new Exception("Target is not HP PID_CAFE.");

        byte[] payload = File.ReadAllBytes(file);
        Console.WriteLine("Payload: " + payload.Length + " bytes");

        using (SafeFileHandle h = CreateFile(device, GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING,
            FILE_FLAG_OVERLAPPED, IntPtr.Zero))
        {
            if (h.IsInvalid)
                throw new Exception("CreateFile: " + Marshal.GetLastWin32Error());

            const int CHUNK = 4096;
            int offset = 0;
            while (offset < payload.Length)
            {
                int count = Math.Min(CHUNK, payload.Length - offset);
                byte[] block = new byte[count];
                Buffer.BlockCopy(payload, offset, block, 0, count);
                Console.WriteLine("WRITE offset=0x" + offset.ToString("X6") + " length=" + count);
                WriteBlock(h, block, timeoutMs, "REFLASH");
                offset += count;
            }
        }

        Console.WriteLine("TRANSFER COMPLETE.");
    }
}
'@
