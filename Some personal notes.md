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