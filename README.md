# CODS

A D library to manage shared object with weak consistency criteria

## Requirements

DMD v2.066 or above

## Building

 * Clone the repository : 

	`git clone https://github.com/damien-maussion/CODS`

 * Compile orange : 

	`cd CODS/orange/`
	
	`make`

 * compile cods (no makefile yet) :

	`cd ../cods/test`

	`dmd ../../orange/lib/32/liborange.a -I../../orange/import/ -I.. ../cods/*/*.d main.d -oftest`

  or 

	`dmd ../../orange/lib/64/liborange.a -I../../orange/import/ -I.. ../cods/*/*.d main.d -oftest`
