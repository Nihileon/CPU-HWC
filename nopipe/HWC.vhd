library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity HWC is
    port(
        -- SWA, SWB, SWC, W(1)\2\3(time)
        SW, W : in std_logic_vector(3 downto 1);
        -- IR: 7~4 high 4bits of an instruction
        IR : in std_logic_vector(7 downto 4);

        C, Z, T3, CLR : in std_logic;
        -- S : 3~0 for ALU, SEL:3~0
        S, SEL: out std_logic_vector(3 downto 0);
        --ALU
        M, CIN, ABUS, LDC, LDZ : out std_logic;
        -- RAM
        MBUS, MEMW : out std_logic;
        -- AR
        LAR, ARINC : out std_logic;
        -- PC
        PCADD, LPC, PCINC : out std_logic;
        -- sequence generator
        STOP, SHORT, LONG : out std_logic;
        -- register, IR, selector, data switcher, SST0
        DRW, LIR, SELCTL, SBUS : out std_logic
    );
end HWC;

architecture rtl of HWC is
    -- write/read register, fetch instruction,
    signal  REG_W, REG_R, FETCH_INS, MEM_W, MEM_R : std_logic;
    signal  ST0 : std_logic;
    signal  ADD, SUB, AND_I, INC, LD, ST, JC, JZ, JMP, STP : std_logic;
    -- what we add in it
    signal  cmp, mov : std_logic;
begin
    REG_W <= '1' when SW = "100" else '0';
    REG_R <= '1' when SW = "011" else '0';
    FETCH_INS <= '1' when SW = "000" else '0';
    MEM_R <= '1' when SW = "010" else '0';
    MEM_W <= '1' when SW = "001" else '0';

    ADD   <= '1' when IR = "0001" else '0';
    SUB   <= '1' when IR = "0010" else '0';
    AND_I <= '1' when IR = "0011" else '0';
    INC   <= '1' when IR = "0100" else '0';
    LD    <= '1' when IR = "0101" else '0';
    ST    <= '1' when IR = "0110" else '0';
    JC    <= '1' when IR = "0111" else '0';
    JZ    <= '1' when IR = "1000" else '0';
    JMP   <= '1' when IR = "1001" else '0';
    STP   <= '1' when IR = "1110" else '0';

-- 此处把process 删除是因为还不需要用到指令
	process(clr,W)
	begin
		if(clr = '0')then
			ST0<='0';
		elsif(falling_edge(T3))then
			if((REG_W = '1' and W(2)='1')
                or ((MEM_R='1' or MEM_W='1') and W(1)='1' and (ST0 = '0'))) then
					ST0    <= '1';
			end if;
        end if;
	end process;


-- 已注释的是由于指令需要用到而放在下方
    SEL(3)  <= (REG_W and (W(1) or W(2)) and ST0)
                or (REG_R and W(2));
    SEL(2)  <= (REG_W and W(2));
    SEL(1)  <= (REG_W and ((W(1) and (not ST0)) or (W(2) and ST0)))
                or (REG_R and W(2));
    SEL(0)  <= (REG_W and W(1))
                or (REG_R and (W(1) or W(2)));
    SBUS    <= (MEM_R and W(1) and (not ST0))
                or (MEM_W and W(1))
                or (REG_W and (W(1) or W(2)));
    -- DRW    <= (REG_W and (W(1) or W(2)));
    -- STOP   <= ((REG_W or REG_R) and (W(1) or W(2)))
    --          or ((MEM_R or MEM_W) and W(1));
    SELCTL  <= ((REG_W or REG_R) and (W(1) or W(2)))
                or ((MEM_R or MEM_W) and W(1));
    -- LAR    <= ((MEM_R or MEM_W) and W(1) and (not ST0));
    SHORT   <= ((MEM_R or MEM_W) and W(1));
    -- MBUS   <= (MEM_R and W(1) and ST0);
    ARINC   <= ((MEM_W or MEM_R) and W(1) and ST0);

    --\TODO : yzq: ADD SUB AND_I INC LD

    PCINC   <= (W(1) and FETCH_INS);
    LIR     <= (W(1) and  FETCH_INS);
    M       <= ((W(2) or W(3)) and ST)
                or (W(2) and JMP)
                or (W(2) and AND_I)
                or (W(2) and LD);
    CIN     <= (W(2) and ADD);
    S(3)      <= ((W(2) or W(3)) and ST)
                or (W(2) and JMP)
                or (W(2) and ADD)
                or (W(2) and AND_I)
                or (W(2) and LD);
    S(2)      <= (W(2) and (ST or JMP))
                or (W(2) and SUB);
    S(1)      <= ((W(2) or W(3)) and ST)
                or (W(2) and JMP)
                or (W(2) and SUB)
                or (W(2) and AND_I)
                or (W(2) and LD);
                -- or (ST0);  --debug
    S(0)      <= (W(2) and (ST or JMP))
                or (W(2) and ADD)
                or (W(2) and AND_I);
    ABUS    <= ((W(2) or W(3)) and ST)
                or (W(2) and (JMP or ADD or SUB or AND_I or INC or LD));
    MBUS    <= (MEM_R and W(1) and ST0)
                or (W(3) and LD);
    DRW     <= (REG_W and (W(1) or W(2)))
                or ((W(2) and (ADD or SUB or AND_I or INC)))
                or( W(3) and LD);
    LDZ     <= (W(2) and (ADD or SUB or AND_I or INC));
    LDC     <= (W(2) and (ADD or SUB or INC));
    LPC     <= (W(2) and JMP);
    LAR     <= ((MEM_R or MEM_W) and W(1) and (not ST0))
                or (W(2) and ST)
                or (W(2) and LD);
    LONG    <= (W(2) and ST)
                or (W(2) and LD);
    PCADD   <= (W(2) and C and JC)
                or (W(2) and Z and JZ);
    MEMW    <= (W(1) and MEM_W and ST0) 
                or (W(3) and ST);
    STOP    <= ((REG_W or REG_R) and (W(1) or W(2)))
                or ((MEM_R or MEM_W) and W(1))
                or (W(2) and STP);

end architecture rtl;