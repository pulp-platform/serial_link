# change parameters ...

* change parameters in serial_link_pkg.sv
* change parameters in serial_link.hjson
* update regs with python script (pip virtual environment see below...):

- in ~/msc23f11: python3 -m venv .
- cd bin
- source activate.csh
- pip install hjson
- cd to serial_link
- pip3 install pyyaml
- pip install mako
- make update-regs

# modelsim search expressions

- expression_BUILDER_quicksaves.md

# my module versions

- /home/msc23f11/myModules/my_axi_test.sv
- /home/msc23f11/myModules/myAxiChanCompare.sv
- /home/msc23f11/myModules/myAssertions.svh

# other files

- /home/msc23f11/perfAnalysis7to16with0to16.csv