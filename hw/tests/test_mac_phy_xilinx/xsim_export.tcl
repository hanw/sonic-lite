
set partname {xc7vx690tffg1761-3}

create_project -in_memory -name fooproject
set_property PART $partname [current_project]

read_ip /home/hwang/dev/connectal/out/xsim/ten_gig_eth_mac_0/ten_gig_eth_mac_0.xci
generate_target simulation [get_ips ten_gig_eth_mac_0]

add_files [glob /home/hwang/dev/connectal/verilog/*.sv]
add_files [glob /home/hwang/dev/sonic-lite/hw/tests/test_mac_phy_xilinx/xsim/verilog/*.v]
add_files [glob /home/hwang/dev/connectal/verilog/*.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog.Vivado/*.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/FIFO1.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/FIFO2.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/ResetInverter.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/SyncResetA.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/SyncReset.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/ResetEither.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/SyncReset0.v]
add_files [glob /home/hwang/bluespec/2015.05.beta1/lib/Verilog/SyncFIFO.v]

add_files [get_files -compile_order sources -used_in simulation -of_objects [get_ips ten_gig_eth_mac_0]]
set_property TOP xsimtop [get_filesets sim_1]
export_simulation -simulator xsim -directory "."
