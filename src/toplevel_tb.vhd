library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity toplevel_tb is
--  Port ( );
end toplevel_tb;

architecture Behavioral of toplevel_tb is

-- this component is a vhdl model of what the actual ADC card looks like to the FPGA,
-- it creates an LVDS clock and 8 LVDS data signals.
-- this particular device puts out a fixed data pattern which represents (if read correctly)
-- 0, 7070, 10000, 7070, 0, -7070, -1000, -7070, 0, 7070 ...etc. 
-- the model outputs 'X' at times when the data would not be wise to sample (i.e. right around when it is changing)
component ad_9467_model is
  Port (dco_p : out std_logic;
        dco_n : out std_logic;
        -- data out.  dout(7) corresponds to the line D15/14, 6 is 13/12...etc
        dout_p : out std_logic_vector(7 downto 0);
        dout_n : out std_logic_vector(7 downto 0)
         );
end component;

-- this is the component that was discussed in class and is the custom logic inside the FPGA which will
-- be responsible for taking the signals from the ADC and creating signed 16-bit data from it.
-- ADC_DATA, and ADC_CLK are the two signals which represent that data.  ADC_DATA can be used on the rising edge
-- of ADC_CLK by any part of the FPGA that wants data from the ADC.
-- PSINCDEC, PSEN, PSCLK, PSDONE are used to control the phase of the ADC_CLK and line it up for reliable data-reading
component AD9467_INTERFACE is 
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
end component;

signal ADC_DATA: std_logic_vector (15 downto 0);
signal dco_p, dco_n : std_logic;
signal dout_p, dout_n : std_logic_vector(7 downto 0);
signal psclk, psen, reset, PSDONE : std_logic;
constant TbPeriod : time := 8 ns;
signal TbClock : std_logic := '0';
signal Unshifted_clk , ADCCLK : std_logic;

begin
TbClock <= not TbClock after 2.5ns; -- create a 200MHz clock for kicks, this clock is arbitrary and is just for the PSCLK
psclk <= TbClock; -- this will be the board clock 125MHz

stimuli : process
  variable total_shift : time := 0 ns;
  variable t_last_Unshifted : time := 0ns;
  variable t_last_ADCCLK : time := 0ns;
  variable TOL : time := 1ps;
  variable psen_count : integer := 0;
begin

  -- Loop and shift until a full period of phase advances
  while total_shift < 1000 us loop   -- 1s upper bound is only a safety net

    ------------------------------------------------------------
    -- Issue one dynamic phase-shift step
    ------------------------------------------------------------
    PSEN <= '1';
    psen_count := psen_count + 1;       -- increment the counter
    report "PSEN asserted " & integer'image(psen_count) & " times";

    wait until rising_edge(psclk);
    PSEN <= '0';

    -- Wait for MMCM to complete the shift
    wait until PSDONE = '1';
    wait until PSDONE = '0';

    -- Wait for any clock edge
    wait until rising_edge(Unshifted_clk);

    -- Record the last rising edge times
    if rising_edge(Unshifted_clk) then
        t_last_Unshifted := now;
    end if;

    wait until rising_edge(ADCCLK);

    if rising_edge(ADCCLK) then
        t_last_ADCCLK := now;
    end if;

    report "current unshifted rising edge = " & time'image(t_last_Unshifted);
    report "current ADC rising edge = " & time'image(t_last_ADCCLK);

    -- Compare rising edge times
    if abs(t_last_Unshifted - t_last_ADCCLK) <= TOL then
        report "Rising edges occurred within 1 ps: " & time'image(now);
        std.env.stop;
    end if;

    total_shift := now;

  end loop;

  report "Error: Did not complete 360-degree rotation before timeout.";
  std.env.stop;
 end process;

-- instantiate the ADC itself
ADC_inst: ad_9467_model 
  Port map (
        dco_p => dco_p,
        dco_n => dco_n,
        dout_p => dout_p, 
        dout_n => dout_n);
        

-- instantiate the ADC Interface
ADCInterface_inst : AD9467_INTERFACE
    port map (
        PSINCDEC => '1',
        PSEN => psen,
        PSCLK => TbClock,
        PSDONE => PSDONE,
        Unshifted_clk => Unshifted_clk,
        ADCCLK => ADCCLK,
        ADC_DATA => ADC_DATA,
        -- LVDS signals from AD9467
        Din_p => dout_p,
        Din_n => dout_n,
        CLK_p => dco_p,
        CLK_N => dco_n
        );

end Behavioral;
