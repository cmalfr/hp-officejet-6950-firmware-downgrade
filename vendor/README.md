# SiriusHacking dependency

The FUL unpacking step used during development came from the SiriusHacking project by compukidmike.

Upstream:
https://github.com/compukidmike/SiriusHacking

This repository intentionally does not copy the upstream project or HP firmware binaries. Obtain the upstream script directly and comply with its license.

The important configuration for this workflow is:

```python
skipFirstStage = False
```

Run it in a clean working directory because it writes files such as `firstStage.bin`.
