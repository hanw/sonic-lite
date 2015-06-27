## BlueNIC

### Platform
BlueNIC is targeted for multiple development platforms. Currently We have support for DE5-net and HTG4 board. We will support NetFPGA-SUME board soon.

### Support I/O operation
#### Kernel
ioread32, iowrite32

### Flash Programming
#### DE5
We can select flash image for programming during booting process. On DE5, the Image Select DIP switch (SW5) is provided to specify the image for configuration of the FPGA. Setting Position 2 of SW5 to low (right) specifies the default factory image to be loaded. Setting Position 2 of SW5 to high (left) specifies the DE5-Net to load a user-defined image.
