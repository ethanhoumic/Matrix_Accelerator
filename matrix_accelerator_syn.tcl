sh mkdir -p Netlist
sh mkdir -p Report



read_verilog matrix_accelerator.v

set DESIGN "matrix_accelerator"
current_design [get_designs $DESIGN]

source matrix_accelerator_syn.sdc

#####################################################


#Compile and save files
#You may modified setting of compile 

compile
#####################################################
set bus_inference_style {%s[%d]}
set bus_naming_style    {%s[%d]}
set hdlout_internal_buses  true
change_names    -hierarchy  -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _}    -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]}  -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names    -hierarchy  -rules name_rule
set verilogout_no_tri   true

report_area         -hierarchy
report_timing       -delay min  -max_path 5
report_timing       -delay max  -max_path 5
report_area         -hierarchy              > ./Report/${DESIGN}_syn.area
report_timing       -delay min  -max_path 5 > ./Report/${DESIGN}_syn.timing_min
report_timing       -delay max  -max_path 5 > ./Report/${DESIGN}_syn.timing_max


set verilogout_higher_designs_first true
write   -f ddc      -hierarchy  -output ./Netlist/${DESIGN}_syn.ddc
write   -f verilog  -hierarchy  -output ./Netlist/${DESIGN}_syn.v
write_sdf   -version 2.1                ./Netlist/${DESIGN}_syn.sdf
write_sdc   -version 1.8                ./Netlist/${DESIGN}_syn.sdc


#####################################################








