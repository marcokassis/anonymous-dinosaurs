library verilog;
use verilog.vl_types.all;
entity \wordlib8__HalfAdder_MK\ is
    port(
        a               : in     vl_logic;
        b               : in     vl_logic;
        Cout            : out    vl_logic;
        s               : out    vl_logic;
        vdd             : in     vl_logic;
        gnd             : in     vl_logic
    );
end \wordlib8__HalfAdder_MK\;