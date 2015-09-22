import ClientServer::*;
import GetPut::*;
import FIFO::*;


function Client#(req_type, resp_type) toClient(FIFO#(req_type) reqQ, FIFO#(resp_type) respQ);
   return (interface Client#(req_type, resp_type);
              interface Get request = toGet(reqQ);
              interface Put response = toPut(respQ);
           endinterface);
endfunction

function Server#(req_type, resp_type) toServer(FIFO#(req_type) reqQ, FIFO#(resp_type) respQ);
   return (interface Server#(req_type, resp_type);
              interface Put request = toPut(reqQ);
              interface Get response = toGet(respQ);
           endinterface);
endfunction

