library verilog;
use verilog.vl_types.all;
entity \wordlib8__FTC\ is
    port(
        Cin             : in     vl_logic;
        I1              : in     vl_logic;
        I2              : in     vl_logic;
        I3              : in     vl_logic;
        I4              : in     vl_logic;
        C               : out    vl_logic;
        Cout            : out    vl_logic;
        S               : out    vl_logic;
        vdd             : in     vl_logic;
        gnd             : in     vl_logic
    );
end \wordlib8__FTC\;