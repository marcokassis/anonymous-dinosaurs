//---------------------
// states and instructions


  typedef enum logic [3:0] {FETCH1 = 4'b0000, FETCH2, FETCH3, FETCH4,
                            DECODE, MEMADR, LBRD, LBWR, SBWR,
                            RTYPEEX, RTYPEWR, BEQEX, JEX} statetype;
  typedef enum logic [5:0] {LB    = 6'b100000,
                            SB    = 6'b101000,
                            RTYPE = 6'b000000,
                            MTYPE = 6'b011000,
                            BEQ   = 6'b000100,
                            J     = 6'b000010} opcode;
  typedef enum logic [5:0] {ADD = 6'b100000,
                            SUB = 6'b100010,
                            AND = 6'b100100,
                            OR  = 6'b100101,
                            SLT = 6'b101010} functcode;

// testbench for testing
module NegNegLH #(parameter WIDTH = 8, REGBITS = 3)();

  logic             clk;
  logic             reset;
  logic             memread, memwrite;
  logic [WIDTH-1:0] adr, writedata;
  logic [WIDTH-1:0] memdata;

  // instantiate devices to be tested
  mips #(WIDTH,REGBITS) dut(clk, reset, memdata, memread, 
                            memwrite, adr, writedata);

  // external memory for code and data
  exmemory #(WIDTH) exmem(clk, memwrite, adr, writedata, memdata);

  // initialize test
  initial
    begin
      reset <= 1; # 22; reset <= 0;
    end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  always@(negedge clk)
    begin
      if(memwrite) begin
        // assert(adr == 76 & writedata == 60) // for multPosPosLH
        //  assert(adr == 76 & writedata == -112) // for multPosPosUH
        
        // if(adr == 76 & writedata == 8'b10010000)
        // if(adr == 76 & writedata == 8'b01000000)
        // if(adr == 76 & writedata == 8'b00000000)
         if(adr == 76 & writedata == 64)    
          $display("Simulation completely successful");
        else $error("Simulation failed");
          
        $stop;
        
      end
    end
endmodule


// external memory accessed by MIPS
module exmemory #(parameter WIDTH = 8)
                 (input  logic             clk,
                  input  logic             memwrite,
                  input  logic [WIDTH-1:0] adr, writedata,
                  output logic [WIDTH-1:0] memdata);

  logic [31:0]      mem [2**(WIDTH-2)-1:0];
  logic [31:0]      word;
  logic [1:0]       bytesel;
  logic [WIDTH-2:0] wordadr;

  initial
    // $readmemh("multPosPosUH.dat", mem);
    // $readmemh("multNegNegUH.dat", mem);
    // $readmemh("multPosZeroUH.dat", mem);
   $readmemh("./testcases/NegNegLH/NegNegLH.dat", mem);

  assign bytesel = adr[1:0];
  assign wordadr = adr[WIDTH-1:2];

  // read and write bytes from 32-bit word
  always @(posedge clk)
    if(memwrite) 
      case (bytesel)
        2'b00: mem[wordadr][7:0]   <= writedata;
        2'b01: mem[wordadr][15:8]  <= writedata;
        2'b10: mem[wordadr][23:16] <= writedata;
        2'b11: mem[wordadr][31:24] <= writedata;
      endcase

   assign word = mem[wordadr];
   always_comb
     case (bytesel)
       2'b00: memdata = word[7:0];
       2'b01: memdata = word[15:8];
       2'b10: memdata = word[23:16];
       2'b11: memdata = word[31:24];
     endcase
endmodule


// MODULE MIPS
// simplified MIPS processor
module mips #(parameter WIDTH = 8, REGBITS = 3)
             (input  logic             clk, reset, 
              input  logic [WIDTH-1:0] memdata, 
              output logic             memread, memwrite, 
              output logic [WIDTH-1:0] adr, writedata);

   logic [31:0] instr;
   logic        zero, alusrca, memtoreg, iord, pcen, regwrite, regdst;
   logic        muldst, lb, mulop;  // our extra signals 
   logic [1:0]  pcsrc, alusrcb;
   logic [3:0]  irwrite;
   logic [2:0]  alucontrol;
   opcode       op;
   functcode    funct;
   

   controller_plabased  cont(clk, reset, op, funct, zero, muldst, lb, mulop,
			     memread, memwrite, alusrca, memtoreg, 
                             iord, pcen, regwrite, regdst,
                             pcsrc, alusrcb, alucontrol, irwrite);

   datapath    #(WIDTH, REGBITS) 
               dp(clk, reset, memdata, alusrca, memtoreg, iord, muldst, lb, mulop, pcen,
                  regwrite, regdst, pcsrc, alusrcb, irwrite, alucontrol,
                  zero, op, funct, adr, writedata);
endmodule



// The format that will be given as input to the 
// PLA generator
module controller_plabased(input logic clk, reset, 
                  input  opcode      op,
                  input  functcode   funct,
                  input  logic       zero, 
                  output logic       muldst, lb, mulop,  
                  output logic       memread, memwrite, alusrca,  
                  output logic       memtoreg, iord, pcen, 
                  output logic       regwrite, regdst, 
                  output logic [1:0] pcsrc, alusrcb,
                  output logic [2:0] alucontrol,
                  output logic [3:0] irwrite);

  logic            pcwrite, branch;
  logic     [1:0]  aluop;
  logic     [9:0]  in;
  logic     [25:0] out;
  logic     [3:0]  state;
  logic     [3:0]  nextstate;
  
  always_ff @(posedge clk)
     if(reset) state <= 4'b0000;
     else      state <= nextstate;
  
  assign in = {op,state};
  assign {aluop, branch, pcwrite, irwrite, alusrcb, pcsrc, regdst, regwrite, 
          iord, memtoreg, alusrca, memwrite, memread, nextstate, muldst, lb, mulop} = out;

  aludec  ac(aluop, funct, alucontrol);
  assign pcen = pcwrite | (branch & zero); // program counter enable


  always_comb 
    casez(in)
      10'b??????0000: out <= 26'b00010001010000000010001000;
      10'b??????0001: out <= 26'b00010010010000000010010000;
      10'b??????0010: out <= 26'b00010100010000000010011000;
      10'b??????0011: out <= 26'b00011000010000000010100000;
      10'b1000000100: out <= 26'b00000000110000000000101000;
      10'b1010000100: out <= 26'b00000000110000000000101000;
      10'b0000000100: out <= 26'b00000000110000000001001000;
      10'b0001000100: out <= 26'b00000000110000000001011000;
      10'b0000100100: out <= 26'b00000000110000000001100000; 
      10'b0110000100: out <= 26'b00000000110000000001101000; 
      10'b??????1101: out <= 26'b10000000000000001001110011;
      10'b??????1110: out <= 26'b00000000000011000001111001;
      10'b??????1111: out <= 26'b00000000000011000000000111;
      10'b1000000101: out <= 26'b00000000100000001000110000;  
      10'b1010000101: out <= 26'b00000000100000001001000000;
      10'b??????0110: out <= 26'b00000000000000100010111000;
      10'b??????0111: out <= 26'b00000000000001010000000000;
      10'b??????1000: out <= 26'b00000000000000100100000000;
      10'b??????1001: out <= 26'b10000000000000001001010000;
      10'b??????1010: out <= 26'b00000000000011000000000000; 
      10'b??????1011: out <= 26'b01100000000100001000000000;
      10'b??????1100: out <= 26'b00010000001000000000000000;
      default:        out <= 26'bxxxxxxxxxxxxxxxxxxxxxxxxxx;
    endcase                                          
                               
endmodule




// Are we going to use alu??
module aludec(input  logic [1:0] aluop, 
              input  logic [5:0] funct, 
              output logic [2:0] alucontrol);

  always_comb
    case (aluop)
      2'b00: alucontrol = 3'b010;  // add for lb/sb/addi
      2'b01: alucontrol = 3'b110;  // subtract (for beq)
      default: case(funct)      // R-Type instructions
                 ADD: alucontrol = 3'b010;
                 SUB: alucontrol = 3'b110;
                 AND: alucontrol = 3'b000;
                 OR:  alucontrol = 3'b001;
                 SLT: alucontrol = 3'b111;
                 default:   alucontrol = 3'b101; // should never happen
               endcase
    endcase
endmodule


// datapath
module datapath #(parameter WIDTH = 8, REGBITS = 3)
                 (input  logic             clk, reset, 
                  input  logic [WIDTH-1:0] memdata, 
                  input  logic             alusrca, memtoreg, iord, 
                  input  logic             muldst, lb, mulop, 
                  input  logic             pcen, regwrite, regdst,
                  input  logic [1:0]       pcsrc, alusrcb, 
                  input  logic [3:0]       irwrite, 
                  input  logic [2:0]       alucontrol, 
                  output logic             zero,
                  output opcode            op,
                  output functcode         funct,
                  output logic [WIDTH-1:0] adr, writedata);

  logic [REGBITS-1:0] ra1, ra2, wa;
  logic [WIDTH-1:0]   pc, nextpc, data, rd1, rd2, wd, a, srca, 
                      srcb, aluresult, aluout, immx4;
  logic [31:0]        instr;

  logic [WIDTH-1:0] CONST_ZERO = 0;
  logic [WIDTH-1:0] CONST_ONE =  1;
  
  assign op = opcode'(instr[31:26]);
  assign funct = functcode'(instr[5:0]);

  // shift left immediate field by 2
  assign immx4 = {instr[WIDTH-3:0],2'b00};

  // register file address fields
  assign ra1 = instr[REGBITS+20:21];
  assign ra2 = instr[REGBITS+15:16];

  // @louis ++ jf: this is kind of magic
  logic [REGBITS-1:0] regmuxout;
  logic [REGBITS-1:0] rdlb;
  assign rdlb =  {instr[REGBITS+10:12],1'b1}; 


  mux2       #(REGBITS) regmux(instr[REGBITS+15:16], 
                               instr[REGBITS+10:11], regdst, regmuxout);
  mux2       #(REGBITS)  muldstmux(regmuxout, rdlb, muldst, wa);




   // independent of bit width, load instruction into four 8-bit registers over four cycles
  flopen     #(8)      ir0(clk, irwrite[0], memdata[7:0], instr[7:0]);
  flopen     #(8)      ir1(clk, irwrite[1], memdata[7:0], instr[15:8]);
  flopen     #(8)      ir2(clk, irwrite[2], memdata[7:0], instr[23:16]);
  flopen     #(8)      ir3(clk, irwrite[3], memdata[7:0], instr[31:24]);


  // datapath
  flopenr    #(WIDTH)  pcreg(clk, reset, pcen, nextpc, pc);
  flop       #(WIDTH)  datareg(clk, memdata, data);
  flop       #(WIDTH)  areg(clk, rd1, a);
  flop       #(WIDTH)  wrdreg(clk, rd2, writedata);
  mux2       #(WIDTH)  adrmux(pc, aluout, iord, adr);
  mux2       #(WIDTH)  src1mux(pc, a, alusrca, srca);
  mux4       #(WIDTH)  src2mux(writedata, CONST_ONE, instr[WIDTH-1:0], 
                               immx4, alusrcb, srcb);
  mux3       #(WIDTH)  pcmux(aluresult, aluout, immx4, 
                             pcsrc, nextpc);
  mux2       #(WIDTH)  wdmux(aluout, data, memtoreg, wd);
  regfile    #(WIDTH,REGBITS) rf(clk, regwrite, ra1, ra2, 
                                 wa, wd, rd1, rd2);
  alu        #(WIDTH) alunit(srca, srcb, alucontrol, aluresult, zero);


  // multiplier & its magic

  logic [2*WIDTH -1:0] multresult;
  logic [WIDTH -1:0] upperhalf;
  logic [WIDTH -1:0] lowerhalf;
  logic [WIDTH -1:0] mulopmuxout;
  logic [WIDTH -1:0] resregUHout; // result FF - UpperHalf
  logic [WIDTH -1:0] resregLHout; // result FF - LowerHalf


  BoothMultiplier multunin(srca[0], srca[1], srca[2], srca[3], srca[4], srca[5], srca[6], srca[7], 
			   srcb[0], srcb[1], srcb[2], srcb[3], srcb[4], srcb[5], srcb[6], srcb[7], 
			   multresult[0],multresult[1],multresult[10],multresult[11],multresult[12],
			   multresult[13],multresult[14],multresult[15],multresult[2],multresult[3],
			   multresult[4],multresult[5],multresult[6],multresult[7],
			   multresult[8],multresult[9]);


  assign upperhalf = multresult[2*WIDTH-1:WIDTH];
  assign lowerhalf = multresult[WIDTH-1:0];

  mux2       #(WIDTH)  mulopmux(aluresult, upperhalf, mulop, mulopmuxout);
  flop       #(WIDTH)  resregUH(clk, mulopmuxout, resregUHout);

  // store the lower half for one cycle
  flopen     #(WIDTH)  resregLH(clk, lb, lowerhalf, resregLHout);
  mux2       #(WIDTH)  lbmux(resregUHout, resregLHout, muldst, aluout);

endmodule



module alu #(parameter WIDTH = 8)
            (input  logic [WIDTH-1:0] a, b, 
             input  logic [2:0]       alucontrol, 
             output logic [WIDTH-1:0] result,
             output logic             zero);

  logic [WIDTH-1:0] b2, andresult, orresult, sumresult, sltresult;

  andN    andblock(a, b, andresult);
  orN     orblock(a, b, orresult);
  condinv binv(b, alucontrol[2], b2);
  adder   addblock(a, b2, alucontrol[2], sumresult);
  // slt should be 1 if most significant bit of sum is 1
  assign sltresult = sumresult[WIDTH-1];

  mux4 resultmux(andresult, orresult, sumresult, sltresult, alucontrol[1:0], result);
  zerodetect #(WIDTH) zd(result, zero);
endmodule

module regfile #(parameter WIDTH = 8, REGBITS = 3)
                (input  logic               clk, 
                 input  logic               regwrite, 
                 input  logic [REGBITS-1:0] ra1, ra2, wa, 
                 input  logic [WIDTH-1:0]   wd, 
                 output logic [WIDTH-1:0]   rd1, rd2);

   logic [WIDTH-1:0] RAM [2**REGBITS-1:0];

  // three ported register file
  // read two ports combinationally
  // write third port on rising edge of clock
  // register 0 hardwired to 0
  always @(posedge clk)
    if (regwrite) RAM[wa] <= wd;

  assign rd1 = ra1 ? RAM[ra1] : 0;
  assign rd2 = ra2 ? RAM[ra2] : 0;
endmodule

module zerodetect #(parameter WIDTH = 8)
                   (input  logic [WIDTH-1:0] a, 
                    output logic             y);

   assign y = (a==0);
endmodule	

module flop #(parameter WIDTH = 8)
             (input  logic             clk, 
              input  logic [WIDTH-1:0] d, 
              output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    q <= d;
endmodule

module flopen #(parameter WIDTH = 8)
               (input  logic             clk, en,
                input  logic [WIDTH-1:0] d, 
                output logic [WIDTH-1:0] q);

  always_ff @(posedge clk)
    if (en) q <= d;
endmodule

module flopenr #(parameter WIDTH = 8)
                (input  logic             clk, reset, en,
                 input  logic [WIDTH-1:0] d, 
                 output logic [WIDTH-1:0] q);
 
  always_ff @(posedge clk)
    if      (reset) q <= 0;
    else if (en)    q <= d;
endmodule

module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, 
              input  logic             s, 
              output logic [WIDTH-1:0] y);

  assign y = s ? d1 : d0; 
endmodule

module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  always_comb 
    casez (s)
      2'b00: y = d0;
      2'b01: y = d1;
      2'b1?: y = d2;
    endcase
endmodule

module mux4 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2, d3,
              input  logic [1:0]       s, 
              output logic [WIDTH-1:0] y);

  always_comb
    case (s)
      2'b00: y = d0;
      2'b01: y = d1;
      2'b10: y = d2;
      2'b11: y = d3;
    endcase
endmodule

module andN #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] a, b,
              output logic [WIDTH-1:0] y);

  assign y = a & b;
endmodule

module orN #(parameter WIDTH = 8)
            (input  logic [WIDTH-1:0] a, b,
             output logic [WIDTH-1:0] y);

  assign y = a | b;
endmodule

module inv #(parameter WIDTH = 8)
            (input  logic [WIDTH-1:0] a,
             output logic [WIDTH-1:0] y);

  assign y = ~a;
endmodule

module condinv #(parameter WIDTH = 8)
                (input  logic [WIDTH-1:0] a,
                 input  logic             invert,
                 output logic [WIDTH-1:0] y);

  logic [WIDTH-1:0] ab;

  inv  inverter(a, ab);
  mux2 invmux(a, ab, invert, y);
endmodule

module adder #(parameter WIDTH = 8)
              (input  logic [WIDTH-1:0] a, b,
               input  logic             cin,
               output logic [WIDTH-1:0] y);

  assign y = a + b + cin;
endmodule







/* Verilog for cell 'BoothMultiplier{lay}' from library 'mips8' */
/* Created on Sun Nov 17, 2013 20:57:19 */
/* Last revised on Tue Nov 19, 2013 22:06:45 */
/* Written on Wed Nov 20, 2013 00:28:28 by Electric VLSI Design System, version 8.06 */

module muddlib07__and2_1x(a, b, y, vdd, gnd);
  input a;
  input b;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_72, net_73, plno_2_well, plnode_0_well;

  tranif1 nmos_0(gnd, net_72, a);
  tranif1 nmos_1(net_72, net_73, b);
  tranif1 nmos_2(y, gnd, net_73);
  tranif0 pmos_0(vdd, net_73, a);
  tranif0 pmos_1(net_73, vdd, b);
  tranif0 pmos_2(y, vdd, net_73);
endmodule   /* muddlib07__and2_1x */

module muddlib07__xor2_1x(a, b, y, vdd, gnd);
  input a;
  input b;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_158, net_68, net_70, net_76, net_79, net_87, plno_2_well;
  wire plnode_0_well;

  tranif1 nmos_0(gnd, net_79, a);
  tranif1 nmos_1(y, net_76, net_158);
  tranif1 nmos_2(net_76, gnd, net_87);
  tranif1 nmos_3(net_79, y, b);
  tranif1 nmos_4(gnd, net_158, b);
  tranif1 nmos_5(net_87, gnd, a);
  tranif0 pmos_0(vdd, net_68, net_87);
  tranif0 pmos_1(net_68, y, b);
  tranif0 pmos_2(y, net_70, net_158);
  tranif0 pmos_4(net_70, vdd, a);
  tranif0 pmos_5(net_87, vdd, a);
  tranif0 pmos_6(vdd, net_158, b);
endmodule   /* muddlib07__xor2_1x */

module wordlib8__HalfAdder_LC(a, b, Cout, s, vdd, gnd);
  input a;
  input b;
  output Cout;
  output s;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  muddlib07__and2_1x and2_1x_1(.a(a), .b(b), .y(Cout), .vdd(vdd), .gnd(gnd));
  muddlib07__xor2_1x xor2_1x_2(.a(a), .b(b), .y(s), .vdd(vdd), .gnd(gnd));
endmodule   /* wordlib8__HalfAdder_LC */

module muddlib07__fulladder_LC(a, b, c, cout, s, vdd, gnd);
  input a;
  input b;
  input c;
  output cout;
  output s;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire coutb, net_10, net_11, net_122, net_123, net_124, net_13, net_134;
  wire net_135, net_27, net_30, plnode_0_well, plnode_1_well, plnode_2_well;
  wire plnode_3_well, sumb;

  tranif1 nmos_0(gnd, cout, coutb);
  tranif1 nmos_1(gnd, s, sumb);
  tranif1 nmos_2(net_124, gnd, a);
  tranif1 nmos_3(net_122, net_124, b);
  tranif1 nmos_4(sumb, net_122, c);
  tranif1 nmos_5(net_123, sumb, coutb);
  tranif1 nmos_6(gnd, net_123, c);
  tranif1 nmos_7(net_123, gnd, b);
  tranif1 nmos_8(gnd, net_123, a);
  tranif1 nmos_9(net_134, gnd, a);
  tranif1 nmos_10(coutb, net_134, b);
  tranif1 nmos_11(net_135, coutb, c);
  tranif1 nmos_12(gnd, net_135, b);
  tranif1 nmos_13(net_135, gnd, a);
  tranif0 pmos_0(vdd, cout, coutb);
  tranif0 pmos_1(vdd, s, sumb);
  tranif0 pmos_2(net_10, vdd, a);
  tranif0 pmos_3(net_11, net_10, b);
  tranif0 pmos_4(sumb, net_11, c);
  tranif0 pmos_5(net_27, sumb, coutb);
  tranif0 pmos_6(vdd, net_27, c);
  tranif0 pmos_7(net_27, vdd, b);
  tranif0 pmos_8(vdd, net_27, a);
  tranif0 pmos_9(net_13, vdd, a);
  tranif0 pmos_10(coutb, net_13, b);
  tranif0 pmos_11(net_30, coutb, c);
  tranif0 pmos_12(vdd, net_30, b);
  tranif0 pmos_13(net_30, vdd, a);
endmodule   /* muddlib07__fulladder_LC */

module wordlib8__CPA(a0, a1, a10, a11, a12, a13, a2, a3, a4, a5, a6, a7, a8, 
      a9, b0, b1, b10, b11, b12, b13, b2, b3, b4, b5, b6, b7, b8, b9, cout, s0, 
      s1, s10, s11, s12, s13, s2, s3, s4, s5, s6, s7, s8, s9, vdd, vdd_1, 
      vdd_10, vdd_11, vdd_12, vdd_1_1, vdd_2, vdd_3, vdd_4, vdd_5, vdd_6, 
      vdd_7, vdd_8, vdd_9, gnd, gnd_1, gnd_10, gnd_11, gnd_12, gnd_1_1, gnd_2, 
      gnd_3, gnd_4, gnd_5, gnd_6, gnd_7, gnd_8, gnd_9);
  input a0;
  input a1;
  input a10;
  input a11;
  input a12;
  input a13;
  input a2;
  input a3;
  input a4;
  input a5;
  input a6;
  input a7;
  input a8;
  input a9;
  input b0;
  input b1;
  input b10;
  input b11;
  input b12;
  input b13;
  input b2;
  input b3;
  input b4;
  input b5;
  input b6;
  input b7;
  input b8;
  input b9;
  output cout;
  output s0;
  output s1;
  output s10;
  output s11;
  output s12;
  output s13;
  output s2;
  output s3;
  output s4;
  output s5;
  output s6;
  output s7;
  output s8;
  output s9;
  input vdd;
  input vdd_1;
  input vdd_10;
  input vdd_11;
  input vdd_12;
  input vdd_1_1;
  input vdd_2;
  input vdd_3;
  input vdd_4;
  input vdd_5;
  input vdd_6;
  input vdd_7;
  input vdd_8;
  input vdd_9;
  input gnd;
  input gnd_1;
  input gnd_10;
  input gnd_11;
  input gnd_12;
  input gnd_1_1;
  input gnd_2;
  input gnd_3;
  input gnd_4;
  input gnd_5;
  input gnd_6;
  input gnd_7;
  input gnd_8;
  input gnd_9;

  supply1 vdd;
  supply0 gnd;
  wire net_182, net_184, net_187, net_190, net_193, net_197, net_200, net_203;
  wire net_206, net_209, net_212, net_215, net_218;

  wordlib8__HalfAdder_LC HalfAdde_1(.a(a0), .b(b0), .Cout(net_182), .s(s0), 
      .vdd(vdd), .gnd(gnd));
  muddlib07__fulladder_LC fulladde_13(.a(a1), .b(b1), .c(net_182), 
      .cout(net_184), .s(s1), .vdd(vdd_1_1), .gnd(gnd_1_1));
  muddlib07__fulladder_LC fulladde_14(.a(a2), .b(b2), .c(net_184), 
      .cout(net_187), .s(s2), .vdd(vdd_2), .gnd(gnd_2));
  muddlib07__fulladder_LC fulladde_15(.a(a3), .b(b3), .c(net_187), 
      .cout(net_190), .s(s3), .vdd(vdd_3), .gnd(gnd_3));
  muddlib07__fulladder_LC fulladde_16(.a(a4), .b(b4), .c(net_190), 
      .cout(net_193), .s(s4), .vdd(vdd_4), .gnd(gnd_4));
  muddlib07__fulladder_LC fulladde_17(.a(a5), .b(b5), .c(net_193), 
      .cout(net_197), .s(s5), .vdd(vdd_5), .gnd(gnd_5));
  muddlib07__fulladder_LC fulladde_18(.a(a6), .b(b6), .c(net_197), 
      .cout(net_200), .s(s6), .vdd(vdd_6), .gnd(gnd_6));
  muddlib07__fulladder_LC fulladde_19(.a(a7), .b(b7), .c(net_200), 
      .cout(net_203), .s(s7), .vdd(vdd_7), .gnd(gnd_7));
  muddlib07__fulladder_LC fulladde_20(.a(a8), .b(b8), .c(net_203), 
      .cout(net_206), .s(s8), .vdd(vdd_8), .gnd(gnd_8));
  muddlib07__fulladder_LC fulladde_21(.a(a9), .b(b9), .c(net_206), 
      .cout(net_209), .s(s9), .vdd(vdd_9), .gnd(gnd_9));
  muddlib07__fulladder_LC fulladde_22(.a(a10), .b(b10), .c(net_209), 
      .cout(net_212), .s(s10), .vdd(vdd_10), .gnd(gnd_10));
  muddlib07__fulladder_LC fulladde_23(.a(a11), .b(b11), .c(net_212), 
      .cout(net_215), .s(s11), .vdd(vdd_11), .gnd(gnd_11));
  muddlib07__fulladder_LC fulladde_24(.a(a12), .b(b12), .c(net_215), 
      .cout(net_218), .s(s12), .vdd(vdd_12), .gnd(gnd_12));
  muddlib07__fulladder_LC fulladde_25(.a(a13), .b(b13), .c(net_218), 
      .cout(cout), .s(s13), .vdd(vdd_1), .gnd(gnd_1));
endmodule   /* wordlib8__CPA */

module wordlib8__HalfAdder_MK(a, b, Cout, s, vdd, gnd);
  input a;
  input b;
  output Cout;
  output s;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  muddlib07__and2_1x and2_1x_0(.a(a), .b(b), .y(Cout), .vdd(vdd), .gnd(gnd));
  muddlib07__xor2_1x xor2_1x_1(.a(a), .b(b), .y(s), .vdd(vdd), .gnd(gnd));
endmodule   /* wordlib8__HalfAdder_MK */

module muddlib07__inv_1x(a, y, vdd, gnd);
  input a;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire plnode_0_well, plnode_1_well;

  tranif1 nmos_0(gnd, y, a);
  tranif0 pmos_0(vdd, y, a);
endmodule   /* muddlib07__inv_1x */

module muddlib07__nor2_1x(a, b, y, vdd, gnd);
  input a;
  input b;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_55, plno_2_well, plnode_0_well;

  tranif1 nmos_0(gnd, y, a);
  tranif1 nmos_1(y, gnd, b);
  tranif0 pmos_0(vdd, net_55, a);
  tranif0 pmos_1(net_55, y, b);
endmodule   /* muddlib07__nor2_1x */

module muddlib07__or4_1x(a, b, c, d, y, vdd, gnd);
  input a;
  input b;
  input c;
  input d;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_133, net_134, net_135, net_136, plnode_4_well, plnode_5_well;

  tranif1 nmos_9(gnd, y, net_136);
  tranif1 nmos_10(gnd, net_136, a);
  tranif1 nmos_11(net_136, gnd, b);
  tranif1 nmos_12(gnd, net_136, c);
  tranif1 nmos_13(net_136, gnd, d);
  tranif0 pmos_5(vdd, net_133, a);
  tranif0 pmos_6(net_133, net_134, b);
  tranif0 pmos_7(net_134, net_135, c);
  tranif0 pmos_8(net_135, net_136, d);
  tranif0 pmos_9(vdd, y, net_136);
endmodule   /* muddlib07__or4_1x */

module wordlib8__NAND8_reducer(inY, inY_1, inY_2, inY_3, inY_4, inY_5, inY_6, 
      inY_7, reduced_AND, vdd, gnd);
  input [0:0] inY;
  input [1:1] inY_1;
  input [2:2] inY_2;
  input [3:3] inY_3;
  input [4:4] inY_4;
  input [5:5] inY_5;
  input [6:6] inY_6;
  input [7:7] inY_7;
  output reduced_AND;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_25, net_29, net_6, plnode_0_select;

  muddlib07__inv_1x inv_1x_1(.a(inY_7[7]), .y(net_6), .vdd(vdd), .gnd(gnd));
  muddlib07__nor2_1x nor2_1x_0(.a(net_25), .b(net_29), .y(reduced_AND), 
      .vdd(vdd), .gnd(gnd));
  muddlib07__or4_1x or4_1x_2(.a(inY_3[3]), .b(inY_2[2]), .c(inY_1[1]), 
      .d(inY[0]), .y(net_29), .vdd(vdd), .gnd(gnd));
  muddlib07__or4_1x or4_1x_3(.a(net_6), .b(inY_6[6]), .c(inY_5[5]), 
      .d(inY_4[4]), .y(net_25), .vdd(vdd), .gnd(gnd));
endmodule   /* wordlib8__NAND8_reducer */

module muddlib07__a22o2_1x(a, b, c, d, y, vdd, gnd);
  input a;
  input b;
  input c;
  input d;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_61, net_62, net_66, net_72, plno_2_well, plnode_0_well;

  tranif1 nmos_0(gnd, net_61, a);
  tranif1 nmos_1(net_61, net_62, b);
  tranif1 nmos_2(net_62, net_66, d);
  tranif1 nmos_3(net_66, gnd, c);
  tranif1 nmos_4(gnd, y, net_62);
  tranif0 pmos_0(net_72, vdd, a);
  tranif0 pmos_1(vdd, net_72, b);
  tranif0 pmos_4(net_72, net_62, d);
  tranif0 pmos_5(net_62, net_72, c);
  tranif0 pmos_6(vdd, y, net_62);
endmodule   /* muddlib07__a22o2_1x */

module wordlib8__PPGen_1bit(Double, Negate, Single, Yi, Yi_m1, PPi, vdd, gnd);
  input Double;
  input Negate;
  input Single;
  input Yi;
  input Yi_m1;
  output PPi;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_4;

  muddlib07__a22o2_1x a22o2_1x_0(.a(Single), .b(Yi), .c(Double), .d(Yi_m1), 
      .y(net_4), .vdd(vdd), .gnd(gnd));
  muddlib07__xor2_1x xor2_1x_0(.a(net_4), .b(Negate), .y(PPi), .vdd(vdd), 
      .gnd(gnd));
endmodule   /* wordlib8__PPGen_1bit */

module muddlib07__nand3_1x(a, b, c, y, vdd, gnd);
  input a;
  input b;
  input c;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_177, net_178, plno_2_well, plnode_0_well;

  tranif1 nmos_6(gnd, net_177, a);
  tranif1 nmos_7(net_177, net_178, b);
  tranif1 nmos_8(net_178, y, c);
  tranif0 pmos_6(vdd, y, c);
  tranif0 pmos_7(y, vdd, b);
  tranif0 pmos_8(vdd, y, a);
endmodule   /* muddlib07__nand3_1x */

module wordlib8__PPGen_9bits(Double, Negate, Single, Y, Y_1, Y_2, Y_3, Y_4, 
      Y_5, Y_6, Y_7, PP, PP_1, PP_2, PP_3, PP_4, PP_5, PP_6, PP_7, PP_8, Sign, 
      vdd, vdd_1, vdd_1_1, vdd_2, vdd_3, vdd_4, vdd_5, vdd_6, vdd_7, vdd_8, 
      gnd, gnd_1, gnd_1_1, gnd_2, gnd_3, gnd_4, gnd_5, gnd_6, gnd_7, gnd_8);
  input Double;
  input Negate;
  input Single;
  input [0:0] Y;
  input [1:1] Y_1;
  input [2:2] Y_2;
  input [3:3] Y_3;
  input [4:4] Y_4;
  input [5:5] Y_5;
  input [6:6] Y_6;
  input [7:7] Y_7;
  output [0:0] PP;
  output [1:1] PP_1;
  output [2:2] PP_2;
  output [3:3] PP_3;
  output [4:4] PP_4;
  output [5:5] PP_5;
  output [6:6] PP_6;
  output [7:7] PP_7;
  output [8:8] PP_8;
  output Sign;
  input vdd;
  input vdd_1;
  input vdd_1_1;
  input vdd_2;
  input vdd_3;
  input vdd_4;
  input vdd_5;
  input vdd_6;
  input vdd_7;
  input vdd_8;
  input gnd;
  input gnd_1;
  input gnd_1_1;
  input gnd_2;
  input gnd_3;
  input gnd_4;
  input gnd_5;
  input gnd_6;
  input gnd_7;
  input gnd_8;

  supply1 vdd;
  supply0 gnd;
  wire HalfAdde_9_Cout, net_102, net_106, net_112, net_115, net_117, net_119;
  wire net_121, net_123, net_332, net_335, net_337, net_339, net_341, net_343;
  wire net_345, net_347, net_351, net_49, net_52;

  wordlib8__HalfAdder_MK HalfAdde_9(.a(net_351), .b(net_102), 
      .Cout(HalfAdde_9_Cout), .s(PP_8[8]), .vdd(vdd_1_1), .gnd(gnd_1_1));
  wordlib8__HalfAdder_MK HalfAdde_10(.a(net_347), .b(net_106), .Cout(net_102), 
      .s(PP_7[7]), .vdd(vdd_2), .gnd(gnd_2));
  wordlib8__HalfAdder_MK HalfAdde_11(.a(net_345), .b(net_112), .Cout(net_106), 
      .s(PP_6[6]), .vdd(vdd_3), .gnd(gnd_3));
  wordlib8__HalfAdder_MK HalfAdde_12(.a(net_343), .b(net_115), .Cout(net_112), 
      .s(PP_5[5]), .vdd(vdd_4), .gnd(gnd_4));
  wordlib8__HalfAdder_MK HalfAdde_13(.a(net_341), .b(net_117), .Cout(net_115), 
      .s(PP_4[4]), .vdd(vdd_5), .gnd(gnd_5));
  wordlib8__HalfAdder_MK HalfAdde_14(.a(net_339), .b(net_119), .Cout(net_117), 
      .s(PP_3[3]), .vdd(vdd_6), .gnd(gnd_6));
  wordlib8__HalfAdder_MK HalfAdde_15(.a(net_337), .b(net_121), .Cout(net_119), 
      .s(PP_2[2]), .vdd(vdd_7), .gnd(gnd_7));
  wordlib8__HalfAdder_MK HalfAdde_16(.a(net_332), .b(net_123), .Cout(net_121), 
      .s(PP_1[1]), .vdd(vdd_8), .gnd(gnd_8));
  wordlib8__HalfAdder_MK HalfAdde_17(.a(net_335), .b(Negate), .Cout(net_123), 
      .s(PP[0]), .vdd(vdd), .gnd(gnd_1));
  wordlib8__NAND8_reducer NAND8_re_0(.inY(Y[0:0]), .inY_1(Y_1[1:1]), 
      .inY_2(Y_2[2:2]), .inY_3(Y_3[3:3]), .inY_4(Y_4[4:4]), .inY_5(Y_5[5:5]), 
      .inY_6(Y_6[6:6]), .inY_7(Y_7[7:7]), .reduced_AND(net_49), .vdd(vdd_1), 
      .gnd(gnd));
  wordlib8__PPGen_1bit PPGen_1b_0(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y[0]), .Yi_m1(gnd_1), .PPi(net_335), .vdd(vdd), 
      .gnd(gnd_1));
  wordlib8__PPGen_1bit PPGen_1b_1(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_1[1]), .Yi_m1(Y[0]), .PPi(net_332), .vdd(vdd_8), 
      .gnd(gnd_8));
  wordlib8__PPGen_1bit PPGen_1b_2(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_2[2]), .Yi_m1(Y_1[1]), .PPi(net_337), .vdd(vdd_7), 
      .gnd(gnd_7));
  wordlib8__PPGen_1bit PPGen_1b_3(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_3[3]), .Yi_m1(Y_2[2]), .PPi(net_339), .vdd(vdd_6), 
      .gnd(gnd_6));
  wordlib8__PPGen_1bit PPGen_1b_4(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_4[4]), .Yi_m1(Y_3[3]), .PPi(net_341), .vdd(vdd_5), 
      .gnd(gnd_5));
  wordlib8__PPGen_1bit PPGen_1b_5(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_5[5]), .Yi_m1(Y_4[4]), .PPi(net_343), .vdd(vdd_4), 
      .gnd(gnd_4));
  wordlib8__PPGen_1bit PPGen_1b_6(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_6[6]), .Yi_m1(Y_5[5]), .PPi(net_345), .vdd(vdd_3), 
      .gnd(gnd_3));
  wordlib8__PPGen_1bit PPGen_1b_7(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_7[7]), .Yi_m1(Y_6[6]), .PPi(net_347), .vdd(vdd_2), 
      .gnd(gnd_2));
  wordlib8__PPGen_1bit PPGen_1b_8(.Double(Double), .Negate(Negate), 
      .Single(Single), .Yi(Y_7[7]), .Yi_m1(Y_7[7]), .PPi(net_351), 
      .vdd(vdd_1_1), .gnd(gnd_1_1));
  muddlib07__and2_1x and2_1x_0(.a(net_52), .b(PP_8[8]), .y(Sign), .vdd(vdd_1), 
      .gnd(gnd));
  muddlib07__nand3_1x nand3_1x_0(.a(net_49), .b(Negate), .c(Double), 
      .y(net_52), .vdd(vdd_1), .gnd(gnd));
endmodule   /* wordlib8__PPGen_9bits */

module muddlib07__fulladder(a, b, c, cout, s, vdd, gnd);
  input a;
  input b;
  input c;
  output cout;
  output s;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire coutb, net_10, net_11, net_122, net_123, net_124, net_13, net_134;
  wire net_135, net_27, net_30, plnode_0_well, plnode_1_well, plnode_2_well;
  wire plnode_3_well, sumb;

  tranif1 nmos_0(gnd, cout, coutb);
  tranif1 nmos_1(gnd, s, sumb);
  tranif1 nmos_2(net_124, gnd, a);
  tranif1 nmos_3(net_122, net_124, b);
  tranif1 nmos_4(sumb, net_122, c);
  tranif1 nmos_5(net_123, sumb, coutb);
  tranif1 nmos_6(gnd, net_123, c);
  tranif1 nmos_7(net_123, gnd, b);
  tranif1 nmos_8(gnd, net_123, a);
  tranif1 nmos_9(net_134, gnd, a);
  tranif1 nmos_10(coutb, net_134, b);
  tranif1 nmos_11(net_135, coutb, c);
  tranif1 nmos_12(gnd, net_135, b);
  tranif1 nmos_13(net_135, gnd, a);
  tranif0 pmos_0(vdd, cout, coutb);
  tranif0 pmos_1(vdd, s, sumb);
  tranif0 pmos_2(net_10, vdd, a);
  tranif0 pmos_3(net_11, net_10, b);
  tranif0 pmos_4(sumb, net_11, c);
  tranif0 pmos_5(net_27, sumb, coutb);
  tranif0 pmos_6(vdd, net_27, c);
  tranif0 pmos_7(net_27, vdd, b);
  tranif0 pmos_8(vdd, net_27, a);
  tranif0 pmos_9(net_13, vdd, a);
  tranif0 pmos_10(coutb, net_13, b);
  tranif0 pmos_11(net_30, coutb, c);
  tranif0 pmos_12(vdd, net_30, b);
  tranif0 pmos_13(net_30, vdd, a);
endmodule   /* muddlib07__fulladder */

module wordlib8__FTC(Cin, I1, I2, I3, I4, C, Cout, S, vdd, gnd);
  input Cin;
  input I1;
  input I2;
  input I3;
  input I4;
  output C;
  output Cout;
  output S;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_6;

  muddlib07__fulladder fulladde_1(.a(I1), .b(I2), .c(I3), .cout(Cout), 
      .s(net_6), .vdd(vdd), .gnd(gnd));
  muddlib07__fulladder fulladde_2(.a(net_6), .b(I4), .c(Cin), .cout(C), .s(S), 
      .vdd(vdd), .gnd(gnd));
endmodule   /* wordlib8__FTC */

module wordlib8__PPR(PP0, PP0_1, PP0_2, PP0_3, PP0_4, PP0_5, PP0_6, PP1, PP1_1, 
      PP1_2, PP1_3, PP1_4, PP1_5, PP1_6, PP1_7, PP1_8, PP2, PP2_1, PP2_2, 
      PP2_3, PP2_4, PP2_5, PP2_6, PP2_7, PP2_8, PP3, PP3_1, PP3_2, PP3_3, 
      PP3_4, PP3_5, PP3_6, PP3_7, PP3_8, Sign0, Sign1, Sign2, Sign3, C0, C1, 
      C10, C11, C12, C13, C2, C3, C4, C5, C6, C7, C8, C9, S0, S1, S10, S11, 
      S12, S13, S2, S3, S4, S5, S6, S7, S8, S9, vdd, vdd_1, vdd_10, vdd_11, 
      vdd_12, vdd_1_1, vdd_2, vdd_3, vdd_4, vdd_5, vdd_6, vdd_7, vdd_8, vdd_9, 
      gnd, gnd_1, gnd_10, gnd_11, gnd_12, gnd_1_1, gnd_2, gnd_3, gnd_4, gnd_5, 
      gnd_6, gnd_7, gnd_8, gnd_9);
  input [2:2] PP0;
  input [3:3] PP0_1;
  input [4:4] PP0_2;
  input [5:5] PP0_3;
  input [6:6] PP0_4;
  input [7:7] PP0_5;
  input [8:8] PP0_6;
  input [0:0] PP1;
  input [1:1] PP1_1;
  input [2:2] PP1_2;
  input [3:3] PP1_3;
  input [4:4] PP1_4;
  input [5:5] PP1_5;
  input [6:6] PP1_6;
  input [7:7] PP1_7;
  input [8:8] PP1_8;
  input [0:0] PP2;
  input [1:1] PP2_1;
  input [2:2] PP2_2;
  input [3:3] PP2_3;
  input [4:4] PP2_4;
  input [5:5] PP2_5;
  input [6:6] PP2_6;
  input [7:7] PP2_7;
  input [8:8] PP2_8;
  input [0:0] PP3;
  input [1:1] PP3_1;
  input [2:2] PP3_2;
  input [3:3] PP3_3;
  input [4:4] PP3_4;
  input [5:5] PP3_5;
  input [6:6] PP3_6;
  input [7:7] PP3_7;
  input [8:8] PP3_8;
  input Sign0;
  input Sign1;
  input Sign2;
  input Sign3;
  output C0;
  output C1;
  output C10;
  output C11;
  output C12;
  output C13;
  output C2;
  output C3;
  output C4;
  output C5;
  output C6;
  output C7;
  output C8;
  output C9;
  output S0;
  output S1;
  output S10;
  output S11;
  output S12;
  output S13;
  output S2;
  output S3;
  output S4;
  output S5;
  output S6;
  output S7;
  output S8;
  output S9;
  input vdd;
  input vdd_1;
  input vdd_10;
  input vdd_11;
  input vdd_12;
  input vdd_1_1;
  input vdd_2;
  input vdd_3;
  input vdd_4;
  input vdd_5;
  input vdd_6;
  input vdd_7;
  input vdd_8;
  input vdd_9;
  input gnd;
  input gnd_1;
  input gnd_10;
  input gnd_11;
  input gnd_12;
  input gnd_1_1;
  input gnd_2;
  input gnd_3;
  input gnd_4;
  input gnd_5;
  input gnd_6;
  input gnd_7;
  input gnd_8;
  input gnd_9;

  supply1 vdd;
  supply0 gnd;
  wire FTC_14_Cout, net_12, net_15, net_18, net_21, net_24, net_27, net_30;
  wire net_33, net_36, net_39, net_42, net_45, net_71;

  wordlib8__FTC FTC_1(.Cin(gnd), .I1(PP0[2]), .I2(PP1[0]), .I3(gnd), .I4(gnd), 
      .C(C0), .Cout(net_12), .S(S0), .vdd(vdd), .gnd(gnd));
  wordlib8__FTC FTC_2(.Cin(net_12), .I1(PP0_1[3]), .I2(PP1_1[1]), .I3(gnd_1_1), 
      .I4(gnd_1_1), .C(C1), .Cout(net_15), .S(S1), .vdd(vdd_1_1), 
      .gnd(gnd_1_1));
  wordlib8__FTC FTC_3(.Cin(net_15), .I1(PP0_2[4]), .I2(PP1_2[2]), .I3(PP2[0]), 
      .I4(gnd_2), .C(C2), .Cout(net_18), .S(S2), .vdd(vdd_2), .gnd(gnd_2));
  wordlib8__FTC FTC_4(.Cin(net_18), .I1(PP0_3[5]), .I2(PP1_3[3]), 
      .I3(PP2_1[1]), .I4(gnd_3), .C(C3), .Cout(net_21), .S(S3), .vdd(vdd_3), 
      .gnd(gnd_3));
  wordlib8__FTC FTC_5(.Cin(net_21), .I1(PP0_4[6]), .I2(PP1_4[4]), 
      .I3(PP2_2[2]), .I4(PP3[0]), .C(C4), .Cout(net_24), .S(S4), .vdd(vdd_4), 
      .gnd(gnd_4));
  wordlib8__FTC FTC_6(.Cin(net_24), .I1(PP0_5[7]), .I2(PP1_5[5]), 
      .I3(PP2_3[3]), .I4(PP3_1[1]), .C(C5), .Cout(net_27), .S(S5), .vdd(vdd_5), 
      .gnd(gnd_5));
  wordlib8__FTC FTC_7(.Cin(net_27), .I1(PP0_6[8]), .I2(PP1_6[6]), 
      .I3(PP2_4[4]), .I4(PP3_2[2]), .C(C6), .Cout(net_30), .S(S6), .vdd(vdd_6), 
      .gnd(gnd_6));
  wordlib8__FTC FTC_8(.Cin(net_30), .I1(Sign0), .I2(PP1_7[7]), .I3(PP2_5[5]), 
      .I4(PP3_3[3]), .C(C7), .Cout(net_33), .S(S7), .vdd(vdd_7), .gnd(gnd_7));
  wordlib8__FTC FTC_9(.Cin(net_33), .I1(Sign0), .I2(PP1_8[8]), .I3(PP2_6[6]), 
      .I4(PP3_4[4]), .C(C8), .Cout(net_36), .S(S8), .vdd(vdd_8), .gnd(gnd_8));
  wordlib8__FTC FTC_10(.Cin(net_36), .I1(Sign0), .I2(Sign1), .I3(PP2_7[7]), 
      .I4(PP3_5[5]), .C(C9), .Cout(net_39), .S(S9), .vdd(vdd_9), .gnd(gnd_9));
  wordlib8__FTC FTC_11(.Cin(net_39), .I1(Sign0), .I2(Sign1), .I3(PP2_8[8]), 
      .I4(PP3_6[6]), .C(C10), .Cout(net_42), .S(S10), .vdd(vdd_10), 
      .gnd(gnd_10));
  wordlib8__FTC FTC_12(.Cin(net_42), .I1(Sign0), .I2(Sign1), .I3(Sign2), 
      .I4(PP3_7[7]), .C(C11), .Cout(net_45), .S(S11), .vdd(vdd_11), 
      .gnd(gnd_11));
  wordlib8__FTC FTC_13(.Cin(net_45), .I1(Sign0), .I2(Sign1), .I3(Sign2), 
      .I4(PP3_8[8]), .C(C12), .Cout(net_71), .S(S12), .vdd(vdd_12), 
      .gnd(gnd_12));
  wordlib8__FTC FTC_14(.Cin(net_71), .I1(Sign3), .I2(Sign2), .I3(Sign1), 
      .I4(Sign0), .C(C13), .Cout(FTC_14_Cout), .S(S13), .vdd(vdd_1), 
      .gnd(gnd_1));
endmodule   /* wordlib8__PPR */

module muddlib07__buf_1x(a, y, vdd, gnd);
  input a;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_61, plno_2_well, plnode_0_well;

  tranif1 nmos_0(gnd, y, net_61);
  tranif1 nmos_1(net_61, gnd, a);
  tranif0 pmos_0(net_61, vdd, a);
  tranif0 pmos_1(vdd, y, net_61);
endmodule   /* muddlib07__buf_1x */

module muddlib07__xnor2_1x(a, b, y, vdd, gnd);
  input a;
  input b;
  output y;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_128, net_129, net_191, net_74, net_75, net_83, plno_2_well;
  wire plnode_0_well;

  tranif1 nmos_0(net_128, gnd, a);
  tranif1 nmos_1(gnd, net_75, a);
  tranif1 nmos_2(net_75, y, net_129);
  tranif1 nmos_3(y, net_83, b);
  tranif1 nmos_4(net_83, gnd, net_128);
  tranif1 nmos_5(gnd, net_129, b);
  tranif0 pmos_0(net_128, vdd, a);
  tranif0 pmos_1(vdd, net_74, a);
  tranif0 pmos_2(net_74, y, b);
  tranif0 pmos_3(y, net_191, net_129);
  tranif0 pmos_5(vdd, net_129, b);
  tranif0 pmos_6(net_191, vdd, net_128);
endmodule   /* muddlib07__xnor2_1x */

module wordlib8__mbe_1x(x0, x1, x2, double, neg, single, vdd, gnd);
  input x0;
  input x1;
  input x2;
  output double;
  output neg;
  output single;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wire net_12;

  muddlib07__buf_1x buf_1x_0(.a(x2), .y(neg), .vdd(vdd), .gnd(gnd));
  muddlib07__nor2_1x nor2_1x_0(.a(net_12), .b(single), .y(double), .vdd(vdd), 
      .gnd(gnd));
  muddlib07__xnor2_1x xnor2_1x_1(.a(x2), .b(x0), .y(net_12), .vdd(vdd), 
      .gnd(gnd));
  muddlib07__xor2_1x xor2_1x_0(.a(x0), .b(x1), .y(single), .vdd(vdd), 
      .gnd(gnd));
endmodule   /* wordlib8__mbe_1x */

module wordlib8__mbe_4x(x, x_1, x_2, x_3, x_4, x_5, x_6, x_7, double, double_1, 
      double_2, double_3, neg, neg_1, neg_2, neg_3, single, single_1, single_2, 
      single_3, vdd, gnd);
  input [0:0] x;
  input [1:1] x_1;
  input [2:2] x_2;
  input [3:3] x_3;
  input [4:4] x_4;
  input [5:5] x_5;
  input [6:6] x_6;
  input [7:7] x_7;
  output [0:0] double;
  output [1:1] double_1;
  output [2:2] double_2;
  output [3:3] double_3;
  output [0:0] neg;
  output [1:1] neg_1;
  output [2:2] neg_2;
  output [3:3] neg_3;
  output [0:0] single;
  output [1:1] single_1;
  output [2:2] single_2;
  output [3:3] single_3;
  input vdd;
  input gnd;

  supply1 vdd;
  supply0 gnd;
  wordlib8__mbe_1x mbe_1x_0(.x0(x_5[5]), .x1(x_6[6]), .x2(x_7[7]), 
      .double(double_3[3]), .neg(neg_3[3]), .single(single_3[3]), .vdd(vdd), 
      .gnd(gnd));
  wordlib8__mbe_1x mbe_1x_1(.x0(x_3[3]), .x1(x_4[4]), .x2(x_5[5]), 
      .double(double_2[2]), .neg(neg_2[2]), .single(single_2[2]), .vdd(vdd), 
      .gnd(gnd));
  wordlib8__mbe_1x mbe_1x_2(.x0(x_1[1]), .x1(x_2[2]), .x2(x_3[3]), 
      .double(double_1[1]), .neg(neg_1[1]), .single(single_1[1]), .vdd(vdd), 
      .gnd(gnd));
  wordlib8__mbe_1x mbe_1x_3(.x0(gnd), .x1(x[0]), .x2(x_1[1]), 
      .double(double[0]), .neg(neg[0]), .single(single[0]), .vdd(vdd), 
      .gnd(gnd));
endmodule   /* wordlib8__mbe_4x */


module BoothMultiplier(x, x_1, x_2, x_3, x_4, x_5, x_6, x_7, y, y_1, y_2, y_3, 
      y_4, y_5, y_6, y_7, s0, s1, s10, s11, s12, s13, s14, s15, s2, s3, s4, s5, 
      s6, s7, s8, s9);

  input [0:0] x;
  input [1:1] x_1;
  input [2:2] x_2;
  input [3:3] x_3;
  input [4:4] x_4;
  input [5:5] x_5;
  input [6:6] x_6;
  input [7:7] x_7;
  input [0:0] y;
  input [1:1] y_1;
  input [2:2] y_2;
  input [3:3] y_3;
  input [4:4] y_4;
  input [5:5] y_5;
  input [6:6] y_6;
  input [7:7] y_7;
  output s0;
  output s1;
  output s10;
  output s11;
  output s12;
  output s13;
  output s14;
  output s15;
  output s2;
  output s3;
  output s4;
  output s5;
  output s6;
  output s7;
  output s8;
  output s9;

  supply1 vdd;
  supply1 vdd_1;
  supply1 vdd_10;
  supply1 vdd_11;
  supply1 vdd_12;
  supply1 vdd_1_1;
  supply1 vdd_2;
  supply1 vdd_3;
  supply1 vdd_4;
  supply1 vdd_5;
  supply1 vdd_6;
  supply1 vdd_7;
  supply1 vdd_8;
  supply1 vdd_9;

  supply0 gnd;
  supply0 gnd_1;
  supply0 gnd_10;
  supply0 gnd_11;
  supply0 gnd_12;
  supply0 gnd_1_1;
  supply0 gnd_2;
  supply0 gnd_3;
  supply0 gnd_4;
  supply0 gnd_5;
  supply0 gnd_6;
  supply0 gnd_7;
  supply0 gnd_8;
  supply0 gnd_9;


  wire CPA_0_cout, PPR_0_C13, net_11, net_15, net_18, net_211, net_216, net_220;
  wire net_222, net_225, net_228, net_231, net_237, net_241, net_243, net_25;
  wire net_250, net_251, net_261, net_266, net_275, net_277, net_28, net_282;
  wire net_291, net_294, net_302, net_306, net_310, net_311, net_318, net_322;
  wire net_324, net_325, net_326, net_327, net_328, net_346, net_35, net_351;
  wire net_358, net_366, net_38, net_395, net_398, net_401, net_5, net_675;
  wire net_678, net_681, net_683, net_688, net_700, net_705, net_708, net_710;
  wire net_712, net_714, net_716, net_718, net_720, net_722, net_724, net_726;
  wire net_728, net_730, net_732, net_734, net_736, net_740, net_742, net_744;
  wire net_746, net_748, net_750, net_752, net_754, net_756, net_791;

  wordlib8__CPA CPA_0(.a0(gnd_1), .a1(net_736), .a10(net_754), .a11(net_756), 
      .a12(net_705), .a13(net_708), .a2(net_740), .a3(net_742), .a4(net_791), 
      .a5(net_744), .a6(net_746), .a7(net_748), .a8(net_750), .a9(net_752), 
      .b0(net_734), .b1(net_732), .b10(net_714), .b11(net_712), .b12(net_710), 
      .b13(net_700), .b2(net_730), .b3(net_728), .b4(net_726), .b5(net_724), 
      .b6(net_722), .b7(net_720), .b8(net_718), .b9(net_716), 
      .cout(CPA_0_cout), .s0(s2), .s1(s3), .s10(s12), .s11(s13), .s12(s14), 
      .s13(s15), .s2(s4), .s3(s5), .s4(s6), .s5(s7), .s6(s8), .s7(s9), 
      .s8(s10), .s9(s11), .vdd(vdd), .vdd_1(vdd_1), .vdd_10(vdd_3), 
      .vdd_11(vdd_2), .vdd_12(vdd_1_1), .vdd_1_1(vdd_12), .vdd_2(vdd_11), 
      .vdd_3(vdd_10), .vdd_4(vdd_9), .vdd_5(vdd_8), .vdd_6(vdd_7), 
      .vdd_7(vdd_6), .vdd_8(vdd_5), .vdd_9(vdd_4), .gnd(gnd_1), .gnd_1(gnd), 
      .gnd_10(gnd_3), .gnd_11(gnd_2), .gnd_12(gnd_1_1), .gnd_1_1(gnd_12), 
      .gnd_2(gnd_11), .gnd_3(gnd_10), .gnd_4(gnd_9), .gnd_5(gnd_8), 
      .gnd_6(gnd_7), .gnd_7(gnd_6), .gnd_8(gnd_5), .gnd_9(gnd_4));
  wordlib8__PPGen_9bits PPGen_9b_3(.Double(net_675), .Negate(net_11), 
      .Single(net_5), .Y(y[0:0]), .Y_1(y_1[1:1]), .Y_2(y_2[2:2]), 
      .Y_3(y_3[3:3]), .Y_4(y_4[4:4]), .Y_5(y_5[5:5]), .Y_6(y_6[6:6]), 
      .Y_7(y_7[7:7]), .PP({net_291}), .PP_1({net_231}), .PP_2({net_228}), 
      .PP_3({net_225}), .PP_4({net_222}), .PP_5({net_220}), .PP_6({net_216}), 
      .PP_7({net_294}), .PP_8({net_282}), .Sign(net_688), .vdd(vdd_10), 
      .vdd_1(vdd_1_1), .vdd_1_1(vdd_2), .vdd_2(vdd_3), .vdd_3(vdd_4), 
      .vdd_4(vdd_5), .vdd_5(vdd_6), .vdd_6(vdd_7), .vdd_7(vdd_8), 
      .vdd_8(vdd_9), .gnd(gnd_1_1), .gnd_1(gnd_10), .gnd_1_1(gnd_2), 
      .gnd_2(gnd_3), .gnd_3(gnd_4), .gnd_4(gnd_5), .gnd_5(gnd_6), 
      .gnd_6(gnd_7), .gnd_7(gnd_8), .gnd_8(gnd_9));
  wordlib8__PPGen_9bits PPGen_9b_4(.Double(net_678), .Negate(net_15), 
      .Single(net_18), .Y(y[0:0]), .Y_1(y_1[1:1]), .Y_2(y_2[2:2]), 
      .Y_3(y_3[3:3]), .Y_4(y_4[4:4]), .Y_5(y_5[5:5]), .Y_6(y_6[6:6]), 
      .Y_7(y_7[7:7]), .PP({net_366}), .PP_1({net_311}), .PP_2({net_310}), 
      .PP_3({net_306}), .PP_4({net_302}), .PP_5({net_250}), .PP_6({net_241}), 
      .PP_7({net_237}), .PP_8({net_211}), .Sign(net_401), .vdd(vdd_11), 
      .vdd_1(vdd_2), .vdd_1_1(vdd_3), .vdd_2(vdd_4), .vdd_3(vdd_5), 
      .vdd_4(vdd_6), .vdd_5(vdd_7), .vdd_6(vdd_8), .vdd_7(vdd_9), 
      .vdd_8(vdd_10), .gnd(gnd_2), .gnd_1(gnd_11), .gnd_1_1(gnd_3), 
      .gnd_2(gnd_4), .gnd_3(gnd_5), .gnd_4(gnd_6), .gnd_5(gnd_7), 
      .gnd_6(gnd_8), .gnd_7(gnd_9), .gnd_8(gnd_10));
  wordlib8__PPGen_9bits PPGen_9b_5(.Double(net_681), .Negate(net_25), 
      .Single(net_28), .Y(y[0:0]), .Y_1(y_1[1:1]), .Y_2(y_2[2:2]), 
      .Y_3(y_3[3:3]), .Y_4(y_4[4:4]), .Y_5(y_5[5:5]), .Y_6(y_6[6:6]), 
      .Y_7(y_7[7:7]), .PP({net_324}), .PP_1({net_325}), .PP_2({net_326}), 
      .PP_3({net_327}), .PP_4({net_328}), .PP_5({net_322}), .PP_6({net_318}), 
      .PP_7({net_251}), .PP_8({net_243}), .Sign(net_395), .vdd(vdd_12), 
      .vdd_1(vdd_3), .vdd_1_1(vdd_4), .vdd_2(vdd_5), .vdd_3(vdd_6), 
      .vdd_4(vdd_7), .vdd_5(vdd_8), .vdd_6(vdd_9), .vdd_7(vdd_10), 
      .vdd_8(vdd_11), .gnd(gnd_3), .gnd_1(gnd_12), .gnd_1_1(gnd_4), 
      .gnd_2(gnd_5), .gnd_3(gnd_6), .gnd_4(gnd_7), .gnd_5(gnd_8), 
      .gnd_6(gnd_9), .gnd_7(gnd_10), .gnd_8(gnd_11));
  wordlib8__PPGen_9bits PPGen_9b_6(.Double(net_683), .Negate(net_35), 
      .Single(net_38), .Y(y[0:0]), .Y_1(y_1[1:1]), .Y_2(y_2[2:2]), 
      .Y_3(y_3[3:3]), .Y_4(y_4[4:4]), .Y_5(y_5[5:5]), .Y_6(y_6[6:6]), 
      .Y_7(y_7[7:7]), .PP({s0}), .PP_1({s1}), .PP_2({net_346}), 
      .PP_3({net_351}), .PP_4({net_358}), .PP_5({net_275}), .PP_6({net_277}), 
      .PP_7({net_266}), .PP_8({net_261}), .Sign(net_398), .vdd(vdd), 
      .vdd_1(vdd_4), .vdd_1_1(vdd_5), .vdd_2(vdd_6), .vdd_3(vdd_7), 
      .vdd_4(vdd_8), .vdd_5(vdd_9), .vdd_6(vdd_10), .vdd_7(vdd_11), 
      .vdd_8(vdd_12), .gnd(gnd_4), .gnd_1(gnd_1), .gnd_1_1(gnd_5), 
      .gnd_2(gnd_6), .gnd_3(gnd_7), .gnd_4(gnd_8), .gnd_5(gnd_9), 
      .gnd_6(gnd_10), .gnd_7(gnd_11), .gnd_8(gnd_12));
  wordlib8__PPR PPR_0(.PP0({net_346}), .PP0_1({net_351}), .PP0_2({net_358}), 
      .PP0_3({net_275}), .PP0_4({net_277}), .PP0_5({net_266}), 
      .PP0_6({net_261}), .PP1({net_324}), .PP1_1({net_325}), .PP1_2({net_326}), 
      .PP1_3({net_327}), .PP1_4({net_328}), .PP1_5({net_322}), 
      .PP1_6({net_318}), .PP1_7({net_251}), .PP1_8({net_243}), .PP2({net_366}), 
      .PP2_1({net_311}), .PP2_2({net_310}), .PP2_3({net_306}), 
      .PP2_4({net_302}), .PP2_5({net_250}), .PP2_6({net_241}), 
      .PP2_7({net_237}), .PP2_8({net_211}), .PP3({net_291}), .PP3_1({net_231}), 
      .PP3_2({net_228}), .PP3_3({net_225}), .PP3_4({net_222}), 
      .PP3_5({net_220}), .PP3_6({net_216}), .PP3_7({net_294}), 
      .PP3_8({net_282}), .Sign0(net_398), .Sign1(net_395), .Sign2(net_401), 
      .Sign3(net_688), .C0(net_736), .C1(net_740), .C10(net_756), 
      .C11(net_705), .C12(net_708), .C13(PPR_0_C13), .C2(net_742), 
      .C3(net_791), .C4(net_744), .C5(net_746), .C6(net_748), .C7(net_750), 
      .C8(net_752), .C9(net_754), .S0(net_734), .S1(net_732), .S10(net_714), 
      .S11(net_712), .S12(net_710), .S13(net_700), .S2(net_730), .S3(net_728), 
      .S4(net_726), .S5(net_724), .S6(net_722), .S7(net_720), .S8(net_718), 
      .S9(net_716), .vdd(vdd), .vdd_1(vdd_1), .vdd_10(vdd_3), .vdd_11(vdd_2), 
      .vdd_12(vdd_1_1), .vdd_1_1(vdd_12), .vdd_2(vdd_11), .vdd_3(vdd_10), 
      .vdd_4(vdd_9), .vdd_5(vdd_8), .vdd_6(vdd_7), .vdd_7(vdd_6), 
      .vdd_8(vdd_5), .vdd_9(vdd_4), .gnd(gnd_1), .gnd_1(gnd), .gnd_10(gnd_3), 
      .gnd_11(gnd_2), .gnd_12(gnd_1_1), .gnd_1_1(gnd_12), .gnd_2(gnd_11), 
      .gnd_3(gnd_10), .gnd_4(gnd_9), .gnd_5(gnd_8), .gnd_6(gnd_7), 
      .gnd_7(gnd_6), .gnd_8(gnd_5), .gnd_9(gnd_4));
  wordlib8__mbe_4x mbe_4x_0(.x(x[0:0]), .x_1(x_1[1:1]), .x_2(x_2[2:2]), 
      .x_3(x_3[3:3]), .x_4(x_4[4:4]), .x_5(x_5[5:5]), .x_6(x_6[6:6]), 
      .x_7(x_7[7:7]), .double({net_683}), .double_1({net_681}), 
      .double_2({net_678}), .double_3({net_675}), .neg({net_35}), 
      .neg_1({net_25}), .neg_2({net_15}), .neg_3({net_11}), .single({net_38}), 
      .single_1({net_28}), .single_2({net_18}), .single_3({net_5}), 
      .vdd(vdd_1), .gnd(gnd));
endmodule   /* BoothMultiplier */

