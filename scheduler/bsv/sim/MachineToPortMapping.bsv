import SchedulerTypes::*;

function PortIndex machineToPortMapping (Integer host_index, MAC mac_addr);
    PortIndex port_index = 0;

    if (host_index == 0)
    begin
        case (mac_addr)
        'hab4673df3647 : port_index = 0;
        'h2947baffe64c : port_index = 1;
        'h5bdc664dffee : port_index = 2;
        'h85774bbcfeaa : port_index = 3;
        endcase
    end

    else if (host_index == 1)
    begin
        case (mac_addr)
        'hffab4859fbc4 : port_index = 0;
        'h2947baffe64c : port_index = 1;
        'h5bdc664dffee : port_index = 2;
        'h85774bbcfeaa : port_index = 3;
        endcase
    end

    else if (host_index == 2)
    begin
        case (mac_addr)
        'hffab4859fbc4 : port_index = 0;
        'hab4673df3647 : port_index = 1;
        'h5bdc664dffee : port_index = 2;
        'h85774bbcfeaa : port_index = 3;
        endcase
    end

    else if (host_index == 3)
    begin
        case (mac_addr)
        'hffab4859fbc4 : port_index = 0;
        'hab4673df3647 : port_index = 1;
        'h2947baffe64c : port_index = 2;
        'h85774bbcfeaa : port_index = 3;
        endcase
    end

    else if (host_index == 4)
    begin
        case (mac_addr)
        'hffab4859fbc4 : port_index = 0;
        'hab4673df3647 : port_index = 1;
        'h2947baffe64c : port_index = 2;
        'h5bdc664dffee : port_index = 3;
        endcase
    end

    return port_index;
endfunction
