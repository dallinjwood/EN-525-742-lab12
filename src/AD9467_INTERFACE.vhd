----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/08/2022 03:02:20 PM
-- Design Name: 
-- Module Name: AD9467_Interfacetop_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity AD9467_INTERFACE is
  Port ( 
    PSINCDEC : in std_logic;
    PSEN : in std_logic;
    PSCLK : in std_logic;
    PSDONE : out std_logic;
    Unshifted_clk : out std_logic;
    ADCCLK : out std_logic;
    ADC_DATA : out std_logic_vector (15 downto 0);
    -- LVDS signals from AD9467
    Din_p : in std_logic_vector (7 downto 0);
    Din_n : in std_logic_vector (7 downto 0);
    CLK_p : in std_logic;
    CLK_N : in std_logic
  );
end AD9467_INTERFACE;

architecture Behavioral of AD9467_INTERFACE is

component clk_wiz_0
     port (
         clk_out1 : out std_logic;
         clk_out2 : out std_logic;        
         psclk : in std_logic;
         psen : in std_logic;
         psincdec : in std_logic;
         psdone : out std_logic;
         clk_in1_p : in std_logic;
         clk_in1_n : in std_logic
         );
end component;

signal O, Q1, Q2 : std_logic_vector (7 downto 0); 
signal adc_data_sorted : std_logic_vector(15 downto 0);
signal shifted_clk : std_logic;

begin

-- IBUFDS (input buffer diffrential signal) lets us read LVDS signals
gen_IBUFDS : for i in 0 to 7 generate
IBUFDS_inst : IBUFDS
    generic map(
      DIFF_TERM => FALSE, --Differential Termination
      IBUF_LOW_PWR => TRUE, --Low power (TRUE) vs. performance (FALSE) setting referenced I/O standards
      IOSTANDARD=> "LVDS_25")
    port map(
      O=> O(i), -- buffer output
      I=> Din_p(i), --Diff_p buffer input
      IB => Din_n(i)); --Diff_n buffer input
end generate;
      
 clk_wiz_inst : clk_wiz_0
      port map(
          clk_out1 => shifted_clk,  --shifted clk
          clk_out2 => Unshifted_clk,  --unshifted clk for debug only      
          psclk => PSCLK,
          psen => PSEN,
          psincdec => PSINCDEC,     --17.9ps per psen
          psdone => PSDONE,
          clk_in1_p => CLK_p, --clk from the adc
          clk_in1_n => CLK_n  --clk from the adc
          );
ADCCLK <= shifted_clk;  
gen_IDDR: for i in 0 to 7 generate    
 IDDR_inst : IDDR
    generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",--"OPPOSITE_EDGE" "SAME_EDGE", "SAME_EDGE_PIPELINED"
      INIT_Q1 => '0', --initial value of Q1 : '0' or '1'
      INIT_Q2 => '0', --initial value of Q2 : '0' or '1'
      SRTYPE => "SYNC") -- set/reset type : "SYNC" or "ASYNC"
    port map (
      Q1 => Q1(i), -- 1-bit output for positive edge of clock
      Q2 => Q2(i), -- 1-bit output for negative edge of clock
      C => shifted_clk, -- 1-bit clock input
      CE => '1', -- 1-bit clock enable input (in this situation always enabled)
      D => O(i), -- 1-bit DDR data input
      R => '0', -- 1-bit reset (no reason to ever reset in this used case)
      S => '0' -- 1-bit set (no reason to ever "set" in this use case)
      );
 end generate;    
 
adc_data_sorted(15) <= Q1(7);
adc_data_sorted(14) <= Q2(7);
adc_data_sorted(13) <= Q1(6);
adc_data_sorted(12) <= Q2(6);
adc_data_sorted(11) <= Q1(5);
adc_data_sorted(10) <= Q2(5);
adc_data_sorted(9)  <= Q1(4);
adc_data_sorted(8)  <= Q2(4);
adc_data_sorted(7)  <= Q1(3);
adc_data_sorted(6)  <= Q2(3);
adc_data_sorted(5)  <= Q1(2);
adc_data_sorted(4)  <= Q2(2);
adc_data_sorted(3)  <= Q1(1);
adc_data_sorted(2)  <= Q2(1);
adc_data_sorted(1)  <= Q1(0);
adc_data_sorted(0)  <= Q2(0);
ADC_DATA <= (adc_data_sorted xor x"8000");
end Behavioral;