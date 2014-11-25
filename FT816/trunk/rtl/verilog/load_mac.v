// ============================================================================
//        __
//   \\__/ o\    (C) 2014  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@opencores.org
//       ||
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
LOAD_MAC1:
`ifdef SUPPORT_DCACHE
	if (unCachedData)
`endif
	begin
		if (isRMW)
			lock_o <= 1'b1;
		data_read(radr);
		state <= LOAD_MAC2;
	end
`ifdef SUPPORT_DCACHE
	else if (dhit)
		load_tsk(rdat,rdat8,rdat16);
	else begin
		retstate <= LOAD_MAC1;
		state <= DCACHE1;
	end
`endif
LOAD_MAC2:
	if (rdy) begin
		data_nack();
		load_tsk(db);
	end
`ifdef SUPPORT_BERR
	else if (err_i) begin
		lock_o <= 1'b0;
		wb_nack();
		derr_address <= adr_o;
		intno <= 9'd508;
		state <= BUS_ERROR;
	end
`endif
LOAD_MAC3:
	begin
		// Rt will be zero by the time the IFETCH stage is entered because of
		// the decrement below.
		if (Rt==4'd1)
			state <= IFETCH;
		else begin
			radr <= isp;
			isp <= isp_inc;
			state <= LOAD_MAC1;
		end
		Rt <= Rt - 4'd1;
	end

RTS1:
	begin
		pc <= pc + 32'd1;
		state <= IFETCH1;
	end
IY3:
	begin
		radr <= radr + y;
		wadr <= radr + y;
		if (ir9==`ST_IY) begin
			store_what <= `STW_A;
			state <= STORE1;
		end
		else if (ir9==`LEA_IY) begin
			res <= radr + y;
			next_state(IFETCH);
		end
		else begin
			load_what <= `WORD_310;
			state <= LOAD_MAC1;
		end
		isIY <= 1'b0;
		isIY24 <= `FALSE;
	end
BYTE_IX5:
	begin
		isI24 <= `FALSE;
		radr <= ia;
		load_what <= m16 ? `HALF_70 : `BYTE_70;
		state <= LOAD_MAC1;
		if (ir[7:0]==`STA_IX || ir[7:0]==`STA_I || ir[7:0]==`STA_IL) begin
			wadr <= ia;
			store_what <= m16 ? `STW_ACC70 : `STW_ACC8;
			state <= STORE1;
		end
		else if (ir[7:0]==`PEI) begin
			set_sp();
			store_what <= `STW_IA158;
			state <= STORE1;
		end
	end
BYTE_IY5:
	begin
		isIY <= `FALSE;
		isIY24 <= `FALSE;
		radr <= iapy8;
		$display("IY addr: %h", iapy8);
		if (ir[7:0]==`STA_IY || ir[7:0]==`STA_IYL || ir[7:0]==`STA_DSPIY) begin
			wadr <= iapy8;
			store_what <= m16 ? `STW_ACC70 : `STW_ACC8;
			state <= STORE1;
		end
		else begin
			load_what <= m16 ? `HALF_70 : `BYTE_70;
			state <= LOAD_MAC1;
		end
	end
