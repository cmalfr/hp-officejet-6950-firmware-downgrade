# HP OfficeJet 6950 firmware downgrade

**Bring your HP OfficeJet 6950 back to life — downgrade its firmware and restore third-party ink cartridge support.**

> ⚠️ **Risk warning**
>
> This procedure writes printer firmware through HP's recovery/reflash USB interface. A power loss, wrong firmware image, wrong model, interrupted transfer, or incorrect offsets can brick the printer. Use it only if you understand the risk and have verified your exact model and firmware package.
>
> This repository **does not distribute HP firmware**. You must obtain the correct `.ful` package yourself.

## What was tested

Tested successfully on an **HP OfficeJet 6950**:

- starting firmware: **MJM2CN2626AR**
- target firmware: **MJM2CN2246AR / 2246A**
- result: printer rebooted normally on **2246**
- third-party ink cartridges that were rejected on 2626 were accepted again after the downgrade

The observed recovery sequence was:

```text
REFLASH
  -> TRANSFERRING
  -> STORING
  -> EXTRACTING
  -> REFLASHING
  -> automatic reboot
```

## What we learned

The HP reflash transport is not just "send the FUL file".

The `.ful` contains a first-stage raster/PCL encoded stream which must be unpacked. That unpacked stream contains:

1. HP-specific `SA` records
2. an `S0` header
3. Motorola-style `S1/S2/S3` data records
4. an `S7/S8/S9` termination record
5. an `Fxxxxxxxx\n` line announcing the exact size of the following binary object
6. the announced payload

For the firmware used during this investigation, the unpacked first stage had:

```text
S7 marker:  S705401D8954C0
F command:  F020FD172
payload:    0x020FD172 bytes
```

The printer moved from **TRANSFERRING** to **STORING** immediately after the `F020FD172\n` command was sent. Sending the announced payload then produced **EXTRACTING** followed by **REFLASHING** and a reboot.

## Repository layout

```text
tools/
  prepare_firmware.py          Split an unpacked firstStage.bin into stage1 / F / payload
  UsbPrintEnum.ps1             Enumerate the HP USB reflash interface on Windows
  UsbReflashStreamer.ps1       Stream a prepared file to the reflash interface

docs/
  protocol-notes.md            Reverse-engineering notes and observed protocol
  procedure.md                 Step-by-step tested downgrade procedure

vendor/
  README.md                    Notes about SiriusHacking dependency / upstream
```

## Requirements

- Windows
- Python 3
- PowerShell
- HP OfficeJet 6950
- printer booted into its **REFLASH** recovery mode
- a compatible HP `.ful` firmware package
- the [SiriusHacking](https://github.com/compukidmike/SiriusHacking) `unpack-ful.py` script or an equivalent unpacker

Python dependency used by the Sirius tool:

```powershell
python -m pip install hexdump
```

## Quick start

### 1. Unpack the HP FUL

Do **not** send the raw `.ful` directly.

Use SiriusHacking's `unpack-ful.py` with:

```python
skipFirstStage = False
```

Run it in a dedicated working directory so that its generated `firstStage.bin` does not overwrite another firmware's output.

Example:

```powershell
python .\unpack-ful.py .\muscatel_lite_mp1_MJM2CN2246AR_nbx_signed.ful
```

A valid unpacked stream should contain a termination record followed by an `F` command, e.g.:

```text
S705401D8954C0
F020FD172
P02184000
...
```

### 2. Split the unpacked stream

```powershell
python .\tools\prepare_firmware.py .\firstStage.bin --out .\prepared
```

This creates:

```text
prepared\stage1.srec
prepared\f-command.bin
prepared\payload.bin
```

The tool validates that the hexadecimal size announced by the `F` command matches the exact remaining payload length.

### 3. Enter printer REFLASH mode

Boot the printer into its service/recovery **REFLASH** mode.

Connect USB and load the helper classes:

```powershell
Invoke-Expression (Get-Content .\tools\UsbPrintEnum.ps1 -Raw)
Invoke-Expression (Get-Content .\tools\UsbReflashStreamer.ps1 -Raw)
```

Enumerate the reflash interface:

```powershell
$raw = @(
    [UsbPrintEnum]::GetInterfaces() |
    Where-Object { $_ -match 'vid_03f0&pid_cafe' }
)

if ($raw.Count -ne 1) {
    throw "Expected exactly one HP PID_CAFE interface, found $($raw.Count)"
}

$reflash = "\\?\" + ($raw[0] -replace '^[\\?]+','')
$reflash
```

The path must start with:

```text
\\?\usb#vid_03f0&pid_cafe#...
```

### 4. Send stage 1

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\stage1.srec",
    10000
)
```

The printer should enter or remain on **TRANSFERRING**.

### 5. Send the F command

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\f-command.bin",
    10000
)
```

On the tested printer this caused:

```text
TRANSFERRING -> STORING
```

### 6. Send the payload

Only after **STORING** appears:

```powershell
[UsbReflashStreamer]::Send(
    $reflash,
    ".\prepared\payload.bin",
    10000
)
```

Expected sequence:

```text
STORING -> EXTRACTING -> REFLASHING -> reboot
```

**Do not remove power during EXTRACTING or REFLASHING.**

### 7. Verify

After reboot, check the installed firmware version before doing anything else.

For the tested downgrade:

```text
MJM2CN2626AR -> MJM2CN2246AR
```

Third-party cartridges were then accepted again.

## Safety notes

- Verify the exact printer model.
- Verify the target firmware filename before unpacking.
- Never mix generated files from two different firmware packages.
- Never re-send stage 1 after the printer has advanced to STORING.
- Never re-send the F command after STORING begins.
- If a USB write fails, stop and inspect the current USB/PnP state before retrying.
- Do not interrupt EXTRACTING or REFLASHING.
- Disable automatic firmware updates afterward if you want to remain on the downgraded version.

## Firmware files

No HP firmware binaries are included in this repository.

That is deliberate: firmware is HP copyrighted material and redistributing it may not be permitted. This project documents the transport and provides tooling for firmware files that you already possess.

## Credits

The FUL unpacking work builds on **SiriusHacking** by compukidmike. This repository does not claim authorship of that project.

## Status

This method has been tested successfully on one HP OfficeJet 6950. More reports are welcome, especially with:

- other 6950 firmware versions
- neighboring OfficeJet models
- other downgrade targets
- Windows versions / USB controller differences

If you test it, please open an issue with the exact source firmware, target firmware, and observed display sequence.
