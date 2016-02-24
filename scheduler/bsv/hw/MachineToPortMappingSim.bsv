import SchedulerTypes::*;

function PortIndex machineToPortMapping (ServerIndex host_index, MAC mac_addr);
    PortIndex port_index = 0;

    if (host_index == 0)
    begin
        case (mac_addr)
        'h3417eb96df1e  : port_index = 0;
        'h3417eb96df1d  : port_index = 1;
        'h3417eb96df1c  : port_index = 2;
        endcase
    end

    else if (host_index == 1)
    begin
        case (mac_addr)
        'h3417eb96df1f  : port_index = 0;
        'h3417eb96df1d  : port_index = 1;
        'h3417eb96df1c  : port_index = 2;
        endcase
    end

    else if (host_index == 2)
    begin
        case (mac_addr)
        'h3417eb96df1f  : port_index = 0;
        'h3417eb96df1e  : port_index = 1;
        'h3417eb96df1c  : port_index = 2;
        endcase
    end

    else if (host_index == 3)
    begin
        case (mac_addr)
        'h3417eb96df1f  : port_index = 0;
        'h3417eb96df1e  : port_index = 1;
        'h3417eb96df1d  : port_index = 2;
        endcase
    end

    return port_index;
endfunction
