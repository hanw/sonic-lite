/* Implementation of Jenkin's Hash Function */

import MatchTableTypes::*;

function AddrIndex hash_function(Key key);
    Integer key_len_in_bytes = fromInteger(valueof(KEY_LEN))/8;
    Bit#(8) key_in_bytes[key_len_in_bytes];
    for (Integer i = 0; i < key_len_in_bytes; i = i + 1)
    begin
        Integer j = i * 8;
        key_in_bytes[i] = key[(j+7):j];
    end
    Bit#(32) hash = 0;
    for (Integer i = 0; i < key_len_in_bytes; i = i + 1)
    begin
        hash = hash + zeroExtend(key_in_bytes[i]);
        hash = hash + (hash << 10);
        hash = hash ^ (hash >> 6);
    end
    hash = hash + (hash << 3);
    hash = hash ^ (hash >> 11);
    hash = hash + (hash << 15);
    
    hash = hash % fromInteger(valueof(TABLE_LEN));
    AddrIndex index = truncate(hash);
    return index;
endfunction
