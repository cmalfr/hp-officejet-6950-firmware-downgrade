# Protocol notes

These notes summarize observations from one successful HP OfficeJet 6950 downgrade session.

## Reflash USB identity

In REFLASH mode the tested printer exposed a USB printer interface containing:

```text
VID_03F0&PID_CAFE
```

## Unpacked first stage

The raw HP `.ful` should not be written directly. The first-stage transport is encoded in raster/PCL commands. SiriusHacking's `unpack-ful.py` reconstructs the logical stream.

The reconstructed stream begins with HP-specific `SA` records, then a standard-looking S-record header and data records.

Observed parser behavior from static analysis:

- searches for ASCII `S`
- decodes hexadecimal ASCII pairs into bytes
- supports S1/S2/S3 data records
- checks that the 8-bit sum including the checksum equals `0xFF`
- recognizes S7/S8/S9 termination records
- recognizes HP-specific `SA` and `SQ` records

## Tested stage boundary

For both MJM2CN2626AR and MJM2CN2246AR packages used during testing:

```text
S7: S705401D8954C0
```

The first byte after that terminating line was:

```text
F020FD172
```

The value after `F` exactly matched the remaining binary object length:

```text
0x020FD172 bytes
```

Sending the stage-1 S-record stream left the display on TRANSFERRING.

Sending only:

```text
F020FD172\n
```

immediately moved the printer to STORING.

Sending the announced payload produced:

```text
STORING -> EXTRACTING -> REFLASHING -> automatic reboot
```

## Important interpretation

The `Fxxxxxxxx` command is therefore treated as a size announcement for the object that follows. It must not be included again in the payload.

This is based on observed behavior, not official HP protocol documentation.
