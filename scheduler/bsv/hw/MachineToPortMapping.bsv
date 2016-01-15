import SchedulerTypes::*;

function PortIndex machineToPortMapping (ServerIndex host_index, MAC mac_addr);
    PortIndex port_index = 0;

    if (host_index == 0)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 1)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 2)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 3)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 4)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 5)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 6)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    else if (host_index == 7)
    begin
        case (mac_addr)
			default : port_index = 0;
        endcase
    end

    return port_index;
endfunction
