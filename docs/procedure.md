# Tested procedure

> **Danger:** firmware flashing can brick the printer. Do not interrupt power during EXTRACTING or REFLASHING.

## Tested hardware/result

- HP OfficeJet 6950
- source firmware: MJM2CN2626AR
- target firmware: MJM2CN2246AR / 2246A
- downgrade completed successfully
- third-party cartridges were accepted afterward

## 1. Obtain the target HP FUL

This repository does not contain HP firmware.

Use the `.ful` for your exact printer and target version.

## 2. Unpack the FUL

Use SiriusHacking `unpack-ful.py` in a clean work directory and set:

```python
skipFirstStage = False
```

Example:

```powershell
python .\unpack-ful.py .\muscatel_lite_mp1_MJM2CN2246AR_nbx_signed.ful
```

Keep the resulting `firstStage.bin`.

## 3. Prepare the three transport pieces

From this repository:

```powershell
python .\tools\prepare_firmware.py .\firstStage.bin --out .\prepared
```

Review the output. The tool refuses a payload-size mismatch.

## 4. Load the Windows USB helpers

If PowerShell script execution is restricted, load the files as text:

```powershell
Invoke-Expression (Get-Content .\tools\UsbPrintEnum.ps1 -Raw)
Invoke-Expression (Get-Content .\tools\UsbReflashStreamer.ps1 -Raw)
```

## 5. Boot the printer to REFLASH

Enter the printer's service/recovery REFLASH mode, then connect USB.

Enumerate:

```powershell
$raw = @(
    [UsbPrintEnum]::GetInterfaces() |
    Where-Object { $_ -match 'vid_03f0&pid_cafe' }
)

if ($raw.Count -ne 1) {
    throw "Expected one PID_CAFE interface, found $($raw.Count)"
}

$reflash = "\\?\" + ($raw[0] -replace '^[\\?]+','')
$reflash
```

Verify that the resulting device path begins with:

```text
\\?\usb#vid_03f0&pid_cafe#
```

## 6. Send stage1.srec

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\stage1.srec",
    10000
)
```

Expected display: TRANSFERRING.

## 7. Send f-command.bin

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\f-command.bin",
    10000
)
```

On the tested printer the display immediately changed to:

```text
STORING
```

Do not send the F command twice.

## 8. Send payload.bin

Only after STORING appears:

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\payload.bin",
    10000
)
```

Expected sequence:

```text
STORING
EXTRACTING
REFLASHING
automatic reboot
```

Do not disconnect power during these phases.

## 9. Verify firmware

After the automatic reboot, check the printer firmware version.

The tested downgrade ended on:

```text
MJM2CN2246AR
```

Third-party cartridges that had been rejected by 2626 were then accepted.

## Troubleshooting

### CreateFile error 123

Your Win32 device path is malformed.

Wrong:

```text
\?\usb...
```

Expected:

```text
\\?\usb...
```

### PID_CAFE disappears / VID_0000&PID_0002

Stop writing. Power-cycle/re-enter REFLASH and confirm the printer still boots normally before retrying.

### TRANSFER COMPLETE but the display does not change

A completed Windows `WriteFile` only confirms that the driver accepted the bytes. It does not prove the printer parsed them. Verify that you unpacked the FUL and that stage boundaries are correct.

### Printer remains configured after reboot

A firmware reflash does not necessarily erase NVRAM/user settings. Language/network settings may remain intact.
