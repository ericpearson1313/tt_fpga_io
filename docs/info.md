<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

A SPI slave interface connects a host CPU to a generated FABulous eFPGA. The SPI port is used for 
both bitstreamn loading of the efpga, and communcation with the user design within.

## How to test

make -B FST=

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
It needs an external SPI master (in my case a Pi5) and something to communcate with.
Initially I was planning on a basic Rs232 receiver funcitonallity inside the efpga
with host polling to read the data. I plan to run the TT chip emualted in an FPGA.
