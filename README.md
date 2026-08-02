ALL Digital Phase Locked Loop  
Team ID: elec_7

About the project:  
An All-Digital Phase-Locked Loop (ADPLL) is a clock generation and synchronization system that replaces the
analog components of a conventional Phase-Locked Loop (PLL) with digital circuitry. The primary purpose of an
ADPLL is to generate a stable, high-frequency clock that remains synchronized with a lower-frequency reference clock.
ADPLLs have become increasingly important in modern System-on-Chips (SoCs), communication systems, pro-
cessors, and high-speed interfaces because digital circuits scale efficiently with advancing semiconductor technologies.
Compared to traditional Analog PLLs, ADPLLs offer reduced silicon area, improved portability across process nodes,
enhanced immunity to process-voltage-temperature (PVT) variations, faster design portability, and easier integration
with digital design flows. They also enable advanced features such as programmability, adaptive bandwidth control,
self-calibration, and dynamic frequency scaling. However, ADPLLs face challenges including quantization noise, fi-
nite TDC resolution, digital jitter, and increased sensitivity to clock-domain timing issues. Despite these limitations,
their scalability, flexibility, lower power consumption, and compatibility with modern digital fabrication processes
have made ADPLLs the preferred choice for next-generation high-performance clock generation and synchronization
applications.

A little about this repo, This repo records the project status during mid evaluation and end evaluation. By end evaluation the
project has 2 version one for FPGA use and another which is the ideal model that could nit be FPGA implemented due to DCO. There is another 
folder that provides the files required in order to complete the bonus task of building a Clock Domain Crossing (CDC). For further information
refer the project report uploaded in this repo. All files can be run using this verilog command on icarus verilog- 
iverilog -g2012 -o full_soc_sim *.v; vvp full_soc_sim;

Design Specifications for ADPLL High Frequency:  
Reference frequency:        100 MHz  
DCO free running frequency: 3.5 GHz  
Target frequency Range:     3 GHz – 4 GHz

Design Specifications for ADPLL FPGA Oriented:  
Reference frequency:        2 MHz  
DCO free running frequency: 70 MHz  
Target frequency Range:     60MHz-80MHz
